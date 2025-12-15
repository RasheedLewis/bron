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
    var bronId: String = ""  // Required for OAuth flows
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
            case .optionButtons:
                optionButtonsView
            case .optionCards:
                optionCardsView
            case .quickReplies:
                quickRepliesView
            case .infoChips:
                infoChipsView
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
    
    // MARK: - Option/Choice Components
    
    /// ACTION LIST - Full-width vertical buttons (broadcast control panel style)
    private var optionButtonsView: some View {
        let options = extractOptions()
        
        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    formData["selected"] = option.id
                    onAction?(.submit, ["selected": option.id])
                } label: {
                    HStack(spacing: 0) {
                        Text("[ \(option.title.uppercased()) ]")
                            .font(BronTypography.bodyM)
                            .fontWeight(.medium)
                            .foregroundStyle(BronColors.textPrimary)
                            .tracking(0.5)
                        
                        Spacer()
                    }
                    .padding(.horizontal, BronLayout.spacingM)
                    .padding(.vertical, BronLayout.spacingM)
                    .background(BronColors.surface)
                }
                .buttonStyle(ActionButtonStyle())
                
                // Divider between options
                if index < options.count - 1 {
                    Rectangle()
                        .fill(BronColors.gray300)
                        .frame(height: 1)
                }
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.black, lineWidth: 1)
        )
    }
    
    /// OPTION CARDS - Choices with brief descriptions (broadcast panel style)
    private var optionCardsView: some View {
        let options = extractOptions()
        
        return VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    formData["selected"] = option.id
                    onAction?(.submit, ["selected": option.id])
                } label: {
                    HStack(spacing: 0) {
                        // Left accent bar
                        Rectangle()
                            .fill(BronColors.black)
                            .frame(width: 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title.uppercased())
                                .font(BronTypography.bodyM)
                                .fontWeight(.semibold)
                                .foregroundStyle(BronColors.textPrimary)
                                .tracking(0.5)
                            
                            if let desc = option.description {
                                Text(desc)
                                    .font(BronTypography.bodyM)
                                    .foregroundStyle(BronColors.textMeta)
                            }
                        }
                        .padding(.horizontal, BronLayout.spacingM)
                        .padding(.vertical, BronLayout.spacingS)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(BronColors.surface)
                }
                .buttonStyle(ActionButtonStyle())
                
                // Divider
                if index < options.count - 1 {
                    Rectangle()
                        .fill(BronColors.gray300)
                        .frame(height: 1)
                }
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(BronColors.gray300, lineWidth: 1)
        )
    }
    
    /// QUICK REPLIES - Horizontal tappable options (rectangular, not pills)
    private var quickRepliesView: some View {
        let options = extractOptions()
        
        return HStack(spacing: BronLayout.spacingS) {
            ForEach(options, id: \.id) { option in
                Button {
                    formData["selected"] = option.id
                    onAction?(.submit, ["selected": option.id])
                } label: {
                    Text(option.title.uppercased())
                        .font(BronTypography.meta)
                        .fontWeight(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                        .tracking(0.5)
                        .padding(.horizontal, BronLayout.spacingM)
                        .padding(.vertical, BronLayout.spacingS)
                        .background(BronColors.surface)
                        .overlay(
                            Rectangle()
                                .strokeBorder(BronColors.gray300, lineWidth: 1)
                        )
                }
                .buttonStyle(ActionButtonStyle())
            }
            
            Spacer()
        }
    }
    
    /// INFO CHIPS - Missing info as tappable chips
    private var infoChipsView: some View {
        let options = extractOptions()
        
        return VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Text("MISSING")
                .font(BronTypography.meta)
                .fontWeight(.bold)
                .foregroundStyle(BronColors.textMeta)
                .tracking(1)
            
            HStack(spacing: BronLayout.spacingS) {
                ForEach(options, id: \.id) { option in
                    Button {
                        formData["selected"] = option.id
                        onAction?(.submit, ["selected": option.id])
                    } label: {
                        Text("[ \(option.title.uppercased()) ]")
                            .font(BronTypography.meta)
                            .foregroundStyle(BronColors.textPrimary)
                            .padding(.horizontal, BronLayout.spacingS)
                            .padding(.vertical, BronLayout.spacingXS)
                            .background(BronColors.surface)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(BronColors.gray500, lineWidth: 1)
                            )
                    }
                    .buttonStyle(ActionButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Option Helpers
    
    private struct OptionItem {
        let id: String
        let title: String
        let description: String?
        let icon: String?
    }
    
    private func extractOptions() -> [OptionItem] {
        // Extract options from schema fields
        var options: [OptionItem] = []
        
        for (key, field) in recipe.schema.sorted(by: { $0.key < $1.key }) {
            if let fieldOptions = field.options {
                // If field has options array, use those
                for opt in fieldOptions {
                    options.append(OptionItem(id: opt, title: opt, description: nil, icon: nil))
                }
            } else {
                // Otherwise, treat each schema field as an option
                options.append(OptionItem(
                    id: key,
                    title: field.label ?? key,
                    description: field.placeholder,
                    icon: nil
                ))
            }
        }
        
        return options
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
        case .styledList:
            styledListView
        case .actionCards:
            actionCardsView
        case .statusStrip:
            statusStripView
        default:
            Text("Display content")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textMeta)
        }
    }
    
    /// STYLED LIST - Display items with left accent (broadcast style)
    private var styledListView: some View {
        VStack(spacing: 0) {
            ForEach(Array(recipe.schema.keys.sorted().enumerated()), id: \.offset) { index, key in
                if let field = recipe.schema[key] {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(BronColors.gray500)
                            .frame(width: 3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text((field.label ?? key).uppercased())
                                .font(BronTypography.meta)
                                .fontWeight(.medium)
                                .foregroundStyle(BronColors.textPrimary)
                            
                            if let placeholder = field.placeholder {
                                Text(placeholder)
                                    .font(BronTypography.bodyM)
                                    .foregroundStyle(BronColors.textMeta)
                            }
                        }
                        .padding(.horizontal, BronLayout.spacingM)
                        .padding(.vertical, BronLayout.spacingS)
                        
                        Spacer()
                    }
                    
                    Rectangle().fill(BronColors.gray300).frame(height: 1)
                }
            }
        }
        .overlay(Rectangle().strokeBorder(BronColors.gray300, lineWidth: 1))
    }
    
    /// ACTION CARDS - Tappable suggestions (deep red = commit)
    private var actionCardsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(recipe.schema.keys.sorted().enumerated()), id: \.offset) { index, key in
                if let field = recipe.schema[key] {
                    Button {
                        onAction?(.submit, ["action": key])
                    } label: {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(BronColors.deepRed)
                                .frame(width: 4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text((field.label ?? key).uppercased())
                                    .font(BronTypography.bodyM)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(BronColors.textPrimary)
                                
                                if let desc = field.placeholder {
                                    Text(desc)
                                        .font(BronTypography.bodyM)
                                        .foregroundStyle(BronColors.textMeta)
                                }
                            }
                            .padding(.horizontal, BronLayout.spacingM)
                            .padding(.vertical, BronLayout.spacingS)
                            
                            Spacer()
                        }
                        .background(BronColors.surface)
                    }
                    .buttonStyle(ActionButtonStyle())
                    
                    if index < recipe.schema.count - 1 {
                        Rectangle().fill(BronColors.gray300).frame(height: 1)
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(BronColors.gray300, lineWidth: 1))
    }
    
    private func iconForFieldType(_ type: FieldType) -> String {
        switch type {
        case .text: return "doc.text"
        case .number: return "number"
        case .date, .datetime: return "calendar"
        case .time: return "clock"
        case .email: return "envelope"
        case .phone: return "phone"
        case .url: return "link"
        case .select, .multiSelect: return "list.bullet"
        case .boolean: return "checkmark.circle"
        case .file, .document: return "doc"
        case .image: return "photo"
        case .location: return "location"
        case .contact: return "person"
        case .currency: return "dollarsign.circle"
        default: return "circle"
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
    
    /// STATUS STRIP - Single-line status (broadcast style)
    private var statusStripView: some View {
        HStack(spacing: BronLayout.spacingS) {
            // Extract status info from schema
            let status = recipe.schema["status"]?.placeholder ?? "WORKING"
            let step = recipe.schema["step"]?.placeholder
            
            Text(status.uppercased())
                .font(BronTypography.displayM)
                .fontWeight(.bold)
                .foregroundStyle(BronColors.textPrimary)
                .tracking(1)
            
            if let step = step {
                Text("•")
                    .foregroundStyle(BronColors.textMeta)
                Text(step.uppercased())
                    .font(BronTypography.bodyM)
                    .foregroundStyle(BronColors.textMeta)
                    .tracking(0.5)
            }
            
            Spacer()
        }
        .padding(BronLayout.spacingM)
        .background(BronColors.black)
        .foregroundStyle(BronColors.white)
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
            brandedAuthView(brand: .google, providerName: "Google")
        case .authApple:
            brandedAuthView(brand: .apple, providerName: "Apple")
        case .authOAuth:
            brandedAuthView(brand: BrandStyle.forProvider(recipe.title), providerName: recipe.title ?? "Provider")
        case .execute:
            executeView
        case .apiKeyInput:
            apiKeyInputView
        case .credentialsInput:
            credentialsInputView
        case .serviceConnect:
            serviceConnectView
        case .authCallback:
            authCallbackView
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
    
    /// Branded auth button matching the service's visual identity
    private func brandedAuthView(brand: BrandStyle, providerName: String) -> some View {
        BrandedAuthButton(
            brand: brand,
            providerName: providerName,
            description: recipe.description,
            bronId: bronId,
            onSuccess: { result in
                // Notify that auth succeeded
                onAction?(.auth, ["provider": providerName.lowercased(), "success": "true", "message": result.message])
            },
            onError: { error in
                // Auth failed - could show error UI
                print("Auth failed: \(error.localizedDescription)")
            }
        )
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
    
    // MARK: - Credential Input Views
    
    private var apiKeyInputView: some View {
        let brand = BrandStyle.forProvider(recipe.title)
        
        return VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            // Branded provider header
            HStack(spacing: BronLayout.spacingM) {
                // Brand icon with accent color
                Image(systemName: brand.iconName)
                    .font(.system(size: 28, weight: brand.fontWeight))
                    .foregroundStyle(brand.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(brand.primaryColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: brand.cornerRadius))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("API KEY REQUIRED")
                        .font(BronTypography.meta)
                        .tracking(1)
                        .foregroundStyle(BronColors.textMeta)
                    
                    if let title = recipe.title {
                        Text(title.uppercased())
                            .font(BronTypography.displayS)
                            .foregroundStyle(BronColors.textPrimary)
                    }
                }
            }
            
            // Description
            if let description = recipe.description {
                Text(description)
                    .font(BronTypography.bodyS)
                    .foregroundStyle(BronColors.textSecondary)
            }
            
            // API Key input field with brand accent
            SecureField("Enter API Key", text: binding(for: "api_key"))
                .font(BronTypography.bodyM)
                .padding(BronLayout.spacingM)
                .background(BronColors.surface)
                .overlay(
                    Rectangle()
                        .strokeBorder(brand.primaryColor.opacity(0.3), lineWidth: 1)
                )
            
            // Security note
            HStack(spacing: BronLayout.spacingXS) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Stored securely on-device")
                    .font(BronTypography.meta)
            }
            .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private var credentialsInputView: some View {
        let providerName = recipe.title ?? "Service"
        let brand = BrandStyle.forProvider(providerName)
        
        return VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            // Branded provider header
            HStack(spacing: BronLayout.spacingM) {
                Image(systemName: brand.iconName)
                    .font(.system(size: 24, weight: brand.fontWeight))
                    .foregroundStyle(brand.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(brand.primaryColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: brand.cornerRadius))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SIGN IN TO")
                        .font(BronTypography.meta)
                        .tracking(1)
                        .foregroundStyle(BronColors.textMeta)
                    
                    Text(providerName.uppercased())
                        .font(BronTypography.displayS)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            
            // Username field with brand accent
            TextField("Email or username", text: binding(for: "username"))
                .font(BronTypography.bodyM)
                .textContentType(.username)
                .autocapitalization(.none)
                .padding(BronLayout.spacingM)
                .background(BronColors.surface)
                .overlay(
                    Rectangle()
                        .strokeBorder(brand.primaryColor.opacity(0.3), lineWidth: 1)
                )
            
            // Password field
            SecureField("Password", text: binding(for: "password"))
                .font(BronTypography.bodyM)
                .textContentType(.password)
                .padding(BronLayout.spacingM)
                .background(BronColors.surface)
                .overlay(
                    Rectangle()
                        .strokeBorder(brand.primaryColor.opacity(0.3), lineWidth: 1)
                )
            
            // Security note
            HStack(spacing: BronLayout.spacingXS) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Stored securely on-device")
                    .font(BronTypography.meta)
            }
            .foregroundStyle(BronColors.textMeta)
        }
    }
    
    private var serviceConnectView: some View {
        let serviceName = recipe.title ?? "Service"
        let permissions = recipe.schema.values.compactMap { $0.label }
        let brand = BrandStyle.forProvider(serviceName)
        
        return VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            // Branded service header
            HStack(spacing: BronLayout.spacingM) {
                Image(systemName: brand.iconName)
                    .font(.system(size: 32, weight: brand.fontWeight))
                    .foregroundStyle(brand.textColor)
                    .frame(width: 56, height: 56)
                    .background(brand.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: brand.cornerRadius))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CONNECT")
                        .font(BronTypography.meta)
                        .tracking(1)
                        .foregroundStyle(BronColors.textMeta)
                    
                    Text(serviceName.uppercased())
                        .font(BronTypography.displayM)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            
            // Description
            if let description = recipe.description {
                Text(description)
                    .font(BronTypography.bodyS)
                    .foregroundStyle(BronColors.textSecondary)
            }
            
            // Permissions list with brand accent
            if !permissions.isEmpty {
                VStack(alignment: .leading, spacing: BronLayout.spacingXS) {
                    Text("PERMISSIONS")
                        .font(BronTypography.meta)
                        .tracking(1)
                        .foregroundStyle(BronColors.textMeta)
                    
                    ForEach(permissions, id: \.self) { permission in
                        HStack(spacing: BronLayout.spacingS) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(brand.primaryColor)
                            Text(permission)
                                .font(BronTypography.bodyS)
                                .foregroundStyle(BronColors.textSecondary)
                        }
                    }
                }
                .padding(BronLayout.spacingM)
                .background(brand.primaryColor.opacity(0.05))
                .overlay(
                    Rectangle()
                        .strokeBorder(brand.primaryColor.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var authCallbackView: some View {
        VStack(spacing: BronLayout.spacingL) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Completing sign in...")
                .utilityStyle(.medium)
                .foregroundStyle(BronColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(BronLayout.spacingXL)
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
        } else if recipe.componentType.requiresUserInteraction && !hasBuiltInButton {
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
    
    /// Components that have their own built-in action button
    private var hasBuiltInButton: Bool {
        switch recipe.componentType {
        case .authGoogle, .authApple, .authOAuth, .serviceConnect:
            return true
        case .optionButtons, .optionCards, .quickReplies, .infoChips, .actionCards:
            return true  // These are tappable directly
        default:
            return false
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

// MARK: - Brand Styles (Service-specific branding)

/// Brand styling for known services
struct BrandStyle {
    let primaryColor: Color
    let secondaryColor: Color?
    let textColor: Color
    let iconName: String
    let fontWeight: Font.Weight
    let cornerRadius: CGFloat
    
    // Known service brands
    static let google = BrandStyle(
        primaryColor: Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
        secondaryColor: nil,
        textColor: .white,
        iconName: "g.circle.fill",
        fontWeight: .medium,
        cornerRadius: 4
    )
    
    static let apple = BrandStyle(
        primaryColor: .black,
        secondaryColor: nil,
        textColor: .white,
        iconName: "apple.logo",
        fontWeight: .medium,
        cornerRadius: 8
    )
    
    static let stripe = BrandStyle(
        primaryColor: Color(red: 0.39, green: 0.35, blue: 0.95), // Stripe Purple
        secondaryColor: nil,
        textColor: .white,
        iconName: "creditcard.fill",
        fontWeight: .semibold,
        cornerRadius: 6
    )
    
    static let amadeus = BrandStyle(
        primaryColor: Color(red: 0.0, green: 0.27, blue: 0.53), // Amadeus Navy
        secondaryColor: Color(red: 0.0, green: 0.65, blue: 0.89),
        textColor: .white,
        iconName: "airplane",
        fontWeight: .semibold,
        cornerRadius: 4
    )
    
    static let booking = BrandStyle(
        primaryColor: Color(red: 0.0, green: 0.21, blue: 0.53), // Booking.com Blue
        secondaryColor: nil,
        textColor: .white,
        iconName: "bed.double.fill",
        fontWeight: .bold,
        cornerRadius: 2
    )
    
    static let gmail = BrandStyle(
        primaryColor: Color(red: 0.92, green: 0.26, blue: 0.21), // Gmail Red
        secondaryColor: nil,
        textColor: .white,
        iconName: "envelope.fill",
        fontWeight: .medium,
        cornerRadius: 4
    )
    
    static let slack = BrandStyle(
        primaryColor: Color(red: 0.23, green: 0.09, blue: 0.33), // Slack Purple
        secondaryColor: nil,
        textColor: .white,
        iconName: "number",
        fontWeight: .bold,
        cornerRadius: 4
    )
    
    static let openai = BrandStyle(
        primaryColor: Color(red: 0.0, green: 0.65, blue: 0.52), // OpenAI Green-ish
        secondaryColor: nil,
        textColor: .white,
        iconName: "brain",
        fontWeight: .medium,
        cornerRadius: 8
    )
    
    static let twilio = BrandStyle(
        primaryColor: Color(red: 0.95, green: 0.23, blue: 0.27), // Twilio Red
        secondaryColor: nil,
        textColor: .white,
        iconName: "phone.fill",
        fontWeight: .semibold,
        cornerRadius: 4
    )
    
    static let plaid = BrandStyle(
        primaryColor: .black,
        secondaryColor: nil,
        textColor: .white,
        iconName: "building.columns.fill",
        fontWeight: .semibold,
        cornerRadius: 8
    )
    
    static let calendar = BrandStyle(
        primaryColor: Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
        secondaryColor: nil,
        textColor: .white,
        iconName: "calendar",
        fontWeight: .medium,
        cornerRadius: 4
    )
    
    static let uber = BrandStyle(
        primaryColor: .black,
        secondaryColor: nil,
        textColor: .white,
        iconName: "car.fill",
        fontWeight: .bold,
        cornerRadius: 8
    )
    
    static let defaultStyle = BrandStyle(
        primaryColor: BronColors.gray700,
        secondaryColor: nil,
        textColor: .white,
        iconName: "key.fill",
        fontWeight: .medium,
        cornerRadius: 4
    )
    
    /// Get brand style from provider name
    static func forProvider(_ provider: String?) -> BrandStyle {
        guard let provider = provider?.lowercased() else { return defaultStyle }
        
        switch provider {
        case "google", "gmail", "google_calendar", "google_drive":
            return provider.contains("mail") ? gmail : google
        case "apple":
            return apple
        case "stripe":
            return stripe
        case "amadeus", "skyscanner", "kiwi":
            return amadeus
        case "booking", "booking.com", "hotels", "airbnb":
            return booking
        case "slack":
            return slack
        case "openai", "chatgpt":
            return openai
        case "twilio":
            return twilio
        case "plaid":
            return plaid
        case "calendar":
            return calendar
        case "uber", "lyft":
            return uber
        default:
            return defaultStyle
        }
    }
}

// MARK: - Action Button Style (Broadcast Control Panel)

/// Button style that feels like a control panel - immediate feedback, no bounce
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? BronColors.gray050 : BronColors.surface)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Branded Auth Button (Real OAuth)

/// Auth button that triggers real OAuth flow via ASWebAuthenticationSession
struct BrandedAuthButton: View {
    let brand: BrandStyle
    let providerName: String
    let description: String?
    let bronId: String
    let onSuccess: (OAuthResult) -> Void
    let onError: (Error) -> Void
    
    @StateObject private var authService = AuthenticationService.shared
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var authSuccess: String?
    
    var body: some View {
        VStack(spacing: BronLayout.spacingM) {
            // Success state
            if let successMessage = authSuccess {
                HStack(spacing: BronLayout.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(successMessage)
                        .font(BronTypography.bodyM)
                        .foregroundStyle(BronColors.textPrimary)
                }
                .padding(BronLayout.spacingM)
            }
            // Error state
            else if let error = authError {
                VStack(spacing: BronLayout.spacingS) {
                    Text(error)
                        .font(BronTypography.bodyS)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        authError = nil
                        startAuth()
                    }
                    .font(BronTypography.button)
                    .foregroundStyle(brand.primaryColor)
                }
                .padding(BronLayout.spacingM)
            }
            // Normal state - show auth button
            else {
                Button {
                    startAuth()
                } label: {
                    HStack(spacing: BronLayout.spacingM) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: brand.textColor))
                        } else {
                            Image(systemName: brand.iconName)
                                .font(.system(size: 20, weight: brand.fontWeight))
                        }
                        
                        Text(isAuthenticating ? "Signing in..." : "Sign in with \(providerName)")
                            .font(.system(size: 18, weight: brand.fontWeight))
                    }
                    .foregroundStyle(brand.textColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(brand.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: brand.cornerRadius))
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                
                // Subtle description
                if let description = description {
                    Text(description)
                        .font(BronTypography.meta)
                        .foregroundStyle(BronColors.textMeta)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(BronLayout.spacingM)
    }
    
    private func startAuth() {
        guard !bronId.isEmpty else {
            authError = "Missing Bron ID for authentication"
            return
        }
        
        isAuthenticating = true
        authError = nil
        
        Task {
            do {
                let result = try await authService.startOAuth(
                    provider: providerName.lowercased(),
                    bronId: bronId
                )
                
                await MainActor.run {
                    isAuthenticating = false
                    if result.success {
                        authSuccess = result.message
                        onSuccess(result)
                    } else {
                        authError = result.message
                    }
                }
            } catch let error as OAuthError {
                await MainActor.run {
                    isAuthenticating = false
                    switch error {
                    case .cancelled:
                        // User cancelled - don't show error
                        break
                    default:
                        authError = error.localizedDescription
                        onError(error)
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    authError = error.localizedDescription
                    onError(error)
                }
            }
        }
    }
}

// MARK: - Flow Layout (for Quick Replies)

/// A horizontal wrapping layout for pill-shaped buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, frame) in result.frames.enumerated() {
            let position = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
            subviews[index].place(at: position, proposal: .init(frame.size))
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = max(totalHeight, currentY + size.height)
        }
        
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
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
