//
//  RecipeValidator.swift
//  Bron
//
//  Schema validation for UI Recipes
//  Ensures recipes are safe and well-formed before rendering
//

import Foundation

/// Validation result for a UI Recipe
struct RecipeValidationResult {
    let isValid: Bool
    let errors: [RecipeValidationError]
    
    static var valid: RecipeValidationResult {
        RecipeValidationResult(isValid: true, errors: [])
    }
    
    static func invalid(_ errors: [RecipeValidationError]) -> RecipeValidationResult {
        RecipeValidationResult(isValid: false, errors: errors)
    }
}

/// Types of validation errors
enum RecipeValidationError: Error, CustomStringConvertible {
    case missingRequiredField(String)
    case invalidFieldType(field: String, expected: FieldType, got: String)
    case unsupportedComponentType(String)
    case schemaEmpty
    case invalidValue(field: String, reason: String)
    
    var description: String {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFieldType(let field, let expected, let got):
            return "Invalid type for '\(field)': expected \(expected.rawValue), got \(got)"
        case .unsupportedComponentType(let type):
            return "Unsupported component type: \(type)"
        case .schemaEmpty:
            return "Recipe schema is empty"
        case .invalidValue(let field, let reason):
            return "Invalid value for '\(field)': \(reason)"
        }
    }
}

/// Validates UI Recipes before rendering
struct RecipeValidator {
    
    // MARK: - Whitelisted Components
    
    /// Components that are allowed to be rendered
    static let allowedComponentTypes: Set<UIComponentType> = [
        // Input
        .form, .picker, .multiSelect, .datePicker, .contactPicker, .fileUpload, .locationPicker,
        // Display
        .infoCard, .weather, .summary, .listView, .progress,
        // Action
        .confirmation, .approval, .authGoogle, .authApple, .authOAuth, .execute,
        // Rich
        .emailPreview, .emailCompose, .calendarEvent, .messagePreview, .documentPreview, .linkPreview
    ]
    
    /// Field types that are allowed
    static let allowedFieldTypes: Set<FieldType> = [
        .text, .number, .date, .datetime, .time, .email, .phone, .url,
        .select, .multiSelect, .boolean,
        .file, .image, .document,
        .location, .contact, .currency,
        .richText, .html, .markdown, .json
    ]
    
    // MARK: - Validation
    
    /// Validate a UI Recipe
    static func validate(_ recipe: UIRecipe) -> RecipeValidationResult {
        var errors: [RecipeValidationError] = []
        
        // Check component type is whitelisted
        if !allowedComponentTypes.contains(recipe.componentType) {
            errors.append(.unsupportedComponentType(recipe.componentType.rawValue))
        }
        
        // For input components, validate schema
        if recipe.componentType.category == .input {
            // Check schema isn't empty (unless it's a simple picker)
            if recipe.schema.isEmpty && recipe.componentType != .datePicker {
                errors.append(.schemaEmpty)
            }
            
            // Validate each field
            for (key, field) in recipe.schema {
                // Check field type is allowed
                if !allowedFieldTypes.contains(field.type) {
                    errors.append(.invalidFieldType(
                        field: key,
                        expected: .text,
                        got: field.type.rawValue
                    ))
                }
                
                // Validate field-specific rules
                if let validation = field.validation {
                    if let minLength = validation.minLength, minLength < 0 {
                        errors.append(.invalidValue(field: key, reason: "minLength cannot be negative"))
                    }
                    if let maxLength = validation.maxLength, maxLength < 0 {
                        errors.append(.invalidValue(field: key, reason: "maxLength cannot be negative"))
                    }
                }
            }
            
            // Check required fields exist in schema
            for requiredField in recipe.requiredFields {
                if recipe.schema[requiredField] == nil {
                    errors.append(.missingRequiredField(requiredField))
                }
            }
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    /// Validate submitted form data against a recipe
    static func validateSubmission(_ data: [String: String], for recipe: UIRecipe) -> RecipeValidationResult {
        var errors: [RecipeValidationError] = []
        
        // Check all required fields are provided
        for requiredField in recipe.requiredFields {
            let value = data[requiredField] ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.missingRequiredField(requiredField))
            }
        }
        
        // Validate field values
        for (key, value) in data {
            if let field = recipe.schema[key] {
                // Type-specific validation
                switch field.type {
                case .email:
                    if !value.isEmpty && !isValidEmail(value) {
                        errors.append(.invalidValue(field: key, reason: "Invalid email format"))
                    }
                case .phone:
                    if !value.isEmpty && !isValidPhone(value) {
                        errors.append(.invalidValue(field: key, reason: "Invalid phone format"))
                    }
                case .url:
                    if !value.isEmpty && URL(string: value) == nil {
                        errors.append(.invalidValue(field: key, reason: "Invalid URL"))
                    }
                case .number, .currency:
                    if !value.isEmpty && Double(value) == nil {
                        errors.append(.invalidValue(field: key, reason: "Must be a number"))
                    }
                default:
                    break
                }
                
                // Length validation
                if let validation = field.validation {
                    if let minLength = validation.minLength, value.count < minLength {
                        errors.append(.invalidValue(field: key, reason: "Minimum \(minLength) characters"))
                    }
                    if let maxLength = validation.maxLength, value.count > maxLength {
                        errors.append(.invalidValue(field: key, reason: "Maximum \(maxLength) characters"))
                    }
                }
            }
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    // MARK: - Helpers
    
    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private static func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.filter { $0.isNumber }
        return digits.count >= 10
    }
}

