import SwiftUI

struct PurchaseView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("ClipFlow Full Version")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Unlock unlimited projects and export features")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // 機能説明
                VStack(spacing: 16) {
                    FeatureRow(icon: "folder.fill", title: "Unlimited Projects", description: "Create as many projects as you want")
                    FeatureRow(icon: "square.and.arrow.up.fill", title: "Export Videos", description: "Save your memories to Photos")
                    FeatureRow(icon: "checkmark.seal.fill", title: "One-Time Purchase", description: "No monthly fees or subscriptions")
                }
                
                Spacer()
                
                // 価格・購入ボタン
                VStack(spacing: 12) {
                    if purchaseManager.isLoading {
                        ProgressView("Loading...")
                            .frame(height: 50)
                    } else {
                        // 購入ボタン
                        Button(action: {
                            purchaseManager.purchase()
                        }) {
                            HStack {
                                Text("Purchase Full Version")
                                Spacer()
                                Text(purchaseManager.formattedPrice())
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(purchaseManager.isLoading)
                        
                        // 復元ボタン
                        Button(action: {
                            purchaseManager.restorePurchases()
                        }) {
                            Text("Restore Previous Purchase")
                                .font(.body)
                                .foregroundColor(.blue)
                        }
                        .disabled(purchaseManager.isLoading)
                    }
                }
                
                // エラーメッセージ
                if let errorMessage = purchaseManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // テストモード表示（デバッグ用）
                if purchaseManager.isTestMode {
                    VStack(spacing: 8) {
                        Text("🧪 TEST MODE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        HStack(spacing: 12) {
                            Button("Test Purchase") {
                                purchaseManager.simulatePurchase()
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            
                            Button("Reset") {
                                purchaseManager.resetPurchase()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Upgrade")
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onReceive(purchaseManager.$isPurchased) { isPurchased in
            if isPurchased {
                // 購入成功時は画面を閉じる
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView(purchaseManager: PurchaseManager())
    }
}
