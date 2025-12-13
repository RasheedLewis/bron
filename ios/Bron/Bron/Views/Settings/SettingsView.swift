//
//  SettingsView.swift
//  Bron
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredTone") private var preferredTone: String = "balanced"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personalization") {
                    Picker("Communication Tone", selection: $preferredTone) {
                        Text("Concise").tag("concise")
                        Text("Balanced").tag("balanced")
                        Text("Detailed").tag("detailed")
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                }
                
                Section("Skills") {
                    NavigationLink("Manage Skills") {
                        SkillsListView()
                    }
                }
                
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        Label("View on GitHub", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}

