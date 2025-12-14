//
//  SettingsView.swift
//  Bron
//
//  Settings - broadcast style
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredTone") private var preferredTone: String = "balanced"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                BronColors.surface
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                        
                        // Personalization
                        settingsSection(title: "PERSONALIZATION") {
                            SettingsRow(title: "COMMUNICATION TONE") {
                                Picker("", selection: $preferredTone) {
                                    Text("Concise").tag("concise")
                                    Text("Balanced").tag("balanced")
                                    Text("Detailed").tag("detailed")
                                }
                                .pickerStyle(.menu)
                                .tint(BronColors.textSecondary)
                            }
                        }
                        
                        BronDivider()
                        
                        // Notifications
                        settingsSection(title: "NOTIFICATIONS") {
                            SettingsRow(title: "ENABLE NOTIFICATIONS") {
                                Toggle("", isOn: $notificationsEnabled)
                                    .tint(BronColors.black)
                            }
                        }
                        
                        BronDivider()
                        
                        // Skills
                        settingsSection(title: "SKILLS") {
                            NavigationLink {
                                SkillsListView()
                            } label: {
                                SettingsRow(title: "MANAGE SKILLS") {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(BronColors.gray300)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        BronDivider()
                        
                        // About
                        settingsSection(title: "ABOUT") {
                            SettingsRow(title: "VERSION") {
                                Text("0.1.0")
                                    .utilityStyle(.medium)
                                    .foregroundStyle(BronColors.textMeta)
                            }
                            
                            Link(destination: URL(string: "https://github.com")!) {
                                SettingsRow(title: "VIEW ON GITHUB") {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(BronColors.gray300)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .displayStyle(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
        }
    }
    
    // MARK: - Section Builder
    
    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .displayStyle(.small)
                .foregroundStyle(BronColors.textSecondary)
                .padding(BronLayout.spacingM)
            
            content()
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    
    var body: some View {
        HStack {
            Text(title)
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textPrimary)
            
            Spacer()
            
            accessory()
        }
        .padding(.horizontal, BronLayout.spacingM)
        .padding(.vertical, BronLayout.spacingS)
    }
}

#Preview {
    SettingsView()
}
