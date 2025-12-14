//
//  BronInstance.swift
//  Bron
//
//  Bron agent model
//

import Foundation
import SwiftUI

/// Represents a Bron agent instance
struct BronInstance: Identifiable, Hashable {
    let id: UUID
    var name: String
    var status: BronStatus
    var currentTaskId: UUID?
    let createdAt: Date
    var updatedAt: Date
    
    // Not decoded from API - set locally if needed
    var currentTask: BronTask?
    
    init(
        id: UUID = UUID(),
        name: String,
        status: BronStatus = .idle,
        currentTaskId: UUID? = nil,
        currentTask: BronTask? = nil,
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

// MARK: - Codable (explicit to handle currentTask exclusion)

extension BronInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, status, currentTaskId, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(BronStatus.self, forKey: .status)
        currentTaskId = try container.decodeIfPresent(UUID.self, forKey: .currentTaskId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        currentTask = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(currentTaskId, forKey: .currentTaskId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Bron status states
enum BronStatus: String, Codable, CaseIterable {
    case idle = "idle"
    case working = "working"
    case waiting = "waiting"
    case needsInfo = "needs_info"
    case ready = "ready"
    
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
