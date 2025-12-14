//
//  UIRecipeView.swift
//  Bron
//
//  UI Recipe renderer - broadcast style
//  Flat, tool-like, minimal copy, strong alignment
//

import SwiftUI

struct UIRecipeView: View {
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
            }
            
            // Description
            if let description = recipe.description {
                Text(description)
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .padding(.top, BronLayout.spacingM)
            }
            
            // Component content
            componentContent
                .padding(.vertical, BronLayout.spacingM)
            
            // Actions
            actionButtons
        }
        .padding(BronLayout.spacingM)
        .background(BronColors.surface)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    // MARK: - Component Content
    
    @ViewBuilder
    private var componentContent: some View {
        switch recipe.componentType.category {
        case .input:
            inputComponent
        case .display:
            displayComponent
        case .action:
            actionComponent
        case .rich:
            richComponent
        }
    }
    
    // MARK: - Input Components
    
    @ViewBuilder
    private var inputComponent: some View {
        VStack(spacing: BronLayout.spacingM) {
            ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
                if let field = recipe.schema[key] {
                    inputField(key: key, field: field)
                }
            }
        }
    }
    
    private func inputField(key: String, field: SchemaField) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
            HStack(spacing: BronLayout.spacingXS) {
                Text((field.label ?? key).uppercased())
                    .font(BronTypography.meta)
                    .tracking(1)
                    .foregroundStyle(BronColors.textSecondary)
                
                if recipe.requiredFields.contains(key) {
                    Text("*")
                        .foregroundStyle(BronColors.commit)
                }
            }
            
            TextField(field.placeholder ?? "", text: Binding(
                get: { formData[key] ?? "" },
                set: { formData[key] = $0 }
            ))
            .font(BronTypography.bodyM)
            .padding(BronLayout.spacingM)
            .background(BronColors.gray050)
            .overlay(
                Rectangle()
                    .strokeBorder(BronColors.gray300, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Display Components
    
    @ViewBuilder
    private var displayComponent: some View {
        switch recipe.componentType {
        case .infoCard, .summary:
            infoCardView
        case .weather:
            weatherView
        case .progress:
            progressView
        default:
            Text("Display component")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private var infoCardView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
                if let field = recipe.schema[key] {
                    HStack {
                        Text((field.label ?? key).uppercased())
                            .font(BronTypography.meta)
                            .foregroundStyle(BronColors.textMeta)
                        Spacer()
                        Text(field.placeholder ?? "—")
                            .utilityStyle(.medium)
                            .foregroundStyle(BronColors.textPrimary)
                    }
                }
            }
        }
    }
    
    private var weatherView: some View {
        HStack(spacing: BronLayout.spacingL) {
            Image(systemName: "sun.max")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BronColors.textSecondary)
            
            VStack(alignment: .leading) {
                Text("72°F")
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
                Text("Sunny")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
    }
    
    private var progressView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack {
                Text("PROGRESS")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
                Spacer()
                Text("75%")
                    .displayStyle(.small)
                    .foregroundStyle(BronColors.textPrimary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(BronColors.gray150)
                    Rectangle()
                        .fill(BronColors.black)
                        .frame(width: geo.size.width * 0.75)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Action Components
    
    @ViewBuilder
    private var actionComponent: some View {
        switch recipe.componentType {
        case .confirmation:
            confirmationView
        case .approval:
            approvalView
        case .authGoogle, .authApple, .authOAuth:
            authView
        default:
            EmptyView()
        }
    }
    
    private var confirmationView: some View {
        Text("Confirm to proceed.")
            .utilityStyle(.medium)
            .foregroundStyle(BronColors.textSecondary)
    }
    
    private var approvalView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack(spacing: BronLayout.spacingS) {
                CommitRule(orientation: .vertical, length: 40)
                Text("This needs your approval before I proceed.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
            }
        }
    }
    
    private var authView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Text("I need access to continue.")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textSecondary)
        }
    }
    
    // MARK: - Rich Components
    
    @ViewBuilder
    private var richComponent: some View {
        switch recipe.componentType {
        case .emailPreview:
            emailPreviewView
        case .calendarEvent:
            calendarEventView
        default:
            Text("Content preview")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private var emailPreviewView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Text("TO: recipient@example.com")
                .font(BronTypography.meta)
                .foregroundStyle(BronColors.textMeta)
            Text("SUBJECT: Your Subject")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textPrimary)
            BronDivider()
            Text("Email body content...")
                .utilityStyle(.small)
                .foregroundStyle(BronColors.textSecondary)
        }
    }
    
    private var calendarEventView: some View {
        HStack(spacing: BronLayout.spacingM) {
            VStack {
                Text("DEC")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
                Text("15")
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
            }
            .frame(width: 60)
            .padding()
            .background(BronColors.gray050)
            
            VStack(alignment: .leading) {
                Text("EVENT TITLE")
                    .displayStyle(.small)
                    .foregroundStyle(BronColors.textPrimary)
                Text("10:00 AM - 11:00 AM")
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textMeta)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        if recipe.componentType.requiresUserInteraction {
            HStack(spacing: BronLayout.spacingM) {
                if showSkipButton {
                    Button("SKIP FOR NOW") {
                        onAction?("skip")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button(primaryButtonText) {
                    if recipe.componentType.category == .input {
                        onSubmit?(formData)
                    } else {
                        onAction?(primaryActionName)
                    }
                }
                .buttonStyle(CommitButtonStyle(isEnabled: isFormValid))
                .disabled(!isFormValid)
            }
        }
    }
    
    private var showSkipButton: Bool {
        recipe.componentType == .form || recipe.componentType == .picker
    }
    
    private var primaryButtonText: String {
        switch recipe.componentType {
        case .confirmation: return "CONFIRM"
        case .approval: return "APPROVE"
        case .authGoogle: return "SIGN IN WITH GOOGLE"
        case .authApple: return "SIGN IN WITH APPLE"
        case .authOAuth: return "SIGN IN"
        case .execute: return "EXECUTE"
        default: return "CONTINUE"
        }
    }
    
    private var primaryActionName: String {
        switch recipe.componentType {
        case .confirmation: return "confirm"
        case .approval: return "approve"
        case .authGoogle, .authApple, .authOAuth: return "auth"
        case .execute: return "execute"
        default: return "continue"
        }
    }
    
    private var isFormValid: Bool {
        if recipe.componentType.category != .input {
            return true
        }
        return recipe.requiredFields.allSatisfy { field in
            let value = formData[field] ?? ""
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

// MARK: - Previews

#Preview("Form") {
    UIRecipeView(recipe: .preview)
        .padding()
}

#Preview("Confirmation") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .confirmation,
        title: "Confirm",
        description: "This will send the email. Ready?"
    ))
    .padding()
}

#Preview("Approval") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .approval,
        title: "Approval Needed",
        description: "This will send an email to 5 recipients."
    ))
    .padding()
}
