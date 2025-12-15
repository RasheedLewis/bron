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
        if bron.status == .completed {
            return .success
        }
        return AvatarState.from(taskState: bron.currentTask?.state.rawValue)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: BronLayout.spacingM) {
            // Commit rule for items needing attention
            if needsAttention {
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
                
                // Current step (if available)
                if let stepInfo = currentStepInfo {
                    Text(stepInfo)
                        .utilityStyle(.small)
                        .foregroundStyle(BronColors.textSecondary)
                        .lineLimit(1)
                }
                
                // Status badge and metadata row
                HStack(spacing: BronLayout.spacingM) {
                    BronStatusBadge(status: statusText)
                    
                    if let progress = progressText {
                        Text(progress)
                            .utilityStyle(.meta)
                            .foregroundStyle(BronColors.textMeta)
                    }
                    
                    Spacer()
                    
                    Text(bron.updatedAt, style: .relative)
                        .utilityStyle(.meta)
                        .foregroundStyle(BronColors.textMeta)
                }
            }
            
            Spacer(minLength: 0)
            
            // Quick action or chevron
            quickActionView
        }
        .padding(.vertical, BronLayout.spacingM)
        .padding(.horizontal, BronLayout.spacingM)
        .contentShape(Rectangle())
    }
    
    // MARK: - Quick Actions
    
    @ViewBuilder
    private var quickActionView: some View {
        if bron.status == .needsInfo {
            // Needs attention indicator
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(BronColors.commit)
        } else if bron.status == .ready {
            // Ready to execute
            Image(systemName: "play.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(BronColors.textSecondary)
        } else if bron.status == .completed {
            // Completed checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(BronColors.textMeta)
        } else {
            // Default chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BronColors.gray300)
        }
    }
    
    // MARK: - Computed Properties
    
    private var needsAttention: Bool {
        bron.status == .needsInfo || bron.status == .ready
    }
    
    private var taskTitle: String {
        bron.currentTask?.title.uppercased() ?? bron.name.uppercased()
    }
    
    private var statusText: String {
        bron.currentTask?.state.displayName ?? bron.status.displayName
    }
    
    /// Current step info (e.g., "Step 2: Research flights") or what we're waiting on
    private var currentStepInfo: String? {
        guard let task = bron.currentTask else { return nil }
        
        // If waiting on something specific (like auth), show that
        if let waitingOn = task.waitingOn, !waitingOn.isEmpty {
            return "→ \(waitingOn)"
        }
        
        // Otherwise show current step
        guard !task.steps.isEmpty,
              let currentStep = task.currentStep,
              let stepIndex = task.currentStepIndex else {
            return nil
        }
        return "Step \(stepIndex): \(currentStep.title)"
    }
    
    /// Progress text (e.g., "2/5")
    private var progressText: String? {
        guard let task = bron.currentTask, !task.steps.isEmpty else {
            return nil
        }
        return "\(task.completedStepCount)/\(task.steps.count)"
    }
}

#Preview {
    VStack(spacing: 0) {
        // Needs info - with steps
        ActiveBronCard(bron: BronInstance(
            name: "Austin Trip",
            status: .needsInfo,
            currentTask: BronTask(
                title: "Plan Trip to Austin",
                state: .needsInfo,
                category: .personal,
                bronId: UUID(),
                steps: [
                    TaskStep(title: "Gather trip details", status: .completed, order: 0),
                    TaskStep(title: "Research flights", status: .inProgress, order: 1),
                    TaskStep(title: "Book hotel", status: .pending, order: 2),
                    TaskStep(title: "Create itinerary", status: .pending, order: 3),
                ]
            )
        ))
        
        BronDivider()
            .padding(.horizontal)
        
        // Working - with steps
        ActiveBronCard(bron: BronInstance(
            name: "Expense Report",
            status: .working,
            currentTask: BronTask(
                title: "Submit Expense Receipt",
                state: .executing,
                category: .admin,
                bronId: UUID(),
                steps: [
                    TaskStep(title: "Upload receipt", status: .completed, order: 0),
                    TaskStep(title: "Extract details", status: .completed, order: 1),
                    TaskStep(title: "Submit to system", status: .inProgress, order: 2),
                ]
            )
        ))
        
        BronDivider()
            .padding(.horizontal)
        
        // Ready to execute
        ActiveBronCard(bron: BronInstance(
            name: "Email Draft",
            status: .ready,
            currentTask: BronTask(
                title: "Send Meeting Follow-up",
                state: .ready,
                category: .work,
                bronId: UUID(),
                steps: [
                    TaskStep(title: "Draft email", status: .completed, order: 0),
                    TaskStep(title: "Review", status: .completed, order: 1),
                    TaskStep(title: "Send", status: .pending, order: 2),
                ]
            )
        ))
        
        BronDivider()
            .padding(.horizontal)
        
        // Completed
        ActiveBronCard(bron: BronInstance(
            name: "Weather Check",
            status: .completed,
            currentTask: BronTask(
                title: "Daily Weather Update",
                state: .done,
                category: .personal,
                bronId: UUID(),
                steps: [
                    TaskStep(title: "Check forecast", status: .completed, order: 0),
                    TaskStep(title: "Send summary", status: .completed, order: 1),
                ]
            )
        ))
    }
    .background(BronColors.surface)
}
