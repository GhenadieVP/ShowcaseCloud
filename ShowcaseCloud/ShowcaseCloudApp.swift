//
//  ShowcaseCloudApp.swift
//  ShowcaseCloud
//
//  Created by Ghenadie Vasiliev-Pusca on 06.02.2024.
//

import SwiftUI

@main
struct ShowcaseCloudApp: App {
    var body: some Scene {
        WindowGroup {
            MainFeature.View(store: .init(initialState: .init(), reducer: {
                MainFeature()
            }))
        }
    }
}
