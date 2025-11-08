import Foundation
import StoreKit

class PurchaseManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    // MARK: - Published Properties
    @Published var isPurchased: Bool = false
    @Published var product: SKProduct?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let productID = "com.tashichi.clipflow.fullversion"
    private let purchaseKey = "ClipFlowFullVersionPurchased"
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        #if targetEnvironment(simulator)
        // シミュレーター：常に未課金に強制（テスト用）
        isPurchased = false
        print("🔧 SIMULATOR MODE: isPurchased forced to false for testing")
        #else
        // 実機：UserDefaultsから読み込む
        loadPurchaseState()
        #endif
        
        // Start StoreKit monitoring
        SKPaymentQueue.default().add(self)
        
        // Load product information
        loadProduct()
    }
    
    deinit {
        // Stop StoreKit monitoring
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - Purchase State Management
    
    private func loadPurchaseState() {
        isPurchased = UserDefaults.standard.bool(forKey: purchaseKey)
        print("Purchase state loaded: \(isPurchased ? "Purchased" : "Free version")")
    }
    
    private func savePurchaseState(_ purchased: Bool) {
        #if targetEnvironment(simulator)
        print("⚠️ SIMULATOR: savePurchaseState called but not saving (simulator test mode)")
        return
        #endif
        
        isPurchased = purchased
        UserDefaults.standard.set(purchased, forKey: purchaseKey)
        print("Purchase state saved: \(purchased ? "Purchased" : "Free version")")
    }
    
    // MARK: - Feature Restriction Checks
    
    func canCreateNewProject(currentProjectCount: Int) -> Bool {
        if isPurchased {
            return true // Unlimited if purchased
        }
        return currentProjectCount < 3 // Free version limited to 3
    }
    
    func canExportVideo() -> Bool {
        return isPurchased // Export only available for purchased version
    }
    
    // MARK: - StoreKit Product Management
    
    func loadProduct() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request = SKProductsRequest(productIdentifiers: [productID])
        request.delegate = self
        request.start()
        
        print("Loading product information: \(productID)")
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        print("商品ID: \(productID)")
        print("商品取得結果: \(response.products)")
        print("無効な商品ID: \(response.invalidProductIdentifiers)")
        
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let product = response.products.first {
                self.product = product
                let currencySymbol = product.priceLocale.currencySymbol ?? "$"
                print("Product information loaded successfully: \(product.localizedTitle) - \(currencySymbol)\(product.price)")
            } else {
                self.errorMessage = "Unable to load product information"
                print("Error: Product not found")
            }
            
            if !response.invalidProductIdentifiers.isEmpty {
                print("Invalid product IDs: \(response.invalidProductIdentifiers)")
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Network error: \(error.localizedDescription)"
            print("Product information loading error: \(error)")
        }
    }
    
    // MARK: - Purchase Processing

    func purchase() {
        guard let product = product else {
            print("Product information not available, attempting reload")
            loadProduct()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.product != nil {
                    self.purchase()
                } else {
                    self.errorMessage = "Unable to load product information. Please try again later."
                }
            }
            return
        }
        
        guard SKPaymentQueue.canMakePayments() else {
            errorMessage = "Purchases are not available on this device"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        
        print("Purchase started: \(product.localizedTitle)")
    }

    func restorePurchases() {
        isLoading = true
        errorMessage = nil
        SKPaymentQueue.default().restoreCompletedTransactions()
        print("Restore purchases started")
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchaseSuccess(transaction)
            case .restored:
                handlePurchaseSuccess(transaction)
            case .failed:
                handlePurchaseFailure(transaction)
            case .purchasing:
                print("Purchase in progress...")
            case .deferred:
                print("Purchase is pending")
            @unknown default:
                print("Unknown transaction state")
            }
        }
    }
    
    private func handlePurchaseSuccess(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.savePurchaseState(true)
            self.isLoading = false
            self.errorMessage = nil
            print("Purchase successful: \(transaction.payment.productIdentifier)")
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handlePurchaseFailure(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let error = transaction.error as? SKError {
                switch error.code {
                case .paymentCancelled:
                    self.errorMessage = nil
                    print("Purchase cancelled")
                case .paymentNotAllowed:
                    self.errorMessage = "Purchases are not available on this device"
                case .paymentInvalid:
                    self.errorMessage = "Purchase information is invalid"
                case .storeProductNotAvailable:
                    self.errorMessage = "This product is not available"
                @unknown default:
                    self.errorMessage = "Purchase error: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "An error occurred during purchase processing"
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    // MARK: - Helper Functions for Price Display
    
    func formattedPrice() -> String {
        guard let product = product else { return "$2.99" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        
        return formatter.string(from: product.price) ?? "$2.99"
    }
}
