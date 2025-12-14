//
//  UIStyleResolver.swift
//  Bron
//
//  Resolves UIStyle to SwiftUI values
//

import SwiftUI

/// Resolves UIStyle presets and custom values to SwiftUI styling
struct UIStyleResolver {
    let style: UIStyle?
    
    // MARK: - Colors
    
    var primaryColor: Color {
        if let hex = style?.primaryColor {
            return Color(hex: hex)
        }
        return presetColors.primary
    }
    
    var secondaryColor: Color {
        if let hex = style?.secondaryColor {
            return Color(hex: hex)
        }
        return presetColors.secondary
    }
    
    var backgroundColor: Color {
        if let hex = style?.backgroundColor {
            return Color(hex: hex)
        }
        return presetColors.background
    }
    
    var textColor: Color {
        if let hex = style?.textColor {
            return Color(hex: hex)
        }
        return presetColors.text
    }
    
    var accentColor: Color {
        if let hex = style?.accentColor {
            return Color(hex: hex)
        }
        return presetColors.accent
    }
    
    // MARK: - Typography
    
    var font: Font {
        let size: Font = {
            switch style?.fontSize {
            case .small: return .subheadline
            case .large: return .title3
            default: return .body
            }
        }()
        
        switch style?.fontWeight {
        case .light: return size.weight(.light)
        case .medium: return size.weight(.medium)
        case .semibold: return size.weight(.semibold)
        case .bold: return size.weight(.bold)
        default: return size.weight(.regular)
        }
    }
    
    var headlineFont: Font {
        switch style?.fontWeight {
        case .light: return .headline.weight(.medium)
        case .bold: return .headline.weight(.bold)
        default: return .headline
        }
    }
    
    // MARK: - Layout
    
    var cornerRadius: CGFloat {
        switch style?.cornerRadius {
        case .none: return 0
        case .small: return 6
        case .large: return 16
        case .full: return 100
        default: return 12
        }
    }
    
    var padding: CGFloat {
        switch style?.padding {
        case .compact: return 8
        case .spacious: return 20
        default: return 14
        }
    }
    
    var borderWidth: CGFloat {
        switch style?.borderStyle {
        case .none: return 0
        case .subtle: return 0.5
        case .prominent: return 2
        default: return 1
        }
    }
    
    var borderColor: Color {
        switch style?.borderStyle {
        case .none: return .clear
        case .subtle: return primaryColor.opacity(0.2)
        case .prominent: return primaryColor
        default: return primaryColor.opacity(0.3)
        }
    }
    
    // MARK: - Effects
    
    var shadowRadius: CGFloat {
        switch style?.shadow {
        case .none: return 0
        case .subtle: return 2
        case .medium: return 6
        case .prominent: return 12
        default: return 0
        }
    }
    
    var blurBackground: Bool {
        style?.blurBackground ?? false
    }
    
    // MARK: - Brand Icon
    
    var iconName: String? {
        if let icon = style?.iconName {
            return icon
        }
        return presetIcon
    }
    
    // MARK: - Preset Resolution
    
