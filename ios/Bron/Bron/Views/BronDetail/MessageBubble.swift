//
//  MessageBubble.swift
//  Bron
//
//  Chat message - "Panel + Note" layout
//  User: minimal right-aligned bubbles
//  Bron: full-width editorial blocks (no bubbles)
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var onRecipeAction: ((RecipeAction, [String: String]?) -> Void)?
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        if isUser {
            userMessage
        } else {
            bronMessage
        }
    }
    
    // MARK: - User Message (Minimal Bubble)
    
    private var userMessage: some View {
        HStack {
            Spacer(minLength: 60)
            
            Text(message.content)
                .font(BronTypography.bodyM)
                .foregroundStyle(BronColors.textPrimary)
                .padding(.horizontal, BronLayout.spacingL)
                .padding(.vertical, BronLayout.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: BronLayout.cornerRadiusM)
                        .fill(BronColors.gray050)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BronLayout.cornerRadiusM)
                        .strokeBorder(BronColors.gray150, lineWidth: 1)
                )
        }
        .padding(.horizontal, BronLayout.spacingL)
    }
    
    // MARK: - Bron Message (Editorial Block)
    
    private var bronMessage: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            // Bron Band (label for structured responses)
            if let band = detectBronBand(message.content) {
                bronBandLabel(band)
                    .padding(.bottom, BronLayout.spacingXS)
            }
            
            // Divider line
            Rectangle()
                .fill(BronColors.gray150)
                .frame(height: 1)
            
            // Task state update (if any)
            if let stateUpdate = message.taskStateUpdate {
                BronStatusBadge(status: stateUpdate)
                    .padding(.top, BronLayout.spacingS)
            }
            
            // Message content - full width editorial
            markdownContent(message.content)
                .padding(.vertical, BronLayout.spacingM)
            
            // UI Recipe (if any)
            if let recipe = message.uiRecipe {
                UIRecipeView(
                    recipe: recipe,
                    onAction: onRecipeAction
                )
                .padding(.top, BronLayout.spacingS)
            }
            
            // Timestamp
            Text(message.createdAt, style: .time)
                .font(BronTypography.meta)
                .foregroundStyle(BronColors.textMeta)
                .padding(.top, BronLayout.spacingS)
        }
        .padding(.horizontal, BronLayout.spacingL)
        .padding(.vertical, BronLayout.spacingM)
    }
    
    // MARK: - Bron Band Detection
    
    private func detectBronBand(_ content: String) -> String? {
        let uppercased = content.uppercased()
        
        // Detect structured response types
        if uppercased.hasPrefix("PLAN") || content.contains("Here's what I") || content.contains("my plan") {
            return "PLAN"
        } else if uppercased.hasPrefix("NEXT STEP") || content.contains("Next step") || content.contains("I need") {
            return "NEXT STEP"
        } else if uppercased.hasPrefix("UPDATE") || content.contains("update") && content.contains(":") {
            return "UPDATE"
        } else if uppercased.hasPrefix("DONE") || content.contains("completed") || content.contains("finished") {
            return "DONE"
        } else if content.contains("•") || content.contains("- ") {
            return "BRON"
        }
        
        return nil
    }
    
    private func bronBandLabel(_ label: String) -> some View {
        Text(label)
            .font(BronTypography.meta)
            .fontWeight(.bold)
            .foregroundStyle(BronColors.textSecondary)
            .tracking(1.5)
    }
    
    // MARK: - Markdown Content (Full Width)
    
    @ViewBuilder
    private func markdownContent(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingM) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("#") {
                    renderHeader(line)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                    // Bullet points
                    HStack(alignment: .top, spacing: BronLayout.spacingS) {
                        Text("•")
                            .font(BronTypography.bodyM)
                            .foregroundStyle(BronColors.textSecondary)
                        renderInlineMarkdown(String(line.dropFirst(2)))
                    }
                } else if let match = line.firstMatch(of: /^(\d+)\.\s(.+)/) {
                    // Numbered lists
                    HStack(alignment: .top, spacing: BronLayout.spacingS) {
                        Text("\(match.1).")
                            .font(BronTypography.bodyM)
                            .foregroundStyle(BronColors.textSecondary)
                            .frame(width: 20, alignment: .trailing)
                        renderInlineMarkdown(String(match.2))
                    }
                } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    renderInlineMarkdown(line)
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderHeader(_ line: String) -> some View {
        let level = line.prefix(while: { $0 == "#" }).count
        let text = String(line.dropFirst(level).trimmingCharacters(in: .whitespaces))
        
        switch level {
        case 1:
            Text(text.uppercased())
                .font(BronTypography.displayM)
                .fontWeight(.black)
                .foregroundStyle(BronColors.textPrimary)
                .tracking(1)
                .padding(.top, BronLayout.spacingM)
        case 2:
            Text(text.uppercased())
                .font(BronTypography.displayS)
                .fontWeight(.bold)
                .foregroundStyle(BronColors.textPrimary)
                .tracking(0.5)
                .padding(.top, BronLayout.spacingS)
        default:
            Text(text)
                .font(BronTypography.bodyL)
                .fontWeight(.semibold)
                .foregroundStyle(BronColors.textPrimary)
        }
    }
    
    @ViewBuilder
    private func renderInlineMarkdown(_ content: String) -> some View {
        if let attributedString = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .font(BronTypography.bodyM)
                .foregroundStyle(BronColors.textPrimary)
                .tint(BronColors.commit)
        } else {
            Text(content)
                .font(BronTypography.bodyM)
                .foregroundStyle(BronColors.textPrimary)
        }
    }
}

// MARK: - Previews

#Preview("User Message") {
    VStack(spacing: BronLayout.spacingL) {
        MessageBubble(message: ChatMessage(
            bronId: UUID(),
            role: .user,
            content: "Submit my expense receipt from lunch",
            createdAt: Date()
        ))
    }
    .padding(.vertical)
    .background(BronColors.surface)
}

#Preview("Bron Message - Plan") {
    VStack(spacing: BronLayout.spacingL) {
        MessageBubble(message: ChatMessage(
            bronId: UUID(),
            role: .assistant,
            content: "Here's what I can do:\n• Collect receipt details\n• Draft expense report\n• Submit for approval",
            taskStateUpdate: "planned",
            createdAt: Date()
        ))
    }
    .padding(.vertical)
    .background(BronColors.surface)
}

#Preview("Bron Message - Next Step") {
    VStack(spacing: BronLayout.spacingL) {
        MessageBubble(message: ChatMessage(
            bronId: UUID(),
            role: .assistant,
            content: "I need the receipt photo to continue.",
            taskStateUpdate: "needs_info",
            createdAt: Date()
        ))
    }
    .padding(.vertical)
    .background(BronColors.surface)
}

#Preview("With UI Recipe") {
    VStack(spacing: BronLayout.spacingL) {
        MessageBubble(message: ChatMessage(
            bronId: UUID(),
            role: .assistant,
            content: "I need a few details:",
            uiRecipe: .preview,
            createdAt: Date()
        ))
    }
    .padding(.vertical)
    .background(BronColors.surface)
}
