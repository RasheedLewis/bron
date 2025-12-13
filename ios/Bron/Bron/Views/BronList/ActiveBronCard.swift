//
//  ActiveBronCard.swift
//  Bron
//
//  Card component for displaying a Bron in the list
//

import SwiftUI

struct ActiveBronCard: View {
    let bron: BronInstance
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(bron.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.accent)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                // Name and status
                HStack {
                    Text(bron.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    StatusPill(status: bron.status)
                }
                
                // Current task
                if let task = bron.currentTask {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                // Last activity
                Text(bron.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ActiveBronCard(bron: .preview)
        .padding()
}

