// MARK: - 新しいファイル: PurchaseManager.swift を作成
// Xcodeで新規ファイル作成してこのコードを貼り付けてください

import Foundation

class PurchaseManager: ObservableObject {
    @Published var isPurchased = false
    
    // UserDefaultsに購入状態を保存するキー
    private let purchaseKey = "clipflow_full_version_purchased"
    
    init() {
        loadPurchaseState()
    }
    
    // MARK: - 購入状態の読み込み・保存
    
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
    
    // MARK: - テスト用の購入シミュレーション
    
    func simulatePurchase() {
        savePurchaseState(true)
        print("購入をシミュレートしました")
    }
    
    func resetPurchase() {
        savePurchaseState(false)
        print("購入をリセットしました")
    }
}//
//  PurchaseManager.swift
//  JourneyMoments
//
//  Created by 谷澤健二 on 2025/09/11.
//

