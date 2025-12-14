//
//  SkillEntity.swift
//  Bron
//
//  Core Data managed object for Skill
//

import CoreData
import Foundation

@objc(SkillEntity)
public class SkillEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var skillDescription: String?
    @NSManaged public var version: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var steps: Set<SkillStepEntity>?
    @NSManaged public var parameters: Set<SkillParameterEntity>?
}

// MARK: - Convenience

extension SkillEntity {
    /// Convert to value type
    func toSkill() -> Skill {
        let sortedSteps = (steps ?? [])
            .sorted { $0.order < $1.order }
            .map { $0.toSkillStep() }
        
        let params = (parameters ?? []).map { $0.toSkillParameter() }
        
        return Skill(
            id: id,
            name: name,
            description: skillDescription,
            steps: sortedSteps,
            parameters: params,
            version: Int(version),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Update from value type
    func update(from skill: Skill) {
        name = skill.name
        skillDescription = skill.description
        version = Int32(skill.version)
        updatedAt = Date()
    }
}

// MARK: - Fetch Requests

extension SkillEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SkillEntity> {
        NSFetchRequest<SkillEntity>(entityName: "SkillEntity")
    }
    
    static func fetchAll() -> NSFetchRequest<SkillEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillEntity.name, ascending: true)]
        return request
    }
    
    static func fetchById(_ id: UUID) -> NSFetchRequest<SkillEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

// MARK: - SkillStepEntity

@objc(SkillStepEntity)
public class SkillStepEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var order: Int32
    @NSManaged public var instruction: String
    @NSManaged public var requiresUserInput: Bool
    @NSManaged public var inputType: String?
    
    // Relationships
    @NSManaged public var skill: SkillEntity?
}

extension SkillStepEntity {
    func toSkillStep() -> SkillStep {
        SkillStep(
            id: id,
            order: Int(order),
            instruction: instruction,
            requiresUserInput: requiresUserInput,
            inputType: inputType.flatMap { UIComponentType(rawValue: $0) }
        )
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SkillStepEntity> {
        NSFetchRequest<SkillStepEntity>(entityName: "SkillStepEntity")
    }
}

// MARK: - SkillParameterEntity

@objc(SkillParameterEntity)
public class SkillParameterEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var paramType: String
    @NSManaged public var isRequired: Bool
    @NSManaged public var defaultValue: String?
    
    // Relationships
    @NSManaged public var skill: SkillEntity?
}

extension SkillParameterEntity {
    func toSkillParameter() -> SkillParameter {
        SkillParameter(
            id: id,
            name: name,
            type: FieldType(rawValue: paramType) ?? .text,
            required: isRequired,
            defaultValue: defaultValue
        )
    }
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SkillParameterEntity> {
        NSFetchRequest<SkillParameterEntity>(entityName: "SkillParameterEntity")
    }
}

