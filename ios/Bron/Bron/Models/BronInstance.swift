//
//  BronInstance.swift
//  Bron
//
//  Bron agent model
//

import Foundation

/// Represents a Bron agent instance
struct BronInstance: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var status: BronStatus
    var currentTaskId: UUID?
    var currentTask: Task?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        status: BronStatus = .idle,
        currentTaskId: UUID? = nil,
        currentTask: Task? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.currentTaskId = currentTaskId
        self.currentTask = currentTask
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Bron status states
enum BronStatus: String, Codable, CaseIterable {
    case idle
    case working
    case waiting
    case needsInfo
    case ready
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waiting: return "Waiting"
        case .needsInfo: return "Needs Info"
        case .ready: return "Ready"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .idle: return .gray
        case .working: return .blue
        case .waiting: return .orange
        case .needsInfo: return .purple
        case .ready: return .green
        }
    }
}

// MARK: - Preview Helpers

extension BronInstance {
    static var preview: BronInstance {
        BronInstance(
            name: "Receipt Helper",
            status: .working,
            currentTask: .preview
        )
    }
}

