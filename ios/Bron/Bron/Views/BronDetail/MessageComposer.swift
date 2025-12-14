//
//  MessageComposer.swift
//  Bron
//
//  Message input - editorial, tool-like, minimal
//

import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let onSend: () -> Void
    var suggestions: [Suggestion]?
    var onSuggestionTap: ((Suggestion) -> Void)?
    var isLoading: Bool = false
    var placeholder: String = "Message"
    
    @FocusState private var isFocused: Bool
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestion row (when input is empty)
            if let suggestions = suggestions, !suggestions.isEmpty, text.isEmpty {
                suggestionRow(suggestions)
            }
            
            BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
            
            // Input area
            HStack(alignment: .bottom, spacing: BronLayout.spacingM) {
                // Text input
                TextField(placeholder, text: $text, axis: .vertical)
                    .font(BronTypography.bodyL)
                    .lineLimit(1...6)
                    .focused($isFocused)
                    .padding(BronLayout.spacingM)
                
                // Send button
                sendButton
            }
            .padding(.horizontal, BronLayout.spacingM)
            .padding(.vertical, BronLayout.spacingS)
            .background(BronColors.surface)
        }
    }
    
    // MARK: - Suggestion Row
    
    private func suggestionRow(_ suggestions: [Suggestion]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BronLayout.spacingS) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSuggestionTap?(suggestion)
                    } label: {
                        Text(suggestion.text)
                            .font(BronTypography.meta)
                            .foregroundStyle(BronColors.textSecondary)
                            .padding(.horizontal, BronLayout.spacingM)
                            .padding(.vertical, BronLayout.spacingS)
                            .background(BronColors.gray050)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(BronColors.gray300, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BronLayout.spacingM)
            .padding(.vertical, BronLayout.spacingS)
        }
        .background(BronColors.surfaceSecondary)
    }
    
    // MARK: - Send Button
    
    private var sendButton: some View {
        Button {
            if canSend {
                onSend()
            }
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(BronColors.textSecondary)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(canSend ? BronColors.black : BronColors.gray300)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(canSend ? BronColors.gray150 : BronColors.gray050)
            )
        }
        .disabled(!canSend)
    }
}

// MARK: - Suggestion Model

struct Suggestion: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String?
    let category: SuggestionCategory
    
    init(_ text: String, icon: String? = nil, category: SuggestionCategory = .general) {
        self.text = text
        self.icon = icon
        self.category = category
    }
}

enum SuggestionCategory: String, CaseIterable {
    case general
    case action
    case question
    case confirmation
    
    var color: Color {
        // All grayscale in broadcast style
        BronColors.textSecondary
    }
}

// MARK: - Default Suggestions

extension Suggestion {
    static let defaultSuggestions: [Suggestion] = [
        Suggestion("What can you do?"),
        Suggestion("Create a new task"),
        Suggestion("Check my tasks"),
    ]
    
    static func contextual(for taskState: String?) -> [Suggestion] {
        guard let state = taskState else { return defaultSuggestions }
        
        switch state {
        case "needs_info":
            return [
                Suggestion("I'll provide the info"),
                Suggestion("Skip this for now"),
                Suggestion("What info do you need?"),
            ]
        case "ready":
            return [
                Suggestion("Yes, execute it"),
                Suggestion("Let me review first"),
                Suggestion("Make changes"),
            ]
        case "planned":
            return [
                Suggestion("Looks good, proceed"),
                Suggestion("Modify the plan"),
                Suggestion("Save as a skill"),
            ]
        case "executing":
            return [
                Suggestion("What's the status?"),
                Suggestion("Stop execution"),
            ]
        case "done":
            return [
                Suggestion("Start a new task"),
                Suggestion("Save this as a skill"),
            ]
        default:
            return defaultSuggestions
        }
    }
}

// MARK: - Previews

#Preview("Empty") {
    VStack {
        Spacer()
        MessageComposer(
            text: .constant(""),
            onSend: {},
            suggestions: Suggestion.defaultSuggestions
        )
    }
    .background(BronColors.surfaceSecondary)
}

#Preview("With Text") {
    VStack {
        Spacer()
        MessageComposer(
            text: .constant("Help me submit my receipt"),
            onSend: {}
        )
    }
    .background(BronColors.surfaceSecondary)
}
