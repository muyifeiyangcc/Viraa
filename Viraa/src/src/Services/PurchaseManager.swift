import Foundation
@preconcurrency import StoreKit

protocol PurchaseManagerDelegate: AnyObject { func purchaseManagerDidUpdateProducts(_ products: [PurchaseDisplayProduct]); func purchaseManagerLoading(_ loading: Bool); func purchaseManagerDidPurchase(reward: Int); func purchaseManagerDidFail(_ message: String) }

final class PurchaseManager: NSObject, @preconcurrency SKProductsRequestDelegate, @preconcurrency SKPaymentTransactionObserver {
    static let shared = PurchaseManager()
    weak var delegate: PurchaseManagerDelegate?
    private var request: SKProductsRequest?, storeProducts: [String: SKProduct] = [:]
    private var requestTimeout: DispatchWorkItem?
    private var requestGeneration = 0
    // Single product catalog. Add the four future products here when their IDs are available.
    private let configurations: [PurchaseConfiguration] = [
      .init(productID: "lvbsvhxcgcrvesor", reward: 400, usdPrice: "$0.99"),
      .init(productID: "dxismgcwewhrtezo", reward: 800, usdPrice: "$1.99"),
      .init(productID: "khtxlcejaxmqcsra", reward: 2450, usdPrice: "$4.99"),
      .init(productID: "yadwwvxspgxwlndb", reward: 5150, usdPrice: "$9.99"),
      .init(productID: "qnrcuelbtiuflyky", reward: 6400, usdPrice: "$12.99"),
      .init(productID: "ymohxnvpkqxutvab", reward: 10800, usdPrice: "$19.99"),
    ]
    private var rewards: [String: Int] { Dictionary(uniqueKeysWithValues: configurations.map { ($0.productID, $0.reward) }) }
    private var configurationsByID: [String: PurchaseConfiguration] {
      Dictionary(uniqueKeysWithValues: configurations.map { ($0.productID, $0) })
    }
    private override init() { super.init(); SKPaymentQueue.default().add(self) }
    deinit { SKPaymentQueue.default().remove(self) }

    func loadProducts() {
      requestTimeout?.cancel()
      request?.cancel()
      requestGeneration += 1
      let generation = requestGeneration
      storeProducts.removeAll()
      delegate?.purchaseManagerLoading(true)
      let request = SKProductsRequest(productIdentifiers: Set(configurations.map(\.productID)))
      self.request = request
      request.delegate = self
      request.start()

      // StoreKit may not call back when the simulator has no StoreKit configuration or network.
      let timeout = DispatchWorkItem { [weak self] in
        guard let self, self.requestGeneration == generation else { return }
        self.request = nil
        self.delegate?.purchaseManagerLoading(false)
        self.delegate?.purchaseManagerDidUpdateProducts([])
        self.delegate?.purchaseManagerDidFail("Coin packs are temporarily unavailable. Please try again.")
      }
      requestTimeout = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
    }
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
      guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
          self?.handleProductsResponse(request, response: response)
        }
        return
      }
      handleProductsResponse(request, response: response)
    }
    private func handleProductsResponse(
      _ request: SKProductsRequest, response: SKProductsResponse
    ) {
      guard request === self.request else { return }
      requestTimeout?.cancel()
      self.request = nil
      storeProducts = Dictionary(uniqueKeysWithValues: response.products.map { ($0.productIdentifier, $0) })
      let display = response.products.compactMap { product -> PurchaseDisplayProduct? in
        guard let configuration = configurationsByID[product.productIdentifier] else { return nil }
        return .init(id: product.productIdentifier, usdPrice: configuration.usdPrice, reward: configuration.reward)
      }.sorted { lhs, rhs in
        configurations.firstIndex(where: { $0.productID == lhs.id }) ?? 0
          < configurations.firstIndex(where: { $0.productID == rhs.id }) ?? 0
      }
      delegate?.purchaseManagerLoading(false)
      delegate?.purchaseManagerDidUpdateProducts(display)
    }
    func request(_ request: SKRequest, didFailWithError error: Error) {
      guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
          self?.handleProductsFailure(request)
        }
        return
      }
      handleProductsFailure(request)
    }
    private func handleProductsFailure(_ request: SKRequest) {
      guard request === self.request else { return }
      requestTimeout?.cancel()
      self.request = nil
      delegate?.purchaseManagerLoading(false)
      delegate?.purchaseManagerDidUpdateProducts([])
      delegate?.purchaseManagerDidFail("Products are unavailable. Please try again.")
    }
    func buy(productID: String) { guard let product = storeProducts[productID], rewards[productID] != nil, SKPaymentQueue.canMakePayments(), let userID = AppRepository.shared.currentUserID else { delegate?.purchaseManagerDidFail("This product is unavailable."); return }; let payment = SKMutablePayment(product: product); payment.applicationUsername = userID; delegate?.purchaseManagerLoading(true); SKPaymentQueue.default().add(payment) }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        guard Thread.isMainThread else {
          DispatchQueue.main.async { [weak self] in
            self?.handleTransactions(queue, transactions: transactions)
          }
          return
        }
        handleTransactions(queue, transactions: transactions)
    }
    private func handleTransactions(
      _ queue: SKPaymentQueue, transactions: [SKPaymentTransaction]
    ) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                let productID = transaction.payment.productIdentifier
                guard let reward = rewards[productID] else {
                  queue.finishTransaction(transaction)
                  delegate?.purchaseManagerLoading(false)
                  delegate?.purchaseManagerDidFail("This product is unavailable.")
                  continue
                }
                // StoreKit V1 reports a successful transaction locally. No receipt validation is performed.
                let transactionID = transaction.transactionIdentifier ?? UUID().uuidString
                let credited = AppRepository.shared.creditPurchase(
                  transactionID: transactionID, productID: productID, reward: reward,
                  userID: transaction.payment.applicationUsername)
                queue.finishTransaction(transaction); delegate?.purchaseManagerLoading(false)
                if credited { delegate?.purchaseManagerDidPurchase(reward: reward) }
            case .failed:
                queue.finishTransaction(transaction); delegate?.purchaseManagerLoading(false)
                if (transaction.error as? SKError)?.code != .paymentCancelled { delegate?.purchaseManagerDidFail("Purchase could not be completed.") }
            case .restored: queue.finishTransaction(transaction); delegate?.purchaseManagerLoading(false)
            default: break
            }
        }
    }
}
