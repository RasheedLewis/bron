//
//  PersistenceController.swift
//  Bron
//
//  Core Data stack for local persistence
//

import CoreData
import Foundation

/// Core Data persistence controller
final class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // Add sample data for previews
        let context = controller.container.viewContext
        
        // Create a sample Bron
        let bron = BronEntity(context: context)
        bron.id = UUID()
        bron.name = "Receipt Helper"
        bron.status = BronStatus.working.rawValue
        bron.createdAt = Date()
        bron.updatedAt = Date()
        
        // Create a sample Task
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Submit expense receipt"
        task.taskDescription = "Submit the lunch receipt from yesterday"
        task.state = TaskState.needsInfo.rawValue
        task.category = TaskCategory.admin.rawValue
        task.progress = 0.3
        task.nextAction = "Upload receipt photo"
        task.createdAt = Date()
        task.updatedAt = Date()
        task.bron = bron
        
        bron.currentTask = task
        
        do {
            try context.save()
        } catch {
            fatalError("Failed to save preview context: \(error)")
        }
        
        return controller
    }()
    
    /// The persistent container
    let container: NSPersistentContainer
    
    /// Main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Initialize with optional in-memory storage
    init(inMemory: Bool = false) {
        // Create the managed object model programmatically
        let model = Self.createManagedObjectModel()
        
        container = NSPersistentContainer(name: "Bron", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Create a background context
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
    
    /// Save changes in the view context
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    /// Save changes in a background context
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save background context: \(error)")
        }
    }
}

// MARK: - Managed Object Model Creation

extension PersistenceController {
    /// Create the Core Data model programmatically
    static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create entities
        let bronEntity = createBronEntity()
        let taskEntity = createTaskEntity()
        let chatMessageEntity = createChatMessageEntity()
        let uiRecipeEntity = createUIRecipeEntity()
        let skillEntity = createSkillEntity()
        let skillStepEntity = createSkillStepEntity()
        let skillParameterEntity = createSkillParameterEntity()
        
        // Set up relationships
        setupBronTaskRelationships(bronEntity: bronEntity, taskEntity: taskEntity)
        setupBronMessageRelationships(bronEntity: bronEntity, messageEntity: chatMessageEntity)
        setupTaskUIRecipeRelationships(taskEntity: taskEntity, uiRecipeEntity: uiRecipeEntity)
        setupMessageUIRecipeRelationships(messageEntity: chatMessageEntity, uiRecipeEntity: uiRecipeEntity)
        setupSkillRelationships(skillEntity: skillEntity, stepEntity: skillStepEntity, parameterEntity: skillParameterEntity)
        
        model.entities = [
            bronEntity,
            taskEntity,
            chatMessageEntity,
            uiRecipeEntity,
            skillEntity,
            skillStepEntity,
            skillParameterEntity,
        ]
        
