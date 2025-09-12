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
    
    // MARK: - テスト用フラグ（本番時は削除）
    @Published var isTestMode: Bool = false  // true → false に変更
    // MARK: - Initialization
    override init() {
        super.init()
        loadPurchaseState()
        
        // StoreKit監視開始
        SKPaymentQueue.default().add(self)
        
        // 商品情報を読み込み
        loadProduct()
    }
    
    deinit {
        // StoreKit監視停止
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - 購入状態管理
    
    private func loadPurchaseState() {
        isPurchased = UserDefaults.standard.bool(forKey: purchaseKey)
        print("購入状態読み込み: \(isPurchased ? "購入済み" : "無料版")")
    }
    
    private func savePurchaseState(_ purchased: Bool) {
        isPurchased = purchased
        UserDefaults.standard.set(purchased, forKey: purchaseKey)
        print("購入状態保存: \(purchased ? "購入済み" : "無料版")")
    }
    
    // MARK: - 機能制限チェック
    
    func canCreateNewProject(currentProjectCount: Int) -> Bool {
        if isPurchased {
            return true // 購入済みなら無制限
        }
        return currentProjectCount < 3 // 無料版は3個まで
    }
    
    func canExportVideo() -> Bool {
        return isPurchased // 購入済みのみエクスポート可能
    }
    
    // MARK: - StoreKit商品管理
    
    func loadProduct() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request = SKProductsRequest(productIdentifiers: [productID])
        request.delegate = self
        request.start()
        
        print("商品情報を読み込み中: \(productID)")
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let product = response.products.first {
                self.product = product
                let currencySymbol = product.priceLocale.currencySymbol ?? "$"
                print("商品情報取得成功: \(product.localizedTitle) - \(currencySymbol)\(product.price)")
            } else {
                self.errorMessage = "商品情報を取得できませんでした"
                print("エラー: 商品が見つかりません")
            }
            
            // 無効な商品IDがある場合
            if !response.invalidProductIdentifiers.isEmpty {
                print("無効な商品ID: \(response.invalidProductIdentifiers)")
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "ネットワークエラー: \(error.localizedDescription)"
            print("商品情報取得エラー: \(error)")
        }
    }
    
    // MARK: - 購入処理
    
    func purchase() {
        // テストモードの場合
        if isTestMode {
            simulatePurchase()
            return
        }
        
        // 実際の購入処理
        guard let product = product else {
            errorMessage = "商品情報がありません"
            return
        }
        
        guard SKPaymentQueue.canMakePayments() else {
            errorMessage = "この端末では購入できません"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
        
        print("購入開始: \(product.localizedTitle)")
    }
    
    func restorePurchases() {
        // テストモードの場合は何もしない
        if isTestMode {
            print("テストモード: 復元は実装されていません")
            return
        }
        
        isLoading = true
        errorMessage = nil
        SKPaymentQueue.default().restoreCompletedTransactions()
        print("購入復元開始")
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
                print("購入処理中...")
            case .deferred:
                print("購入が保留されています")
            default:
                print("未知の取引状態")
            }
        }
    }
    
    private func handlePurchaseSuccess(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.savePurchaseState(true)
            self.isLoading = false
            self.errorMessage = nil
            print("購入成功: \(transaction.payment.productIdentifier)")
        }
        
        // 取引完了
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handlePurchaseFailure(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let error = transaction.error as? SKError {
                switch error.code {
                case .paymentCancelled:
                    self.errorMessage = nil // キャンセルはエラー表示しない
                    print("購入キャンセル")
                case .paymentNotAllowed:
                    self.errorMessage = "この端末では購入できません"
                case .paymentInvalid:
                    self.errorMessage = "購入情報が無効です"
                case .storeProductNotAvailable:
                    self.errorMessage = "この商品は利用できません"
                default:
                    self.errorMessage = "購入エラー: \(error.localizedDescription)"
                }
            } else {
                self.errorMessage = "購入処理でエラーが発生しました"
            }
        }
        
        // 失敗した取引も完了させる
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    // MARK: - 価格表示用のヘルパー関数
    
    func formattedPrice() -> String {
        guard let product = product else { return "$2.99" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        
        return formatter.string(from: product.price) ?? "$2.99"
    }
    
    // MARK: - テスト用機能（本番時は削除予定）
    
    func simulatePurchase() {
        savePurchaseState(true)
        print("テスト購入をシミュレートしました")
    }
    
    func resetPurchase() {
        savePurchaseState(false)
        print("テスト購入をリセットしました")
    }
    
    func toggleTestMode() {
        isTestMode.toggle()
        print("テストモード: \(isTestMode ? "ON" : "OFF")")
    }
}
