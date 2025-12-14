//
//  MessageBubble.swift
//  Bron
//
//  Chat message - editorial style, feels like notes between teammates
//  No bubbles with personality. Clean, calm, neutral.
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var onRecipeAction: ((String) -> Void)?
    var onRecipeSubmit: (([String: String]) -> Void)?
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: BronLayout.spacingM) {
            // Avatar (left-aligned, only colored element)
            if !isUser {
                BronAvatar(
                    size: .small,
                    state: AvatarState.from(taskState: message.taskStateUpdate),
                    isAnimated: false
                )
            } else {
                // Spacer for user messages (right-aligned)
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: BronLayout.spacingS) {
                // Task state update (if any)
                if let stateUpdate = message.taskStateUpdate {
                    BronStatusBadge(status: stateUpdate)
                }
                
                // Message content
                messageContent
                
                // UI Recipe (if any)
                if let recipe = message.uiRecipe {
                    UIRecipeCard(
                        recipe: recipe,
                        onAction: onRecipeAction,
                        onSubmit: onRecipeSubmit
                    )
                }
                
                // Timestamp
                Text(message.createdAt, style: .time)
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            
            // User avatar or spacer
            if isUser {
                UserAvatar(size: .small)
            } else {
                Spacer(minLength: 60)
            }
        }
    }
    
    // MARK: - Message Content
    
    private var messageContent: some View {
        Text(message.content)
            .utilityStyle(.large)
            .foregroundStyle(BronColors.textPrimary)
            .padding(BronLayout.spacingM)
            .background(
                Rectangle()
                    .fill(isUser ? BronColors.gray050 : BronColors.surface)
            )
            .overlay(
                Rectangle()
                    .strokeBorder(BronColors.gray150, lineWidth: 1)
            )
    }
}

// MARK: - UI Recipe Card (Broadcast Style)

struct UIRecipeCard: View {
    let recipe: UIRecipe
    var onAction: ((String) -> Void)?
    var onSubmit: (([String: String]) -> Void)?
    
    @State private var formData: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if let title = recipe.title {
                VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                    Text(title.uppercased())
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                    
                    BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                }
                .padding(BronLayout.spacingM)
            }
            
            // Description
            if let description = recipe.description {
                Text(description)
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .padding(.horizontal, BronLayout.spacingM)
                    .padding(.bottom, BronLayout.spacingM)
            }
            
            // Form fields
            VStack(spacing: BronLayout.spacingM) {
                ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
                    if let field = recipe.schema[key] {
                        RecipeFormField(
                            key: key,
                            field: field,
                            isRequired: recipe.requiredFields.contains(key),
                            value: Binding(
                                get: { formData[key] ?? "" },
                                set: { formData[key] = $0 }
                            )
                        )
                    }
                }
            }
            .padding(.horizontal, BronLayout.spacingM)
            
            // Actions
            HStack(spacing: BronLayout.spacingM) {
                if recipe.componentType == .confirmation || recipe.componentType == .approval {
                    Button("SKIP FOR NOW") {
                        onAction?("skip")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button("CONTINUE") {
                        onSubmit?(formData)
                    }
                    .buttonStyle(CommitButtonStyle(isEnabled: isFormValid))
                    .disabled(!isFormValid)
                } else {
                    Button("SUBMIT") {
                        onSubmit?(formData)
                    }
                    .buttonStyle(CommitButtonStyle(isEnabled: isFormValid))
                    .disabled(!isFormValid)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(BronLayout.spacingM)
        }
        .background(BronColors.surface)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    private var isFormValid: Bool {
        recipe.requiredFields.allSatisfy { field in
            let value = formData[field] ?? ""
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Recipe Form Field

struct RecipeFormField: View {
    let key: String
    let field: SchemaField
    let isRequired: Bool
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
            // Label
            HStack(spacing: BronLayout.spacingXS) {
                Text((field.label ?? key).uppercased())
                    .font(BronTypography.meta)
                    .tracking(1)
                    .foregroundStyle(BronColors.textSecondary)
                
                if isRequired {
                    Text("*")
                        .foregroundStyle(BronColors.commit)
                }
            }
            
            // Input
            TextField(field.placeholder ?? "", text: $value)
                .font(BronTypography.bodyM)
                .padding(BronLayout.spacingM)
                .background(BronColors.gray050)
                .overlay(
                    Rectangle()
                        .strokeBorder(BronColors.gray300, lineWidth: 1)
                )
        }
    }
}

// MARK: - Previews

#Preview("User Message") {
    MessageBubble(message: ChatMessage(
        bronId: UUID(),
        role: .user,
        content: "Submit my expense receipt from lunch",
        createdAt: Date()
    ))
    .padding()
    .background(BronColors.surface)
}

#Preview("Assistant Message") {
    MessageBubble(message: ChatMessage(
        bronId: UUID(),
        role: .assistant,
        content: "I need the receipt photo and purchase details to continue.",
        taskStateUpdate: "needs_info",
        createdAt: Date()
    ))
    .padding()
    .background(BronColors.surface)
}

#Preview("With UI Recipe") {
    MessageBubble(message: ChatMessage(
        bronId: UUID(),
        role: .assistant,
        content: "I need the receipt details:",
        uiRecipe: .preview,
        createdAt: Date()
    ))
    .padding()
    .background(BronColors.surface)
}
