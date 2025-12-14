//
//  BronTask.swift
//  Bron
//
//  Task model (named BronTask to avoid collision with Swift's Task)
//

import Foundation

/// Represents a task being worked on by a Bron
struct BronTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String?
    var state: TaskState
    var category: TaskCategory
    var bronId: UUID
    var progress: Double
    var nextAction: String?
    var waitingOn: String?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        state: TaskState = .draft,
        category: TaskCategory = .other,
        bronId: UUID,
        progress: Double = 0,
        nextAction: String? = nil,
        waitingOn: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.state = state
        self.category = category
        self.bronId = bronId
        self.progress = progress
        self.nextAction = nextAction
        self.waitingOn = waitingOn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Task state enumeration
enum TaskState: String, Codable, CaseIterable {
    case draft
    case needsInfo
    case planned
    case ready
    case executing
    case waiting
    case done
    case failed
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .needsInfo: return "Needs Info"
        case .planned: return "Planned"
        case .ready: return "Ready"
        case .executing: return "Executing"
        case .waiting: return "Waiting"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }
    
    var toBronStatus: BronStatus {
        switch self {
        case .draft, .planned: return .idle
        case .needsInfo: return .needsInfo
        case .ready: return .ready
        case .executing: return .working
        case .waiting, .done, .failed: return .waiting
        }
    }
}

/// Task category enumeration
enum TaskCategory: String, Codable, CaseIterable {
    case admin
    case creative
    case school
    case personal
    case work
    case other
}

// MARK: - Preview Helpers

extension BronTask {
    static var preview: BronTask {
        BronTask(
            title: "Submit expense receipt",
            description: "Submit the lunch receipt from yesterday",
            state: .needsInfo,
            category: .admin,
            bronId: UUID(),
            progress: 0.3,
            nextAction: "Upload receipt photo"
        )
    }
}

