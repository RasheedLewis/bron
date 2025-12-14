//
//  BronTheme.swift
//  Bron
//
//  Championship Broadcast Design System
//  Theme: ESPN / NBA Energy · High-contrast B&W · Deep Red Accent
//

import SwiftUI

// MARK: - Color System

/// Bron's grayscale-first color palette
/// UI must function at 100% clarity in pure grayscale
struct BronColors {
    // Primary
    static let black = Color(hex: "#000000")
    static let white = Color(hex: "#FFFFFF")
    
    // Grayscale spectrum
    static let gray900 = Color(hex: "#1A1A1A")  // Near-black text
    static let gray700 = Color(hex: "#4A4A4A")  // Secondary text
    static let gray500 = Color(hex: "#737373")  // Metadata
    static let gray300 = Color(hex: "#B3B3B3")  // Dividers
    static let gray150 = Color(hex: "#E0E0E0")  // Subtle surfaces
    static let gray050 = Color(hex: "#F5F5F5")  // Background separation
    
    // Accent: Deep Red (RARE - max one per screen)
    // Meaning: Commitment · Importance · Finality
    // NOT: Error · Warning · Failure
    static let deepRed = Color(hex: "#8B0000")
    
    // Semantic aliases
    static var primaryBackground: Color { black }
    static var secondaryBackground: Color { gray900 }
    static var surface: Color { white }
    static var surfaceSecondary: Color { gray050 }
    
    static var textPrimary: Color { gray900 }
    static var textSecondary: Color { gray700 }
    static var textMeta: Color { gray500 }
    
    static var divider: Color { gray300 }
    static var subtleSurface: Color { gray150 }
    
    // Commitment action (use sparingly)
    static var commit: Color { deepRed }
}

// MARK: - Typography System

/// Bron's typographic hierarchy
/// Display: ALL CAPS, condensed, heavy (broadcast headlines)
/// Utility: Sentence case, calm, neutral (body/control)
struct BronTypography {
    
    // MARK: - Display Fonts (Impact / Broadcast)
    // Used for: Screen titles, Task titles, Status headers, Section labels
    
    static var displayXL: Font {
        .system(size: 44, weight: .black, design: .default)
    }
    
    static var displayL: Font {
        .system(size: 32, weight: .black, design: .default)
    }
    
    static var displayM: Font {
        .system(size: 20, weight: .heavy, design: .default)
    }
    
    static var displayS: Font {
        .system(size: 16, weight: .bold, design: .default)
    }
    
    // MARK: - Utility Fonts (Body / Control)
    // Used for: Chat messages, Descriptions, Forms, Metadata, Buttons
    
    static var bodyL: Font {
        .system(size: 17, weight: .regular, design: .default)
    }
    
    static var bodyM: Font {
        .system(size: 15, weight: .regular, design: .default)
    }
    
    static var bodyS: Font {
        .system(size: 13, weight: .regular, design: .default)
    }
    
    static var meta: Font {
        .system(size: 12, weight: .medium, design: .default)
    }
    
    static var button: Font {
        .system(size: 15, weight: .semibold, design: .default)
    }
}

// MARK: - Layout Constants

struct BronLayout {
    // Spacing scale
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    
    // Corner radius (minimal - editorial feel)
    static let cornerRadiusS: CGFloat = 4
    static let cornerRadiusM: CGFloat = 8
    static let cornerRadiusL: CGFloat = 12
    
    // Divider weight
    static let dividerThick: CGFloat = 2
    static let dividerThin: CGFloat = 1
    static let dividerHairline: CGFloat = 0.5
    
    // Rule/accent line
    static let ruleWeight: CGFloat = 3
}

// MARK: - View Modifiers

/// Display text style (ALL CAPS, tight tracking)
struct DisplayTextStyle: ViewModifier {
    let font: Font
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .textCase(.uppercase)
            .tracking(1.5)
    }
}

/// Utility text style (sentence case, neutral)
struct UtilityTextStyle: ViewModifier {
    let font: Font
    
    func body(content: Content) -> some View {
        content
            .font(font)
    }
}

extension View {
    func displayStyle(_ size: DisplaySize = .medium) -> some View {
        let font: Font = {
            switch size {
            case .xl: return BronTypography.displayXL
            case .large: return BronTypography.displayL
            case .medium: return BronTypography.displayM
            case .small: return BronTypography.displayS
            }
        }()
        return modifier(DisplayTextStyle(font: font))
    }
    
