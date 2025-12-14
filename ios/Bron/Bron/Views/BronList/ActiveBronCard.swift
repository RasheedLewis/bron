//
//  ActiveBronCard.swift
//  Bron
//
//  Bron roster card - broadcast rundown style
//

import SwiftUI

struct ActiveBronCard: View {
    let bron: BronInstance
    
    private var avatarState: AvatarState {
        AvatarState.from(taskState: bron.currentTask?.state.rawValue)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: BronLayout.spacingM) {
            // Commit rule for active items
            if isActive {
                CommitRule(orientation: .vertical, length: nil)
            }
            
            // Avatar - only colored element
            BronAvatar(size: .medium, state: avatarState)
            
            // Content
            VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                // Task title (or Bron name if no task)
                Text(taskTitle)
                    .displayStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
                    .lineLimit(1)
                
                // Status
                BronStatusBadge(status: statusText)
                
                // Metadata
                HStack(spacing: BronLayout.spacingM) {
                    if let progress = progressText {
                        Text(progress)
                            .utilityStyle(.meta)
                            .foregroundStyle(BronColors.textMeta)
                    }
                    
                    Text(bron.updatedAt, style: .relative)
                        .utilityStyle(.meta)
                        .foregroundStyle(BronColors.textMeta)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BronColors.gray300)
        }
        .padding(.vertical, BronLayout.spacingM)
        .padding(.horizontal, BronLayout.spacingM)
        .contentShape(Rectangle())
    }
    
    // MARK: - Computed Properties
    
    private var isActive: Bool {
        bron.status == .working || bron.status == .needsInfo
    }
    
    private var taskTitle: String {
        bron.currentTask?.title.uppercased() ?? bron.name.uppercased()
    }
    
    private var statusText: String {
        bron.currentTask?.state.displayName ?? bron.status.displayName
    }
    
    private var progressText: String? {
        guard let task = bron.currentTask else { return nil }
        let steps = Int(task.progress * 5) + 1
        return "Step \(steps)/5"
    }
}

#Preview {
    VStack(spacing: 0) {
        ActiveBronCard(bron: BronInstance(
            name: "Receipt Helper",
            status: .working,
            currentTask: BronTask(
                title: "Submit Expense Receipt",
                state: .needsInfo,
                category: .admin,
                bronId: UUID(),
                progress: 0.4
            )
        ))
        
        BronDivider()
            .padding(.horizontal)
        
        ActiveBronCard(bron: BronInstance(
            name: "Podcast Setup",
            status: .working,
            currentTask: BronTask(
                title: "Setup Podcast Episode",
                state: .executing,
                category: .creative,
                bronId: UUID(),
                progress: 0.6
            )
        ))
        
        BronDivider()
            .padding(.horizontal)
        
        ActiveBronCard(bron: BronInstance(
            name: "Weather Check",
            status: .ready,
            currentTask: BronTask(
                title: "Daily Weather Update",
                state: .ready,
                category: .personal,
                bronId: UUID(),
                progress: 1.0
            )
        ))
    }
    .background(BronColors.surface)
}
