//
//  StatusPill.swift
//  Bron
//
//  Status indicator pill component
//

import SwiftUI

struct StatusPill: View {
    let status: BronStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 8) {
        StatusPill(status: .working)
        StatusPill(status: .waiting)
        StatusPill(status: .needsInfo)
        StatusPill(status: .ready)
        StatusPill(status: .idle)
    }
    .padding()
}