    func utilityStyle(_ size: UtilitySize = .medium) -> some View {
        let font: Font = {
            switch size {
            case .large: return BronTypography.bodyL
            case .medium: return BronTypography.bodyM
            case .small: return BronTypography.bodyS
            case .meta: return BronTypography.meta
            }
        }()
        return modifier(UtilityTextStyle(font: font))
    }
}

enum DisplaySize {
    case xl, large, medium, small
}

enum UtilitySize {
    case large, medium, small, meta
}

// MARK: - Component Styles

/// Strong horizontal divider (broadcast rundown style)
struct BronDivider: View {
    var weight: CGFloat = BronLayout.dividerThin
    var color: Color = BronColors.divider
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
    }
}

/// Deep red accent rule (left edge or underline)
struct CommitRule: View {
    var orientation: Axis = .vertical
    var length: CGFloat? = nil
    
    var body: some View {
        Rectangle()
            .fill(BronColors.commit)
            .frame(
                width: orientation == .vertical ? BronLayout.ruleWeight : length,
                height: orientation == .horizontal ? BronLayout.ruleWeight : length
            )
    }
}

/// Section header with strong typography
struct SectionHeader: View {
    let title: String
    var showRule: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: BronLayout.spacingS) {
            Text(title)
                .displayStyle(.medium)
                .foregroundStyle(BronColors.textPrimary)
            
            if showRule {
                BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
            }
        }
    }
}

// MARK: - Button Styles

/// Primary commit button (deep red outline - use sparingly)
struct CommitButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BronTypography.button)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(isEnabled ? BronColors.commit : BronColors.gray500)
            .padding(.horizontal, BronLayout.spacingL)
            .padding(.vertical, BronLayout.spacingM)
            .background(
                RoundedRectangle(cornerRadius: BronLayout.cornerRadiusS)
                    .strokeBorder(
                        isEnabled ? BronColors.commit : BronColors.gray300,
                        lineWidth: 2
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// Secondary button (grayscale)
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BronTypography.button)
            .foregroundStyle(BronColors.textSecondary)
            .padding(.horizontal, BronLayout.spacingL)
            .padding(.vertical, BronLayout.spacingM)
            .background(
                RoundedRectangle(cornerRadius: BronLayout.cornerRadiusS)
                    .fill(BronColors.gray050)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// Minimal button (text only)
struct MinimalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BronTypography.button)
            .foregroundStyle(BronColors.textSecondary)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// MARK: - Status Indicator

/// Task status display (broadcast style)
struct BronStatusBadge: View {
    let status: String
    var showDot: Bool = true
    
    private var isActive: Bool {
        ["executing", "working"].contains(status.lowercased())
    }
    
    var body: some View {
        HStack(spacing: BronLayout.spacingS) {
            if showDot {
                Circle()
                    .fill(isActive ? BronColors.black : BronColors.gray500)
                    .frame(width: 8, height: 8)
            }
            
            Text(status.uppercased())
                .font(BronTypography.meta)
                .tracking(1)
                .foregroundStyle(BronColors.textSecondary)
        }
    }
}

// MARK: - Color Extension (for hex support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview("Typography") {
    VStack(alignment: .leading, spacing: 20) {
        Text("ACTIVE BRONS")
            .displayStyle(.xl)
        
        Text("SUBMIT RECEIPT")
            .displayStyle(.large)
        
        Text("NEEDS INFO")
            .displayStyle(.medium)
        
        Text("STATUS")
            .displayStyle(.small)
        
        Divider()
        
        Text("This is body text for chat messages and descriptions.")
            .utilityStyle(.large)
        
        Text("Metadata and timestamps")
            .utilityStyle(.meta)
            .foregroundStyle(BronColors.textMeta)
    }
    .padding()
}

#Preview("Buttons") {
    VStack(spacing: 20) {
        Button("Execute Task") {}
            .buttonStyle(CommitButtonStyle())
        
        Button("Skip for Now") {}
            .buttonStyle(SecondaryButtonStyle())
        
        Button("Cancel") {}
            .buttonStyle(MinimalButtonStyle())
    }
    .padding()
}

#Preview("Components") {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeader(title: "Active Brons")
        
        BronStatusBadge(status: "executing")
        BronStatusBadge(status: "needs info")
        BronStatusBadge(status: "ready")
        
        HStack(spacing: 0) {
            CommitRule(orientation: .vertical, length: 60)
            VStack(alignment: .leading) {
                Text("SUBMIT RECEIPT")
                    .displayStyle(.medium)
                Text("Step 2/5")
                    .utilityStyle(.meta)
                    .foregroundStyle(BronColors.textMeta)
            }
            .padding(.leading)
        }
    }
    .padding()
}

