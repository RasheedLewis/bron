//
//  BronApp.swift
//  Bron
//
//  Deep Agents for Everyone
//

import SwiftUI

@main
struct BronApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

