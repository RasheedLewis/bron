//
//  TaskSpreadsheetView.swift
//  Bron
//
//  All Tasks - broadcast rundown style
//

import SwiftUI

struct TaskSpreadsheetView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\BronTask.updatedAt, order: .reverse)]
    
    private var tasks: [BronTask] {
        appState.taskRepository.tasks.sorted(using: sortOrder)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BronColors.surface
                    .ignoresSafeArea()
                
                if tasks.isEmpty {
                    emptyState
                } else {
                    tasksList
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ALL TASKS")
                        .displayStyle(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            .refreshable {
                appState.taskRepository.fetchAll()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BronLayout.spacingXL) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BronColors.gray300)
            
            VStack(spacing: BronLayout.spacingM) {
                Text("NO TASKS")
                    .displayStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("Your tasks will appear here.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header row
                taskHeaderRow
                
                BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                
                // Task rows
                ForEach(tasks) { task in
                    taskRow(task)
                    
                    BronDivider()
                }
            }
            .padding(.top, BronLayout.spacingM)
        }
    }
    
    // MARK: - Header Row
    
    private var taskHeaderRow: some View {
        HStack(spacing: BronLayout.spacingM) {
            Text("TASK")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("STATUS")
                .frame(width: 80)
            
            Text("UPDATED")
                .frame(width: 70)
        }
        .font(BronTypography.meta)
        .tracking(1)
        .foregroundStyle(BronColors.textMeta)
        .padding(.horizontal, BronLayout.spacingM)
        .padding(.vertical, BronLayout.spacingS)
    }
    
    // MARK: - Task Row
    
    private func taskRow(_ task: BronTask) -> some View {
        HStack(spacing: BronLayout.spacingM) {
            // Task title
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.uppercased())
                    .displayStyle(.small)
                    .foregroundStyle(BronColors.textPrimary)
                    .lineLimit(1)
                
                Text(task.category.rawValue.capitalized)
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Status
            BronStatusBadge(status: task.state.displayName, showDot: false)
                .frame(width: 80)
            
            // Updated
            Text(task.updatedAt, style: .relative)
                .utilityStyle(.meta)
                .foregroundStyle(BronColors.textMeta)
                .frame(width: 70)
        }
        .padding(.horizontal, BronLayout.spacingM)
        .padding(.vertical, BronLayout.spacingS)
    }
}

#Preview {
    TaskSpreadsheetView()
        .environmentObject(AppState(persistenceController: .preview))
}
