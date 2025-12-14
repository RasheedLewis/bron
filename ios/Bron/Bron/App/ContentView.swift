//
//  ContentView.swift
//  Bron
//
//  Main navigation - championship broadcast style
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BronListView()
                .tabItem {
                    Label("BRONS", systemImage: "person.3")
                }
                .tag(0)
            
            TaskSpreadsheetView()
                .tabItem {
                    Label("TASKS", systemImage: "list.bullet")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("SETTINGS", systemImage: "gear")
                }
                .tag(2)
        }
        .tint(BronColors.black)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState(persistenceController: .preview))
}
