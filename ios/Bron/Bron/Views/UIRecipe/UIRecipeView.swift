//
//  UIRecipeView.swift
//  Bron
//
//  UI Recipe renderer - broadcast style
//  Flat, tool-like, minimal copy, strong alignment
//  Performance optimized with lazy loading
//

import SwiftUI

/// Actions that can be dispatched from a UI Recipe
enum RecipeAction: String {
    case submit = "submit"       // Provide info
    case confirm = "confirm"     // Confirm action
    case approve = "approve"     // Approve execution
    case auth = "auth"           // Authenticate
    case execute = "execute"     // Execute action
    case skip = "skip"           // Skip for now (defer)
    case cancel = "cancel"       // Cancel/dismiss
}

struct UIRecipeView: View {
    let recipe: UIRecipe
    var onAction: ((RecipeAction, [String: String]?) -> Void)?
    
    @State private var formData: [String: String] = [:]
    @State private var validationErrors: [String: String] = [:]
    @State private var isSubmitting = false
    
    // Whether this recipe has been submitted (read-only mode)
    private var isReadOnly: Bool {
        recipe.isSubmitted
    }
    
    // Validation on init
    private var validationResult: RecipeValidationResult {
        RecipeValidator.validate(recipe)
    }
    
    var body: some View {
        Group {
            if validationResult.isValid {
                validRecipeView
            } else {
                invalidRecipeView
            }
        }
        .onAppear {
            // Pre-populate form with submitted data if available
            if let submitted = recipe.submittedData {
                formData = submitted
            }
        }
    }
    
    // MARK: - Valid Recipe View
    
    private var validRecipeView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if let title = recipe.title {
                headerView(title: title)
            }
            
            // Description
            if let description = recipe.description {
                Text(description)
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .padding(.top, BronLayout.spacingM)
                    .padding(.horizontal, BronLayout.spacingM)
            }
            
            // Component content (lazy loaded)
            componentContent
                .padding(.vertical, BronLayout.spacingM)
                .padding(.horizontal, BronLayout.spacingM)
            
