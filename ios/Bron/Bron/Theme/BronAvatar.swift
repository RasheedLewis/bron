//
//  BronAvatar.swift
//  Bron
//
//  The ONLY expressive color surface in the UI
//  Carries warmth and life while UI stays sharp and silent
//

import SwiftUI

/// Bron avatar - the only colored element in the championship broadcast UI
/// Reflects task state through subtle expression, not emotion
struct BronAvatar: View {
    var size: AvatarSize = .medium
    var state: AvatarState = .idle
    var isAnimated: Bool = true
    
    @State private var glowPhase: CGFloat = 0
    
    private var diameter: CGFloat {
        switch size {
        case .small: return 32
        case .medium: return 48
        case .large: return 80
        case .hero: return 120
        }
    }
    
    private var iconSize: CGFloat {
        diameter * 0.45
    }
    
    var body: some View {
        ZStack {
            // Glow layer (subtle, state-based)
            if isAnimated && state.hasGlow {
                glowLayer
            }
            
            // Main avatar circle
            Circle()
                .fill(avatarGradient)
                .frame(width: diameter, height: diameter)
            
            // Icon
            Image(systemName: state.iconName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            if isAnimated {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPhase = 1
                }
            }
        }
    }
    
    // MARK: - Glow Layer
    
    private var glowLayer: some View {
        Circle()
            .fill(state.glowColor.opacity(0.3))
            .frame(width: diameter * 1.3, height: diameter * 1.3)
            .blur(radius: 10)
            .opacity(0.5 + glowPhase * 0.3)
    }
    
    // MARK: - Gradient
    
    private var avatarGradient: LinearGradient {
        LinearGradient(
            colors: state.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Avatar Size

enum AvatarSize {
    case small   // 32pt - inline with text
    case medium  // 48pt - list items
    case large   // 80pt - detail headers
    case hero    // 120pt - welcome screens
}

// MARK: - Avatar State

enum AvatarState {
    case idle
    case working
    case thinking
    case ready
    case needsInfo
    case success
    case waiting
    
    var iconName: String {
        switch self {
        case .idle: return "brain.head.profile"
        case .working: return "gearshape.2"
        case .thinking: return "ellipsis"
        case .ready: return "checkmark"
        case .needsInfo: return "questionmark"
        case .success: return "hand.thumbsup"
        case .waiting: return "clock"
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .idle:
            return [Color(hex: "#2C3E50"), Color(hex: "#34495E")]
        case .working:
            return [Color(hex: "#1E3A5F"), Color(hex: "#2980B9")]
        case .thinking:
            return [Color(hex: "#2C3E50"), Color(hex: "#3498DB")]
        case .ready:
            return [Color(hex: "#1D4E3E"), Color(hex: "#27AE60")]
        case .needsInfo:
            return [Color(hex: "#4A235A"), Color(hex: "#8E44AD")]
        case .success:
            return [Color(hex: "#145A32"), Color(hex: "#2ECC71")]
        case .waiting:
            return [Color(hex: "#7E5109"), Color(hex: "#F39C12")]
        }
    }
    
    var glowColor: Color {
        gradientColors.last ?? .blue
    }
    
    var hasGlow: Bool {
        switch self {
        case .working, .thinking, .ready: return true
        default: return false
        }
    }
    
    /// Convert from task state string
    static func from(taskState: String?) -> AvatarState {
        guard let state = taskState?.lowercased() else { return .idle }
        
        switch state {
        case "draft": return .idle
        case "needs_info": return .needsInfo
        case "planned": return .thinking
        case "ready": return .ready
        case "executing": return .working
        case "waiting": return .waiting
        case "done": return .success
        case "failed": return .idle
        default: return .idle
        }
    }
}

// MARK: - Static Avatar (no animation)

struct BronAvatarStatic: View {
    var size: AvatarSize = .medium
    var initial: String = "B"
    
    private var diameter: CGFloat {
        switch size {
        case .small: return 32
        case .medium: return 48
        case .large: return 80
        case .hero: return 120
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#2C3E50"), Color(hex: "#34495E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter, height: diameter)
            
            Text(initial.prefix(1).uppercased())
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - User Avatar (grayscale)

struct UserAvatar: View {
    var size: AvatarSize = .small
    
    private var diameter: CGFloat {
        switch size {
        case .small: return 32
        case .medium: return 48
        case .large: return 80
        case .hero: return 120
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(BronColors.gray150)
                .frame(width: diameter, height: diameter)
            
            Image(systemName: "person.fill")
                .font(.system(size: diameter * 0.4, weight: .medium))
                .foregroundStyle(BronColors.gray500)
        }
    }
}

// MARK: - Previews

#Preview("Avatar States") {
    HStack(spacing: 20) {
        VStack {
            BronAvatar(size: .medium, state: .idle)
            Text("Idle").font(.caption)
        }
        VStack {
            BronAvatar(size: .medium, state: .working)
            Text("Working").font(.caption)
        }
        VStack {
            BronAvatar(size: .medium, state: .ready)
            Text("Ready").font(.caption)
        }
        VStack {
            BronAvatar(size: .medium, state: .needsInfo)
            Text("Needs Info").font(.caption)
        }
    }
    .padding()
}

#Preview("Avatar Sizes") {
    HStack(spacing: 20) {
        BronAvatar(size: .small, state: .working)
        BronAvatar(size: .medium, state: .working)
        BronAvatar(size: .large, state: .working)
    }
    .padding()
}

#Preview("Hero Avatar") {
    BronAvatar(size: .hero, state: .idle)
        .padding()
}