        return model
    }
    
    // MARK: Entity Definitions
    
    private static func createBronEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "BronEntity"
        entity.managedObjectClassName = "BronEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "status", type: .stringAttributeType, optional: false, defaultValue: "idle"),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "updatedAt", type: .dateAttributeType, optional: false),
        ]
        
        return entity
    }
    
    private static func createTaskEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TaskEntity"
        entity.managedObjectClassName = "TaskEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "title", type: .stringAttributeType, optional: false),
            createAttribute(name: "taskDescription", type: .stringAttributeType, optional: true),
            createAttribute(name: "state", type: .stringAttributeType, optional: false, defaultValue: "draft"),
            createAttribute(name: "category", type: .stringAttributeType, optional: false, defaultValue: "other"),
            createAttribute(name: "progress", type: .doubleAttributeType, optional: false, defaultValue: 0.0),
            createAttribute(name: "nextAction", type: .stringAttributeType, optional: true),
            createAttribute(name: "waitingOn", type: .stringAttributeType, optional: true),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "updatedAt", type: .dateAttributeType, optional: false),
        ]
        
        return entity
    }
    
    private static func createChatMessageEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "ChatMessageEntity"
        entity.managedObjectClassName = "ChatMessageEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "role", type: .stringAttributeType, optional: false),
            createAttribute(name: "content", type: .stringAttributeType, optional: false),
            createAttribute(name: "taskStateUpdate", type: .stringAttributeType, optional: true),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
        ]
        
        return entity
    }
    
    private static func createUIRecipeEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "UIRecipeEntity"
        entity.managedObjectClassName = "UIRecipeEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "componentType", type: .stringAttributeType, optional: false),
            createAttribute(name: "schemaData", type: .binaryDataAttributeType, optional: true),
            createAttribute(name: "requiredFieldsData", type: .binaryDataAttributeType, optional: true),
            createAttribute(name: "title", type: .stringAttributeType, optional: true),
            createAttribute(name: "recipeDescription", type: .stringAttributeType, optional: true),
            createAttribute(name: "submittedData", type: .binaryDataAttributeType, optional: true),
            createAttribute(name: "isSubmitted", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "updatedAt", type: .dateAttributeType, optional: false),
        ]
        
        return entity
    }
    
    private static func createSkillEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SkillEntity"
        entity.managedObjectClassName = "SkillEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "skillDescription", type: .stringAttributeType, optional: true),
            createAttribute(name: "version", type: .integer32AttributeType, optional: false, defaultValue: 1),
            createAttribute(name: "createdAt", type: .dateAttributeType, optional: false),
            createAttribute(name: "updatedAt", type: .dateAttributeType, optional: false),
        ]
        
        return entity
    }
    
    private static func createSkillStepEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SkillStepEntity"
        entity.managedObjectClassName = "SkillStepEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "order", type: .integer32AttributeType, optional: false),
            createAttribute(name: "instruction", type: .stringAttributeType, optional: false),
            createAttribute(name: "requiresUserInput", type: .booleanAttributeType, optional: false, defaultValue: false),
            createAttribute(name: "inputType", type: .stringAttributeType, optional: true),
        ]
        
        return entity
    }
    
    private static func createSkillParameterEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "SkillParameterEntity"
        entity.managedObjectClassName = "SkillParameterEntity"
        
        entity.properties = [
            createAttribute(name: "id", type: .UUIDAttributeType, optional: false),
            createAttribute(name: "name", type: .stringAttributeType, optional: false),
            createAttribute(name: "paramType", type: .stringAttributeType, optional: false),
            createAttribute(name: "isRequired", type: .booleanAttributeType, optional: false, defaultValue: true),
            createAttribute(name: "defaultValue", type: .stringAttributeType, optional: true),
        ]
        
        return entity
    }
    
    // MARK: Relationship Setup
    
    private static func setupBronTaskRelationships(bronEntity: NSEntityDescription, taskEntity: NSEntityDescription) {
        // Bron -> Tasks (one-to-many)
        let bronToTasks = NSRelationshipDescription()
        bronToTasks.name = "tasks"
        bronToTasks.destinationEntity = taskEntity
        bronToTasks.minCount = 0
        bronToTasks.maxCount = 0 // to-many
        bronToTasks.deleteRule = .cascadeDeleteRule
        
        // Task -> Bron (many-to-one)
        let taskToBron = NSRelationshipDescription()
        taskToBron.name = "bron"
        taskToBron.destinationEntity = bronEntity
        taskToBron.minCount = 1
        taskToBron.maxCount = 1
        taskToBron.deleteRule = .nullifyDeleteRule
        
        bronToTasks.inverseRelationship = taskToBron
        taskToBron.inverseRelationship = bronToTasks
        
        // Bron -> CurrentTask (one-to-one, optional)
        let bronToCurrentTask = NSRelationshipDescription()
        bronToCurrentTask.name = "currentTask"
        bronToCurrentTask.destinationEntity = taskEntity
        bronToCurrentTask.minCount = 0
        bronToCurrentTask.maxCount = 1
        bronToCurrentTask.deleteRule = .nullifyDeleteRule
        
        bronEntity.properties.append(contentsOf: [bronToTasks, bronToCurrentTask])
        taskEntity.properties.append(taskToBron)
    }
    
    private static func setupBronMessageRelationships(bronEntity: NSEntityDescription, messageEntity: NSEntityDescription) {
        // Bron -> Messages (one-to-many)
        let bronToMessages = NSRelationshipDescription()
        bronToMessages.name = "messages"
        bronToMessages.destinationEntity = messageEntity
        bronToMessages.minCount = 0
        bronToMessages.maxCount = 0
        bronToMessages.deleteRule = .cascadeDeleteRule
        
        // Message -> Bron (many-to-one)
        let messageToBron = NSRelationshipDescription()
        messageToBron.name = "bron"
        messageToBron.destinationEntity = bronEntity
        messageToBron.minCount = 1
        messageToBron.maxCount = 1
        messageToBron.deleteRule = .nullifyDeleteRule
        
        bronToMessages.inverseRelationship = messageToBron
        messageToBron.inverseRelationship = bronToMessages
        
        bronEntity.properties.append(bronToMessages)
        messageEntity.properties.append(messageToBron)
    }
    
    private static func setupTaskUIRecipeRelationships(taskEntity: NSEntityDescription, uiRecipeEntity: NSEntityDescription) {
        // Task -> UIRecipes (one-to-many)
        let taskToRecipes = NSRelationshipDescription()
        taskToRecipes.name = "uiRecipes"
        taskToRecipes.destinationEntity = uiRecipeEntity
        taskToRecipes.minCount = 0
        taskToRecipes.maxCount = 0
        taskToRecipes.deleteRule = .cascadeDeleteRule
        
        // UIRecipe -> Task (many-to-one, optional)
        let recipeToTask = NSRelationshipDescription()
        recipeToTask.name = "task"
        recipeToTask.destinationEntity = taskEntity
        recipeToTask.minCount = 0
        recipeToTask.maxCount = 1
        recipeToTask.deleteRule = .nullifyDeleteRule
        
        taskToRecipes.inverseRelationship = recipeToTask
        recipeToTask.inverseRelationship = taskToRecipes
        
        taskEntity.properties.append(taskToRecipes)
        uiRecipeEntity.properties.append(recipeToTask)
    }
    
    private static func setupMessageUIRecipeRelationships(messageEntity: NSEntityDescription, uiRecipeEntity: NSEntityDescription) {
        // Message -> UIRecipe (one-to-one, optional)
        let messageToRecipe = NSRelationshipDescription()
        messageToRecipe.name = "uiRecipe"
        messageToRecipe.destinationEntity = uiRecipeEntity
        messageToRecipe.minCount = 0
        messageToRecipe.maxCount = 1
        messageToRecipe.deleteRule = .cascadeDeleteRule
        
        // UIRecipe -> Message (one-to-one, optional)
        let recipeToMessage = NSRelationshipDescription()
        recipeToMessage.name = "message"
        recipeToMessage.destinationEntity = messageEntity
        recipeToMessage.minCount = 0
        recipeToMessage.maxCount = 1
        recipeToMessage.deleteRule = .nullifyDeleteRule
        
        messageToRecipe.inverseRelationship = recipeToMessage
        recipeToMessage.inverseRelationship = messageToRecipe
        
        messageEntity.properties.append(messageToRecipe)
        uiRecipeEntity.properties.append(recipeToMessage)
    }
    
    private static func setupSkillRelationships(skillEntity: NSEntityDescription, stepEntity: NSEntityDescription, parameterEntity: NSEntityDescription) {
        // Skill -> Steps (one-to-many)
        let skillToSteps = NSRelationshipDescription()
        skillToSteps.name = "steps"
        skillToSteps.destinationEntity = stepEntity
        skillToSteps.minCount = 0
        skillToSteps.maxCount = 0
        skillToSteps.deleteRule = .cascadeDeleteRule
        
        let stepToSkill = NSRelationshipDescription()
        stepToSkill.name = "skill"
        stepToSkill.destinationEntity = skillEntity
        stepToSkill.minCount = 1
        stepToSkill.maxCount = 1
        stepToSkill.deleteRule = .nullifyDeleteRule
        
        skillToSteps.inverseRelationship = stepToSkill
        stepToSkill.inverseRelationship = skillToSteps
        
        // Skill -> Parameters (one-to-many)
        let skillToParams = NSRelationshipDescription()
        skillToParams.name = "parameters"
        skillToParams.destinationEntity = parameterEntity
        skillToParams.minCount = 0
        skillToParams.maxCount = 0
        skillToParams.deleteRule = .cascadeDeleteRule
        
        let paramToSkill = NSRelationshipDescription()
        paramToSkill.name = "skill"
        paramToSkill.destinationEntity = skillEntity
        paramToSkill.minCount = 1
        paramToSkill.maxCount = 1
        paramToSkill.deleteRule = .nullifyDeleteRule
        
        skillToParams.inverseRelationship = paramToSkill
        paramToSkill.inverseRelationship = skillToParams
        
        skillEntity.properties.append(contentsOf: [skillToSteps, skillToParams])
        stepEntity.properties.append(stepToSkill)
        parameterEntity.properties.append(paramToSkill)
    }
    
    // MARK: Helper
    
    private static func createAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        if let defaultValue = defaultValue {
            attribute.defaultValue = defaultValue
        }
        return attribute
    }
}

