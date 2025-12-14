//
//  ContentView.swift
//  Bron
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            BronListView()
                .tabItem {
                    Label("Brons", systemImage: "person.3.fill")
                }
            
            TaskSpreadsheetView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet.rectangle")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState(persistenceController: .preview))
}