            // Actions
            actionButtons
                .padding(BronLayout.spacingM)
        }
        .background(BronColors.surface)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    private func headerView(title: String) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
            Text(title.uppercased())
                .displayStyle(.small)
                .foregroundStyle(BronColors.textPrimary)
            
            BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
        }
        .padding(BronLayout.spacingM)
    }
    
    // MARK: - Invalid Recipe View
    
    private var invalidRecipeView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack(spacing: BronLayout.spacingS) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(BronColors.commit)
                Text("INVALID RECIPE")
                    .displayStyle(.small)
                    .foregroundStyle(BronColors.textPrimary)
            }
            
            ForEach(validationResult.errors.indices, id: \.self) { index in
                Text("• \(validationResult.errors[index].description)")
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
        .padding(BronLayout.spacingM)
        .background(BronColors.gray050)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.commit, lineWidth: 1)
        )
    }
    
    // MARK: - Component Content (Lazy)
    
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
        LazyVStack(spacing: BronLayout.spacingM) {
            switch recipe.componentType {
            case .form:
                formFields
            case .picker:
                pickerField
            case .multiSelect:
                multiSelectField
            case .datePicker:
                datePickerField
            case .contactPicker:
                contactPickerField
            case .fileUpload:
                fileUploadField
            case .locationPicker:
                locationPickerField
            default:
                formFields
            }
        }
    }
    
    private var formFields: some View {
        ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
            if let field = recipe.schema[key] {
                inputField(key: key, field: field)
            }
        }
    }
    
    private func inputField(key: String, field: SchemaField) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
            // Label
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
            
            // Input based on field type
            inputForFieldType(key: key, field: field)
            
            // Validation error
            if let error = validationErrors[key] {
                Text(error)
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.commit)
            }
        }
    }
    
    @ViewBuilder
    private func inputForFieldType(key: String, field: SchemaField) -> some View {
        switch field.type {
        case .select:
            selectInput(key: key, field: field)
        case .boolean:
            booleanInput(key: key, field: field)
        case .date, .datetime, .time:
            dateInput(key: key, field: field)
        case .number, .currency:
            numberInput(key: key, field: field)
        default:
            textInput(key: key, field: field)
        }
    }
    
    private func textInput(key: String, field: SchemaField) -> some View {
        Group {
            if isReadOnly {
                // Read-only display of submitted value
                Text(formData[key]?.isEmpty == false ? formData[key]! : "—")
                    .font(BronTypography.bodyM)
                    .foregroundStyle(BronColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BronLayout.spacingM)
                    .background(BronColors.gray050)
                    .overlay(
                        Rectangle()
                            .strokeBorder(BronColors.gray150, lineWidth: 1)
                    )
            } else {
                TextField(field.placeholder ?? "", text: binding(for: key))
                    .font(BronTypography.bodyM)
                    .padding(BronLayout.spacingM)
                    .background(BronColors.gray050)
                    .overlay(
                        Rectangle()
                            .strokeBorder(
                                validationErrors[key] != nil ? BronColors.commit : BronColors.gray300,
                                lineWidth: 1
                            )
                    )
                    .keyboardType(keyboardType(for: field.type))
                    .textContentType(contentType(for: field.type))
            }
        }
    }
    
    private func numberInput(key: String, field: SchemaField) -> some View {
        TextField(field.placeholder ?? "0", text: binding(for: key))
            .font(BronTypography.bodyM)
            .padding(BronLayout.spacingM)
            .background(BronColors.gray050)
            .overlay(
                Rectangle()
                    .strokeBorder(BronColors.gray300, lineWidth: 1)
            )
            .keyboardType(.decimalPad)
    }
    
    private func selectInput(key: String, field: SchemaField) -> some View {
        Group {
            if isReadOnly {
                // Read-only display of submitted selection
                HStack {
                    Text(formData[key] ?? "—")
                        .foregroundStyle(BronColors.textPrimary)
                    Spacer()
                }
                .font(BronTypography.bodyM)
                .padding(BronLayout.spacingM)
                .background(BronColors.gray050)
                .overlay(
                    Rectangle()
                        .strokeBorder(BronColors.gray150, lineWidth: 1)
                )
            } else {
                Menu {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Button(option) {
                            formData[key] = option
                        }
                    }
                } label: {
                    HStack {
                        Text(formData[key] ?? field.placeholder ?? "Select...")
                            .foregroundStyle(formData[key] != nil ? BronColors.textPrimary : BronColors.textMeta)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundStyle(BronColors.textMeta)
                    }
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
    }
    
    private func booleanInput(key: String, field: SchemaField) -> some View {
        Toggle(isOn: Binding(
            get: { formData[key] == "true" },
            set: { formData[key] = $0 ? "true" : "false" }
        )) {
            Text(field.label ?? key)
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: BronColors.black))
    }
    
    private func dateInput(key: String, field: SchemaField) -> some View {
        DatePicker(
            "",
            selection: Binding(
                get: {
                    if let dateStr = formData[key], let date = ISO8601DateFormatter().date(from: dateStr) {
                        return date
                    }
                    return Date()
                },
                set: { formData[key] = ISO8601DateFormatter().string(from: $0) }
            ),
            displayedComponents: dateComponents(for: field.type)
        )
        .labelsHidden()
        .datePickerStyle(.compact)
    }
    
    private var pickerField: some View {
        let options = recipe.schema.values.first?.options ?? []
        return VStack(spacing: BronLayout.spacingS) {
            ForEach(options, id: \.self) { option in
                pickerOptionButton(option: option)
            }
        }
    }
    
    private func pickerOptionButton(option: String) -> some View {
        let isSelected = formData["selection"] == option
        
        if isReadOnly {
            // Read-only: only show selected option
            return AnyView(
                Group {
                    if isSelected {
                        HStack {
                            Text(option)
                                .utilityStyle(.medium)
                                .foregroundStyle(BronColors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(BronColors.black)
                        }
                        .padding(BronLayout.spacingM)
                        .background(BronColors.gray150)
                        .overlay(
                            Rectangle()
                                .strokeBorder(BronColors.gray150, lineWidth: 1)
                        )
                    }
                }
            )
        } else {
            return AnyView(
                Button {
                    formData["selection"] = option
                } label: {
                    HStack {
                        Text(option)
                            .utilityStyle(.medium)
                            .foregroundStyle(BronColors.textPrimary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(BronColors.black)
                        }
                    }
                    .padding(BronLayout.spacingM)
                    .background(isSelected ? BronColors.gray150 : BronColors.gray050)
                    .overlay(
                        Rectangle()
                            .strokeBorder(BronColors.gray300, lineWidth: 1)
                    )
                }
            )
        }
    }
    
    private var multiSelectField: some View {
        let options = recipe.schema.values.first?.options ?? []
        return VStack(spacing: BronLayout.spacingS) {
            ForEach(options, id: \.self) { option in
                multiSelectOptionButton(option: option)
            }
        }
    }
    
    private func multiSelectOptionButton(option: String) -> some View {
        let selected = isSelected(option)
        
        if isReadOnly {
            // Read-only: only show selected options
            return AnyView(
                Group {
                    if selected {
                        HStack {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundStyle(BronColors.black)
                            Text(option)
                                .utilityStyle(.medium)
                                .foregroundStyle(BronColors.textPrimary)
                            Spacer()
                        }
                        .padding(BronLayout.spacingM)
                        .background(BronColors.gray050)
                        .overlay(
                            Rectangle()
                                .strokeBorder(BronColors.gray150, lineWidth: 1)
                        )
                    }
                }
            )
        } else {
            return AnyView(
                Button {
                    toggleMultiSelect(option)
                } label: {
                    HStack {
                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(BronColors.black)
                        Text(option)
                            .utilityStyle(.medium)
                            .foregroundStyle(BronColors.textPrimary)
                        Spacer()
                    }
                    .padding(BronLayout.spacingM)
                    .background(BronColors.gray050)
                }
            )
        }
    }
    
    private var datePickerField: some View {
        DatePicker(
            "",
            selection: Binding(
                get: { Date() },
                set: { formData["date"] = ISO8601DateFormatter().string(from: $0) }
            )
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }
    
    private var contactPickerField: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Text("Select a contact")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textSecondary)
            
            Button {
                // Would open contacts picker
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text(formData["contact"] ?? "Choose Contact")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(BronColors.textPrimary)
                .padding(BronLayout.spacingM)
                .background(BronColors.gray050)
                .overlay(
                    Rectangle()
                        .strokeBorder(BronColors.gray300, lineWidth: 1)
                )
            }
        }
    }
    
    private var fileUploadField: some View {
        VStack(spacing: BronLayout.spacingM) {
            Button {
                // Would open file picker
            } label: {
                VStack(spacing: BronLayout.spacingS) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 32))
                    Text("TAP TO UPLOAD")
                        .font(BronTypography.meta)
                }
                .foregroundStyle(BronColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(BronLayout.spacingXL)
                .background(BronColors.gray050)
                .overlay(
                    Rectangle()
                        .strokeBorder(BronColors.gray300, style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
        }
    }
    
    private var locationPickerField: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Button {
                // Would open location picker
            } label: {
                HStack {
                    Image(systemName: "location")
                    Text(formData["location"] ?? "Choose Location")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundStyle(BronColors.textPrimary)
                .padding(BronLayout.spacingM)
                .background(BronColors.gray050)
                .overlay(
                    Rectangle()
                        .strokeBorder(BronColors.gray300, lineWidth: 1)
                )
            }
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
        case .listView:
            listView
        default:
            Text("Display content")
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
            Image(systemName: weatherIcon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(BronColors.textSecondary)
            
            VStack(alignment: .leading) {
                if let temp = recipe.schema["temperature"]?.placeholder {
                    Text(temp)
                        .displayStyle(.large)
                        .foregroundStyle(BronColors.textPrimary)
                }
                if let condition = recipe.schema["condition"]?.placeholder {
                    Text(condition)
                        .utilityStyle(.medium)
                        .foregroundStyle(BronColors.textSecondary)
                }
            }
        }
    }
    
    private var weatherIcon: String {
        let condition = recipe.schema["condition"]?.placeholder?.lowercased() ?? ""
        if condition.contains("rain") { return "cloud.rain" }
        if condition.contains("cloud") { return "cloud" }
        if condition.contains("snow") { return "cloud.snow" }
        return "sun.max"
    }
    
    private var progressView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack {
                Text("PROGRESS")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
                Spacer()
                if let progress = recipe.schema["progress"]?.placeholder {
                    Text(progress)
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(BronColors.gray150)
                    Rectangle()
                        .fill(BronColors.black)
                        .frame(width: geo.size.width * progressValue)
                }
            }
            .frame(height: 8)
        }
    }
    
    private var progressValue: CGFloat {
        if let progressStr = recipe.schema["progress"]?.placeholder,
           let value = Double(progressStr.replacingOccurrences(of: "%", with: "")) {
            return CGFloat(value / 100)
        }
        return 0.5
    }
    
    private var listView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
                if let field = recipe.schema[key] {
                    HStack(spacing: BronLayout.spacingS) {
                        Text("•")
                            .foregroundStyle(BronColors.textMeta)
                        Text(field.placeholder ?? field.label ?? key)
                            .utilityStyle(.medium)
                            .foregroundStyle(BronColors.textPrimary)
                    }
                }
            }
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
        case .authGoogle:
            authView(provider: "Google", icon: "g.circle.fill", color: .red)
        case .authApple:
            authView(provider: "Apple", icon: "apple.logo", color: .black)
        case .authOAuth:
            authView(provider: "Provider", icon: "key.fill", color: .gray)
        case .execute:
            executeView
        default:
            EmptyView()
        }
    }
    
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack(spacing: BronLayout.spacingS) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(BronColors.textSecondary)
                Text("Confirm to proceed.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
    }
    
    private var approvalView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack(spacing: BronLayout.spacingS) {
                CommitRule(orientation: .vertical, length: 40)
                VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                    Text("APPROVAL REQUIRED")
                        .font(BronTypography.meta)
                        .foregroundStyle(BronColors.commit)
                    Text("This needs your approval before I proceed.")
                        .utilityStyle(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
        }
    }
    
    private func authView(provider: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: BronLayout.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(color)
            
            Text("Sign in with \(provider) to continue")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(BronLayout.spacingL)
    }
    
    private var executeView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack(spacing: BronLayout.spacingS) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(BronColors.commit)
                Text("Ready to execute this action.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
            }
        }
    }
    
    // MARK: - Rich Components
    
    @ViewBuilder
    private var richComponent: some View {
        switch recipe.componentType {
        case .emailPreview:
            emailPreviewView
        case .emailCompose:
            emailComposeView
        case .calendarEvent:
            calendarEventView
        case .messagePreview:
            messagePreviewView
        case .linkPreview:
            linkPreviewView
        default:
            Text("Content preview")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private var emailPreviewView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            if let to = recipe.schema["to"]?.placeholder {
                Text("TO: \(to)")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            if let subject = recipe.schema["subject"]?.placeholder {
                Text(subject)
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
            }
            BronDivider()
            if let body = recipe.schema["body"]?.placeholder {
                Text(body)
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textSecondary)
                    .lineLimit(5)
            }
        }
    }
    
    private var emailComposeView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            inputField(key: "to", field: SchemaField(type: .email, label: "To", placeholder: "recipient@example.com"))
            inputField(key: "subject", field: SchemaField(type: .text, label: "Subject", placeholder: "Subject"))
            
            VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                Text("MESSAGE")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textSecondary)
                
                TextEditor(text: binding(for: "body"))
                    .font(BronTypography.bodyM)
                    .frame(minHeight: 100)
                    .padding(BronLayout.spacingS)
                    .background(BronColors.gray050)
                    .overlay(
                        Rectangle()
                            .strokeBorder(BronColors.gray300, lineWidth: 1)
                    )
            }
        }
    }
    
    private var calendarEventView: some View {
        HStack(spacing: BronLayout.spacingM) {
            VStack {
                if let month = recipe.schema["month"]?.placeholder {
                    Text(month.uppercased())
                        .font(BronTypography.meta)
                        .foregroundStyle(BronColors.textMeta)
                }
                if let day = recipe.schema["day"]?.placeholder {
                    Text(day)
                        .displayStyle(.large)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            .frame(width: 60)
        .padding()
            .background(BronColors.gray050)
            
            VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                if let title = recipe.schema["title"]?.placeholder {
                    Text(title.uppercased())
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                }
                if let time = recipe.schema["time"]?.placeholder {
                    Text(time)
                        .utilityStyle(.small)
                        .foregroundStyle(BronColors.textMeta)
                }
                if let location = recipe.schema["location"]?.placeholder {
                    HStack(spacing: BronLayout.spacingXS) {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(location)
                    }
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textMeta)
                }
            }
        }
    }
    
    private var messagePreviewView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            HStack {
                if let from = recipe.schema["from"]?.placeholder {
                    Text(from)
                        .utilityStyle(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                }
                Spacer()
                if let time = recipe.schema["time"]?.placeholder {
                    Text(time)
                        .font(BronTypography.meta)
                        .foregroundStyle(BronColors.textMeta)
                }
            }
            if let message = recipe.schema["message"]?.placeholder {
                Text(message)
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textSecondary)
            }
        }
        .padding(BronLayout.spacingM)
        .background(BronColors.gray050)
    }
    
    private var linkPreviewView: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            if let title = recipe.schema["title"]?.placeholder {
                Text(title)
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textPrimary)
                    .lineLimit(2)
            }
            if let description = recipe.schema["description"]?.placeholder {
                Text(description)
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textSecondary)
                    .lineLimit(3)
            }
            if let url = recipe.schema["url"]?.placeholder {
                Text(url)
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
                    .lineLimit(1)
            }
        }
        .padding(BronLayout.spacingM)
        .background(BronColors.gray050)
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        if isReadOnly {
            // Show "Submitted" indicator for already-submitted recipes
            HStack(spacing: BronLayout.spacingS) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(BronColors.textMeta)
                Text("SUBMITTED")
                    .font(BronTypography.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BronLayout.spacingS)
        } else if recipe.componentType.requiresUserInteraction {
            HStack(spacing: BronLayout.spacingM) {
                // Defer/Skip button
                if showDeferButton {
                    Button("SKIP FOR NOW") {
                        onAction?(.skip, nil)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                // Primary action button
                Button(primaryButtonText) {
                    handlePrimaryAction()
                }
                .buttonStyle(CommitButtonStyle(isEnabled: isFormValid && !isSubmitting))
                .disabled(!isFormValid || isSubmitting)
            }
        }
    }
    
    private var showDeferButton: Bool {
        switch recipe.componentType {
        case .form, .picker, .multiSelect, .datePicker, .fileUpload, .locationPicker, .contactPicker:
            return true
        default:
            return false
        }
    }
    
    private var primaryButtonText: String {
        if isSubmitting { return "WORKING..." }
        
        switch recipe.componentType {
        case .confirmation: return "CONFIRM"
        case .approval: return "APPROVE"
        case .authGoogle: return "SIGN IN WITH GOOGLE"
        case .authApple: return "SIGN IN WITH APPLE"
        case .authOAuth: return "SIGN IN"
        case .execute: return "EXECUTE"
        case .emailCompose: return "SEND"
        default: return "CONTINUE"
        }
    }
    
    private func handlePrimaryAction() {
        // Validate submission for input components
        if recipe.componentType.category == .input {
            let validation = RecipeValidator.validateSubmission(formData, for: recipe)
            if !validation.isValid {
                // Show validation errors
                validationErrors = [:]
                for error in validation.errors {
                    if case .missingRequiredField(let field) = error {
                        validationErrors[field] = "Required"
                    } else if case .invalidValue(let field, let reason) = error {
                        validationErrors[field] = reason
                    }
                }
                return
            }
        }
        
        isSubmitting = true
        
        // Dispatch appropriate action
        let action: RecipeAction
        switch recipe.componentType {
        case .confirmation: action = .confirm
        case .approval: action = .approve
        case .authGoogle, .authApple, .authOAuth: action = .auth
        case .execute: action = .execute
        default: action = .submit
        }
        
        onAction?(action, recipe.componentType.category == .input ? formData : nil)
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
    
    // MARK: - Helpers
    
    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { formData[key] ?? "" },
            set: { 
                formData[key] = $0
                validationErrors[key] = nil // Clear error on edit
            }
        )
    }
    
    private func toggleMultiSelect(_ option: String) {
        var selections = (formData["selections"] ?? "").split(separator: ",").map(String.init)
        if selections.contains(option) {
            selections.removeAll { $0 == option }
        } else {
            selections.append(option)
        }
        formData["selections"] = selections.joined(separator: ",")
    }
    
    private func isSelected(_ option: String) -> Bool {
        (formData["selections"] ?? "").split(separator: ",").contains(Substring(option))
    }
    
    private func keyboardType(for fieldType: FieldType) -> UIKeyboardType {
        switch fieldType {
        case .email: return .emailAddress
        case .phone: return .phonePad
        case .number, .currency: return .decimalPad
        case .url: return .URL
        default: return .default
        }
    }
    
    private func contentType(for fieldType: FieldType) -> UITextContentType? {
        switch fieldType {
        case .email: return .emailAddress
        case .phone: return .telephoneNumber
        case .url: return .URL
        default: return nil
        }
    }
    
    private func dateComponents(for fieldType: FieldType) -> DatePickerComponents {
        switch fieldType {
        case .date: return .date
        case .time: return .hourAndMinute
        case .datetime: return [.date, .hourAndMinute]
        default: return .date
        }
    }
}

// MARK: - Previews

#Preview("Form") {
    UIRecipeView(recipe: .preview)
        .padding()
}

#Preview("Picker") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .picker,
        schema: ["category": SchemaField(
            type: .select,
            label: "Category",
            options: ["Food", "Transport", "Entertainment", "Shopping"]
        )],
        title: "Select Category"
    ))
    .padding()
}

#Preview("Confirmation") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .confirmation,
        title: "Confirm Action",
        description: "This will send the email to 5 recipients."
    ))
    .padding()
}

#Preview("Approval") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .approval,
        title: "Approval Required",
        description: "This action requires your explicit approval."
    ))
    .padding()
}

#Preview("Weather") {
    UIRecipeView(recipe: UIRecipe(
        componentType: .weather,
        schema: [
            "temperature": SchemaField(type: .text, placeholder: "72°F"),
            "condition": SchemaField(type: .text, placeholder: "Sunny")
        ],
        title: "Current Weather"
    ))
    .padding()
}