    private var presetColors: (primary: Color, secondary: Color, background: Color, text: Color, accent: Color) {
        switch style?.preset {
        case .google:
            return (
                primary: Color(hex: "#4285F4"),
                secondary: Color(hex: "#34A853"),
                background: .white,
                text: Color(hex: "#202124"),
                accent: Color(hex: "#EA4335")
            )
        case .apple:
            return (
                primary: .primary,
                secondary: .secondary,
                background: Color(.systemBackground),
                text: .primary,
                accent: .primary
            )
        case .microsoft:
            return (
                primary: Color(hex: "#0078D4"),
                secondary: Color(hex: "#50E6FF"),
                background: .white,
                text: Color(hex: "#323130"),
                accent: Color(hex: "#FFB900")
            )
        case .github:
            return (
                primary: Color(hex: "#24292F"),
                secondary: Color(hex: "#57606A"),
                background: .white,
                text: Color(hex: "#24292F"),
                accent: Color(hex: "#2DA44E")
            )
        case .slack:
            return (
                primary: Color(hex: "#4A154B"),
                secondary: Color(hex: "#36C5F0"),
                background: .white,
                text: Color(hex: "#1D1C1D"),
                accent: Color(hex: "#2EB67D")
            )
        case .notion:
            return (
                primary: .primary,
                secondary: .secondary,
                background: Color(hex: "#FFFFFF"),
                text: Color(hex: "#37352F"),
                accent: Color(hex: "#EB5757")
            )
        case .spotify:
            return (
                primary: Color(hex: "#1DB954"),
                secondary: Color(hex: "#191414"),
                background: Color(hex: "#191414"),
                text: .white,
                accent: Color(hex: "#1DB954")
            )
        case .urgent:
            return (
                primary: Color(hex: "#DC2626"),
                secondary: Color(hex: "#FEE2E2"),
                background: Color(hex: "#FEF2F2"),
                text: Color(hex: "#991B1B"),
                accent: Color(hex: "#DC2626")
            )
        case .success:
            return (
                primary: Color(hex: "#16A34A"),
                secondary: Color(hex: "#DCFCE7"),
                background: Color(hex: "#F0FDF4"),
                text: Color(hex: "#166534"),
                accent: Color(hex: "#16A34A")
            )
        case .warning:
            return (
                primary: Color(hex: "#D97706"),
                secondary: Color(hex: "#FEF3C7"),
                background: Color(hex: "#FFFBEB"),
                text: Color(hex: "#92400E"),
                accent: Color(hex: "#D97706")
            )
        case .error:
            return (
                primary: Color(hex: "#DC2626"),
                secondary: Color(hex: "#FEE2E2"),
                background: Color(hex: "#FEF2F2"),
                text: Color(hex: "#991B1B"),
                accent: Color(hex: "#DC2626")
            )
        case .email:
            return (
                primary: Color(hex: "#3B82F6"),
                secondary: .secondary,
                background: Color(.systemGray6),
                text: .primary,
                accent: Color(hex: "#3B82F6")
            )
        case .calendar:
            return (
                primary: Color(hex: "#EF4444"),
                secondary: Color(hex: "#FCA5A5"),
                background: .white,
                text: .primary,
                accent: Color(hex: "#EF4444")
            )
        case .weather:
            return (
                primary: Color(hex: "#0EA5E9"),
                secondary: Color(hex: "#7DD3FC"),
                background: Color(hex: "#F0F9FF"),
                text: Color(hex: "#0C4A6E"),
                accent: Color(hex: "#F59E0B")
            )
        case .financial:
            return (
                primary: Color(hex: "#059669"),
                secondary: Color(hex: "#34D399"),
                background: .white,
                text: .primary,
                accent: Color(hex: "#059669")
            )
        case .health:
            return (
                primary: Color(hex: "#EC4899"),
                secondary: Color(hex: "#F9A8D4"),
                background: Color(hex: "#FDF2F8"),
                text: .primary,
                accent: Color(hex: "#EC4899")
            )
        case .professional:
            return (
                primary: Color(hex: "#1E3A5F"),
                secondary: Color(hex: "#64748B"),
                background: Color(hex: "#F8FAFC"),
                text: Color(hex: "#0F172A"),
                accent: Color(hex: "#3B82F6")
            )
        case .casual:
            return (
                primary: Color(hex: "#8B5CF6"),
                secondary: Color(hex: "#C4B5FD"),
                background: Color(hex: "#F5F3FF"),
                text: .primary,
                accent: Color(hex: "#8B5CF6")
            )
        case .minimal:
            return (
                primary: .primary,
                secondary: .secondary,
                background: Color(.systemBackground),
                text: .primary,
                accent: .accentColor
            )
        default:
            return (
                primary: .accentColor,
                secondary: .secondary,
                background: Color(.systemGray6),
                text: .primary,
                accent: .accentColor
            )
        }
    }
    
    private var presetIcon: String? {
        switch style?.preset {
        case .google: return "g.circle.fill"
        case .apple: return "apple.logo"
        case .microsoft: return "square.grid.2x2.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .slack: return "number.square.fill"
        case .spotify: return "music.note"
        case .email: return "envelope.fill"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .financial: return "dollarsign.circle.fill"
        case .health: return "heart.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .error: return "xmark.circle.fill"
        default: return nil
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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

// MARK: - View Modifier

struct UIStyleModifier: ViewModifier {
    let resolver: UIStyleResolver
    
    func body(content: Content) -> some View {
        content
            .font(resolver.font)
            .foregroundStyle(resolver.textColor)
            .padding(resolver.padding)
            .background(resolver.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: resolver.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: resolver.cornerRadius)
                    .strokeBorder(resolver.borderColor, lineWidth: resolver.borderWidth)
            )
            .shadow(radius: resolver.shadowRadius)
    }
}

extension View {
    func styled(with style: UIStyle?) -> some View {
        modifier(UIStyleModifier(resolver: UIStyleResolver(style: style)))
    }
    
    func styled(preset: UIStylePreset) -> some View {
        modifier(UIStyleModifier(resolver: UIStyleResolver(style: UIStyle(preset: preset))))
    }
}

