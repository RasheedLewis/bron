//
//  TaskDrawer.swift
//  Bron
//
//  Collapsible drawer showing current task details
//

import SwiftUI

struct TaskDrawer: View {
    let bronId: UUID
    
    @State private var currentTask: Task?
    
    var body: some View {
        NavigationStack {
            Group {
                if let task = currentTask {
                    taskContent(task)
                } else {
                    ContentUnavailableView(
                        "No Active Task",
                        systemImage: "checkmark.circle",
                        description: Text("This Bron doesn't have an active task.")
                    )
                }
            }
            .navigationTitle("Current Task")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private func taskContent(_ task: Task) -> some View {
        List {
            Section("Details") {
                LabeledContent("Title", value: task.title)
                LabeledContent("Status", value: task.state.displayName)
                LabeledContent("Category", value: task.category.rawValue.capitalized)
            }
            
            if let nextAction = task.nextAction {
                Section("Next Action") {
                    Text(nextAction)
                }
            }
            
            if task.state == .ready {
                Section {
                    Button("Execute Task") {
                        // Execute task
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    TaskDrawer(bronId: UUID())
}

