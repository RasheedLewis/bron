//
//  StatusPill.swift
//  Bron
//
//  Status indicator - broadcast style
//  Replaced by BronStatusBadge in theme, kept for compatibility
//

import SwiftUI

struct StatusPill: View {
    let status: BronStatus
    
    var body: some View {
        BronStatusBadge(status: status.displayName, showDot: true)
    }
}

#Preview {
    VStack(spacing: BronLayout.spacingM) {
        StatusPill(status: .working)
        StatusPill(status: .waiting)
        StatusPill(status: .needsInfo)
        StatusPill(status: .ready)
        StatusPill(status: .idle)
    }
    .padding()
}
