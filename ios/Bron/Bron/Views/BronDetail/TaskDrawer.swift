//
//  TaskDrawer.swift
//  Bron
//
//  Control Panel - task details and execution
//  Deep red only appears here (if anywhere)
//

import SwiftUI

struct TaskDrawer: View {
    let bronId: UUID
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var currentTask: BronTask?
    @State private var showExecuteConfirmation = false
    @State private var isExecuting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                BronColors.surface
                    .ignoresSafeArea()
                
                if let task = currentTask {
                    taskContent(task)
                } else {
                    emptyState
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TASK DETAILS")
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(BronTypography.button)
                            .foregroundStyle(BronColors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            loadCurrentTask()
        }
        .confirmationDialog(
            "EXECUTE TASK",
            isPresented: $showExecuteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Execute Now") {
                executeTask()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ready to proceed. Review the details first if needed.")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BronLayout.spacingXL) {
            BronAvatar(size: .large, state: .idle)
            
            VStack(spacing: BronLayout.spacingM) {
                Text("NO ACTIVE TASK")
                    .displayStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("Send a message to get started.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
    }
    
    // MARK: - Task Content
    
    @ViewBuilder
    private func taskContent(_ task: BronTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with commit rule
                taskHeader(task)
                
                BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                
                // Checklist
                checklistSection(task)
                
                BronDivider()
                
                // Metadata
                metadataSection(task)
            }
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            executeSection(task)
        }
    }
    
    // MARK: - Task Header
    
    private func taskHeader(_ task: BronTask) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Commit rule (only for ready tasks)
            if task.state == .ready {
                CommitRule(orientation: .vertical, length: nil)
            }
            
            VStack(alignment: .leading, spacing: BronLayout.spacingS) {
                Text(task.title.uppercased())
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
                
                BronStatusBadge(status: task.state.displayName)
            }
            .padding(BronLayout.spacingL)
        }
    }
    
    // MARK: - Checklist Section
    
    private func checklistSection(_ task: BronTask) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            // Section header
            Text("REQUIREMENTS")
                .displayStyle(.small)
                .foregroundStyle(BronColors.textSecondary)
                .padding(.top, BronLayout.spacingL)
            
            // Checklist items (derived from task)
            VStack(alignment: .leading, spacing: BronLayout.spacingS) {
                ChecklistItem(text: "Task created", isComplete: true)
                ChecklistItem(text: "Information gathered", isComplete: task.progress > 0.3)
                ChecklistItem(text: "Plan confirmed", isComplete: task.progress > 0.5)
                ChecklistItem(text: "Ready for execution", isComplete: task.state == .ready)
            }
            .padding(.bottom, BronLayout.spacingL)
        }
        .padding(.horizontal, BronLayout.spacingL)
    }
    
    // MARK: - Metadata Section
    
    private func metadataSection(_ task: BronTask) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            if let nextAction = task.nextAction {
                MetadataRow(label: "NEXT ACTION", value: nextAction)
            }
            
            if let waitingOn = task.waitingOn {
                MetadataRow(label: "WAITING ON", value: waitingOn)
            }
            
            MetadataRow(
                label: "PROGRESS",
                value: "\(Int(task.progress * 100))%"
            )
            
            MetadataRow(
                label: "CREATED",
                value: task.createdAt.formatted(date: .abbreviated, time: .shortened)
            )
            
            MetadataRow(
                label: "UPDATED",
                value: task.updatedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
        .padding(BronLayout.spacingL)
    }
    
    // MARK: - Execute Section
    
    private func executeSection(_ task: BronTask) -> some View {
        VStack(spacing: BronLayout.spacingM) {
            BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
            
            Button {
                if canExecute(task) {
                    showExecuteConfirmation = true
                }
            } label: {
                HStack(spacing: BronLayout.spacingS) {
                    if isExecuting {
                        ProgressView()
                            .tint(canExecute(task) ? BronColors.commit : BronColors.gray500)
                    }
                    Text(executeButtonText(for: task))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CommitButtonStyle(isEnabled: canExecute(task)))
            .disabled(!canExecute(task))
            
            if !canExecute(task) {
                Text(gatingMessage(for: task))
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
        }
        .padding(BronLayout.spacingL)
        .background(BronColors.surface)
    }
    
    // MARK: - Helpers
    
    private func loadCurrentTask() {
        currentTask = appState.taskRepository.tasks.first { task in
            appState.bronRepository.brons.first { $0.id == bronId }?.currentTaskId == task.id
        }
        
        if currentTask == nil {
            currentTask = appState.taskRepository.tasks.first { $0.bronId == bronId }
        }
    }
    
    private func executeTask() {
        guard let task = currentTask, canExecute(task) else { return }
        
        isExecuting = true
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isExecuting = false
                var updatedTask = task
                updatedTask.state = .executing
                appState.taskRepository.update(updatedTask)
                currentTask = updatedTask
            }
        }
    }
    
    private func canExecute(_ task: BronTask) -> Bool {
        task.state == .ready && !isExecuting
    }
    
    private func executeButtonText(for task: BronTask) -> String {
        if isExecuting {
            return "EXECUTING..."
        }
        switch task.state {
        case .ready: return "EXECUTE TASK"
        case .executing: return "IN PROGRESS"
        case .done: return "COMPLETED"
        default: return "NOT READY"
        }
    }
    
    private func gatingMessage(for task: BronTask) -> String {
        switch task.state {
        case .draft: return "Setting up"
        case .needsInfo: return "I need one thing to continue"
        case .planned: return "Plan ready — want to adjust it?"
        case .executing: return "Working on it"
        case .waiting: return "Waiting on external action"
        case .done: return "Done"
        case .failed: return "Something went wrong — review and retry"
        case .ready: return ""
        }
    }
}

// MARK: - Checklist Item

struct ChecklistItem: View {
    let text: String
    let isComplete: Bool
    
    var body: some View {
        HStack(spacing: BronLayout.spacingM) {
            Image(systemName: isComplete ? "checkmark.square.fill" : "square")
                .foregroundStyle(isComplete ? BronColors.black : BronColors.gray300)
            
            Text(text)
                .utilityStyle(.medium)
                .foregroundStyle(isComplete ? BronColors.textPrimary : BronColors.textMeta)
        }
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
            Text(label)
                .font(BronTypography.meta)
                .tracking(1)
                .foregroundStyle(BronColors.textMeta)
            
            Text(value)
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textPrimary)
        }
    }
}

#Preview {
    TaskDrawer(bronId: UUID())
        .environmentObject(AppState(persistenceController: .preview))
}
