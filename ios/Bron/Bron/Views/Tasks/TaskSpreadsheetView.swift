//
//  TaskSpreadsheetView.swift
//  Bron
//
//  Table view of all tasks (Status Spreadsheet)
//

import SwiftUI

struct TaskSpreadsheetView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortOrder = [KeyPathComparator(\Task.updatedAt, order: .reverse)]
    
    private var tasks: [Task] {
        appState.taskRepository.tasks.sorted(using: sortOrder)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .navigationTitle("All Tasks")
            .refreshable {
                appState.taskRepository.fetchAll()
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Tasks from your Brons will appear here.")
        }
    }
    
    // Use List for iOS (Table is iPad-only)
    private var taskList: some View {
        List(tasks) { task in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                    Spacer()
                    StatusPill(status: task.state.toBronStatus)
                }
                
                HStack {
                    Text(task.category.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(task.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    TaskSpreadsheetView()
        .environmentObject(AppState(persistenceController: .preview))
}

