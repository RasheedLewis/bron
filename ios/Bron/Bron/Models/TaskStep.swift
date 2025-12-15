//
//  TaskStep.swift
//  Bron
//
//  Represents a step in a Bron's task plan
//

import Foundation

/// A single step in a task's execution plan
struct TaskStep: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var status: TaskStepStatus
    var order: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        status: TaskStepStatus = .pending,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.order = order
    }
}

/// Status of a task step
enum TaskStepStatus: String, Codable, CaseIterable {
    case pending     // Not started
    case inProgress  // Currently working on
    case completed   // Done
    case skipped     // Skipped by user or agent
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Done"
        case .skipped: return "Skipped"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }
}

// MARK: - Preview Helpers

extension TaskStep {
    static var previewPlan: [TaskStep] {
        [
            TaskStep(title: "Gather trip details", status: .completed, order: 0),
            TaskStep(title: "Research flights", status: .inProgress, order: 1),
            TaskStep(title: "Find hotels", status: .pending, order: 2),
            TaskStep(title: "Create itinerary", status: .pending, order: 3),
            TaskStep(title: "Send summary", status: .pending, order: 4),
        ]
    }
}

