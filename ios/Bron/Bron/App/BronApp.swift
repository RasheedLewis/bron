//
//  BronApp.swift
//  Bron
//
//  Deep Agents for Everyone
//

import SwiftUI

@main
struct BronApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState: AppState
    
    init() {
        let controller = PersistenceController.shared
        _appState = StateObject(wrappedValue: AppState(persistenceController: controller))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(appState)
        }
    }
}

