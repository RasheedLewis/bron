//
//  SkillsListView.swift
//  Bron
//
//  Skills list - broadcast style
//

import SwiftUI

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    
    private var skills: [Skill] {
        appState.skillRepository.skills
    }
    
    var body: some View {
        ZStack {
            BronColors.surface
                .ignoresSafeArea()
            
            if skills.isEmpty {
                emptyState
            } else {
                skillsList
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("SKILLS")
                    .displayStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
            }
        }
        .refreshable {
            appState.skillRepository.fetchAll()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BronLayout.spacingXL) {
            Image(systemName: "star")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BronColors.gray300)
            
            VStack(spacing: BronLayout.spacingM) {
                Text("NO SKILLS YET")
                    .displayStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("Save a workflow to reuse it.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BronLayout.spacingXL)
            }
        }
    }
    
    // MARK: - Skills List
    
    private var skillsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                    .padding(.horizontal)
                
                ForEach(skills) { skill in
                    SkillRow(skill: skill)
                    
                    BronDivider()
                        .padding(.horizontal)
                }
            }
            .padding(.top, BronLayout.spacingM)
        }
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: Skill
    
    var body: some View {
        HStack(spacing: BronLayout.spacingM) {
            VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                Text(skill.name.uppercased())
                    .displayStyle(.small)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("\(skill.steps.count) steps")
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(BronColors.gray300)
        }
        .padding(BronLayout.spacingM)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        SkillsListView()
            .environmentObject(AppState(persistenceController: .preview))
    }
}
