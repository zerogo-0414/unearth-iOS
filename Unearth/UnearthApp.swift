//
//  UnearthApp.swift
//  Unearth
//
//  Created by Theo on 2026/5/29.
//

import SwiftUI
import SwiftData
import AMapFoundationKit
import AMapLocationKit

@main
struct UnearthApp: App {
    init() {
        // 配置高德 API Key
        AMapServices.shared().apiKey = "34377153f10506458c223cfc18f365ce"

        // 隐私合规：设置隐私政策已展示且用户已同意
        AMapLocationManager.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapLocationManager.updatePrivacyAgree(.didAgree)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
