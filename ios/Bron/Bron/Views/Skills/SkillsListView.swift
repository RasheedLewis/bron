//
//  SkillsListView.swift
//  Bron
//
//  List of saved Skills
//  Placeholder for PR-08 implementation
//

import SwiftUI

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    
    private var skills: [Skill] {
        appState.skillRepository.skills
    }
    
    var body: some View {
        Group {
            if skills.isEmpty {
                ContentUnavailableView {
                    Label("No Skills Yet", systemImage: "wand.and.stars")
                } description: {
                    Text("Save a task as a Skill to reuse it later.")
                }
            } else {
                List(skills) { skill in
                    NavigationLink(value: skill.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(skill.name)
                                .font(.headline)
                            Text("\(skill.steps.count) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Skills")
        .refreshable {
            appState.skillRepository.fetchAll()
        }
    }
}

#Preview {
    NavigationStack {
        SkillsListView()
            .environmentObject(AppState(persistenceController: .preview))
    }
}

