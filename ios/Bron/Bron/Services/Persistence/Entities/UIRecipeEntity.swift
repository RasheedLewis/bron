//
//  UIRecipeEntity.swift
//  Bron
//
//  Core Data managed object for UIRecipe
//

import CoreData
import Foundation

@objc(UIRecipeEntity)
public class UIRecipeEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var componentType: String
    @NSManaged public var schemaData: Data?
    @NSManaged public var requiredFieldsData: Data?
    @NSManaged public var title: String?
    @NSManaged public var recipeDescription: String?
    @NSManaged public var submittedData: Data?
    @NSManaged public var isSubmitted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var task: TaskEntity?
    @NSManaged public var message: ChatMessageEntity?
}

// MARK: - Convenience

extension UIRecipeEntity {
    /// Convert to value type
    func toUIRecipe() -> UIRecipe {
        UIRecipe(
            id: id,
            componentType: UIComponentType(rawValue: componentType) ?? .form,
            schema: decodeSchema() ?? [:],
            requiredFields: decodeRequiredFields() ?? [],
            title: title,
            description: recipeDescription,
            isSubmitted: isSubmitted,
            submittedData: decodeSubmittedData()
        )
    }
    
    /// Update from value type
    func update(from recipe: UIRecipe) {
        componentType = recipe.componentType.rawValue
        title = recipe.title
        recipeDescription = recipe.description
        encodeSchema(recipe.schema)
        encodeRequiredFields(recipe.requiredFields)
        isSubmitted = recipe.isSubmitted
        if let data = recipe.submittedData {
            encodeSubmittedData(data)
        }
        updatedAt = Date()
    }
    
    // MARK: JSON Encoding/Decoding
    
    private func decodeSchema() -> [String: SchemaField]? {
        guard let data = schemaData else { return nil }
        return try? JSONDecoder().decode([String: SchemaField].self, from: data)
    }
    
    private func encodeSchema(_ schema: [String: SchemaField]) {
        schemaData = try? JSONEncoder().encode(schema)
    }
    
    private func decodeRequiredFields() -> [String]? {
        guard let data = requiredFieldsData else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    private func encodeRequiredFields(_ fields: [String]) {
        requiredFieldsData = try? JSONEncoder().encode(fields)
    }
    
    private func decodeSubmittedData() -> [String: String]? {
        guard let data = submittedData else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
    
    private func encodeSubmittedData(_ data: [String: String]) {
        submittedData = try? JSONEncoder().encode(data)
    }
}

// MARK: - Fetch Requests

extension UIRecipeEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UIRecipeEntity> {
        NSFetchRequest<UIRecipeEntity>(entityName: "UIRecipeEntity")
    }
    
    static func fetchById(_ id: UUID) -> NSFetchRequest<UIRecipeEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
    
    static func fetchPendingByTask(_ taskId: UUID) -> NSFetchRequest<UIRecipeEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "task.id == %@ AND isSubmitted == NO", taskId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UIRecipeEntity.createdAt, ascending: false)]
        return request
    }
}

