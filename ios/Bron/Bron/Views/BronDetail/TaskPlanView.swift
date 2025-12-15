//
//  TaskPlanView.swift
//  Bron
//
//  Always-visible task plan in chat - like Cursor's todo list
//

import SwiftUI

struct TaskPlanView: View {
    let steps: [TaskStep]
    let taskTitle: String?
    var pendingRecipe: UIRecipe? = nil
    var waitingOn: String? = nil
    
    /// Current step being worked on
    private var currentStep: TaskStep? {
        steps.first { $0.status == .inProgress } ?? steps.first { $0.status == .pending }
    }
    
    /// Progress percentage
    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.filter { $0.status == .completed }.count
        return Double(completed) / Double(steps.count)
    }
    
    /// What Bron is currently waiting for
    private var currentAction: CurrentBronAction? {
        if let recipe = pendingRecipe {
            return CurrentBronAction.from(recipe: recipe)
        } else if let waiting = waitingOn, !waiting.isEmpty {
            return CurrentBronAction(icon: "clock", text: waiting, color: BronColors.textSecondary)
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
            
            // Divider
            BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
            
            // Current action banner (if waiting on something)
            if let action = currentAction {
                currentActionBanner(action)
                if !steps.isEmpty {
                    BronDivider()
                }
            }
            
            // Steps list (only if we have steps)
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(steps.sorted(by: { $0.order < $1.order })) { step in
                        stepRow(step)
                        
                        if step.id != steps.last?.id {
                            BronDivider()
                                .padding(.leading, 28) // Align with text
                        }
                    }
                }
            }
        }
        .background(BronColors.surface)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    // MARK: - Current Action Banner
    
    private func currentActionBanner(_ action: CurrentBronAction) -> some View {
        HStack(spacing: BronLayout.spacingS) {
            Image(systemName: action.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(action.color)
            
            Text(action.text)
                .utilityStyle(.small)
                .foregroundStyle(BronColors.textPrimary)
            
            Spacer()
            
            // Pulsing dot to show activity
            Circle()
                .fill(action.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(action.color.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.7)
                )
        }
        .padding(.horizontal, BronLayout.spacingM)
        .padding(.vertical, BronLayout.spacingS)
        .background(action.color.opacity(0.08))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: BronLayout.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAN")
                    .font(BronTypography.meta)
                    .tracking(1)
                    .foregroundStyle(BronColors.textMeta)
                
                if let title = taskTitle {
                    Text(title)
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Progress indicator
            progressPill
        }
        .padding(BronLayout.spacingM)
    }
    
    private var progressPill: some View {
        let completed = steps.filter { $0.status == .completed }.count
        
        return HStack(spacing: BronLayout.spacingXS) {
            Text("\(completed)/\(steps.count)")
                .font(BronTypography.meta)
                .foregroundStyle(BronColors.textMeta)
            
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(BronColors.gray150)
                    Rectangle()
                        .fill(progress >= 1.0 ? BronColors.textMeta : BronColors.black)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(width: 40, height: 4)
        }
    }
    
    // MARK: - Step Row
    
    private func stepRow(_ step: TaskStep) -> some View {
        let isCurrent = step.id == currentStep?.id
        
        return HStack(spacing: BronLayout.spacingS) {
            // Status icon
            Image(systemName: step.status.icon)
                .font(.system(size: 14, weight: step.status == .completed ? .semibold : .regular))
                .foregroundStyle(iconColor(for: step))
                .frame(width: 20)
            
            // Step title
            Text(step.title)
                .utilityStyle(isCurrent ? .medium : .small)
                .foregroundStyle(textColor(for: step))
                .strikethrough(step.status == .skipped, color: BronColors.textMeta)
            
            Spacer()
            
            // Current indicator
            if isCurrent && step.status == .inProgress {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, BronLayout.spacingM)
        .padding(.vertical, BronLayout.spacingS)
        .background(isCurrent ? BronColors.gray050 : Color.clear)
    }
    
    private func iconColor(for step: TaskStep) -> Color {
        switch step.status {
        case .completed:
            return BronColors.textMeta
        case .inProgress:
            return BronColors.black
        case .pending:
            return BronColors.gray300
        case .skipped:
            return BronColors.textMeta
        }
    }
    
    private func textColor(for step: TaskStep) -> Color {
        switch step.status {
        case .completed, .skipped:
            return BronColors.textMeta
        case .inProgress:
            return BronColors.textPrimary
        case .pending:
            return BronColors.textSecondary
        }
    }
}

// MARK: - Compact Version (for inline display)

struct TaskPlanCompact: View {
    let steps: [TaskStep]
    
    private var currentStep: TaskStep? {
        steps.first { $0.status == .inProgress } ?? steps.first { $0.status == .pending }
    }
    
    private var completed: Int {
        steps.filter { $0.status == .completed }.count
    }
    
    var body: some View {
        HStack(spacing: BronLayout.spacingS) {
            // Progress dots
            HStack(spacing: 2) {
                ForEach(steps.sorted(by: { $0.order < $1.order })) { step in
                    Circle()
                        .fill(dotColor(for: step))
                        .frame(width: 6, height: 6)
                }
            }
            
            // Current step text
            if let current = currentStep {
                Text(current.title)
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(completed)/\(steps.count)")
                .utilityStyle(.meta)
                .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private func dotColor(for step: TaskStep) -> Color {
        switch step.status {
        case .completed:
            return BronColors.textMeta
        case .inProgress:
            return BronColors.black
        case .pending:
            return BronColors.gray300
        case .skipped:
            return BronColors.gray150
        }
    }
}

// MARK: - Current Action Helper

struct CurrentBronAction {
    let icon: String
    let text: String
    let color: Color
    
    static func from(recipe: UIRecipe) -> CurrentBronAction {
        switch recipe.componentType {
        // Auth components
        case .authGoogle:
            return CurrentBronAction(
                icon: "person.badge.key",
                text: recipe.title ?? "Connecting to Google",
                color: Color(red: 0.26, green: 0.52, blue: 0.96)  // Google blue
            )
        case .authApple:
            return CurrentBronAction(
                icon: "apple.logo",
                text: recipe.title ?? "Connecting to Apple",
                color: BronColors.black
            )
        case .authOAuth, .serviceConnect:
            return CurrentBronAction(
                icon: "link",
                text: recipe.title ?? "Connecting service",
                color: BronColors.deepRed
            )
        case .apiKeyInput:
            return CurrentBronAction(
                icon: "key",
                text: recipe.title ?? "Need API key",
                color: Color.orange
            )
        case .credentialsInput:
            return CurrentBronAction(
                icon: "person.text.rectangle",
                text: recipe.title ?? "Need login credentials",
                color: BronColors.deepRed
            )
        case .authCallback:
            return CurrentBronAction(
                icon: "arrow.triangle.2.circlepath",
                text: "Completing authentication",
                color: BronColors.deepRed
            )
            
        // Approval/confirmation
        case .confirmation, .approval:
            return CurrentBronAction(
                icon: "checkmark.shield",
                text: recipe.title ?? "Need your approval",
                color: Color.orange
            )
            
        // Input forms
        case .form, .picker, .multiSelect, .datePicker, .contactPicker, .locationPicker:
            return CurrentBronAction(
                icon: "square.and.pencil",
                text: recipe.title ?? "Need some info",
                color: BronColors.textSecondary
            )
            
        // Execute
        case .execute:
            return CurrentBronAction(
                icon: "play.circle",
                text: recipe.title ?? "Ready to execute",
                color: BronColors.deepRed
            )
            
        default:
            return CurrentBronAction(
                icon: "clock",
                text: recipe.title ?? "Working on it",
                color: BronColors.textSecondary
            )
        }
    }
}

// MARK: - Preview

#Preview("Full Plan") {
    TaskPlanView(
        steps: TaskStep.previewPlan,
        taskTitle: "Plan Trip to Austin"
    )
    .padding()
}

#Preview("With Pending Auth") {
    TaskPlanView(
        steps: TaskStep.previewPlan,
        taskTitle: "Schedule Meeting",
        pendingRecipe: UIRecipe(
            componentType: .authGoogle,
            title: "Connect Google Calendar"
        )
    )
    .padding()
}

#Preview("Compact") {
    TaskPlanCompact(steps: TaskStep.previewPlan)
        .padding()
}

