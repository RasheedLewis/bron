//
//  TaskSpreadsheetView.swift
//  Bron
//
//  Table view of all tasks (Status Spreadsheet)
//

import SwiftUI

struct TaskSpreadsheetView: View {
    @State private var tasks: [Task] = []
    @State private var sortOrder = [KeyPathComparator(\Task.updatedAt, order: .reverse)]
    
    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    emptyState
                } else {
                    taskTable
                }
            }
            .navigationTitle("All Tasks")
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Tasks from your Brons will appear here.")
        }
    }
    
    private var taskTable: some View {
        Table(tasks, sortOrder: $sortOrder) {
            TableColumn("Task", value: \.title)
            TableColumn("Category") { task in
                Text(task.category.rawValue.capitalized)
            }
            TableColumn("Status") { task in
                StatusPill(status: task.state.toBronStatus)
            }
            TableColumn("Updated") { task in
                Text(task.updatedAt, style: .relative)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            tasks.sort(using: newOrder)
        }
    }
}

#Preview {
    TaskSpreadsheetView()
}

