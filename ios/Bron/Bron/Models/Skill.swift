//
//  Skill.swift
//  Bron
//
//  Skill model for reusable workflows
//

import Foundation

/// Represents a saved, reusable workflow
struct Skill: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var steps: [SkillStep]
    var parameters: [SkillParameter]
    var version: Int
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        steps: [SkillStep] = [],
        parameters: [SkillParameter] = [],
        version: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.parameters = parameters
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A step within a Skill
struct SkillStep: Identifiable, Codable, Hashable {
    let id: UUID
    var order: Int
    var instruction: String
    var requiresUserInput: Bool
    var inputType: UIComponentType?
    
    init(
        id: UUID = UUID(),
        order: Int,
        instruction: String,
        requiresUserInput: Bool = false,
        inputType: UIComponentType? = nil
    ) {
        self.id = id
        self.order = order
        self.instruction = instruction
        self.requiresUserInput = requiresUserInput
        self.inputType = inputType
    }
}

/// A parameter that can be injected into a Skill
struct SkillParameter: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: FieldType
    var required: Bool
    var defaultValue: String?
    
    init(
        id: UUID = UUID(),
        name: String,
        type: FieldType,
        required: Bool = true,
        defaultValue: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
    }
}

