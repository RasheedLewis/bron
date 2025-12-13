//
//  BronListView.swift
//  Bron
//
//  Dashboard showing all active Brons
//

import SwiftUI

struct BronListView: View {
    @EnvironmentObject var appState: AppState
    @State private var brons: [BronInstance] = []
    
    var body: some View {
        NavigationStack {
            Group {
                if brons.isEmpty {
                    emptyState
                } else {
                    bronList
                }
            }
            .navigationTitle("Your Brons")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Create new Bron
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Brons Yet", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Create your first Bron to get started.")
        } actions: {
            Button("Create Bron") {
                // Create new Bron
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var bronList: some View {
        List(brons) { bron in
            NavigationLink(value: bron.id) {
                ActiveBronCard(bron: bron)
            }
        }
        .navigationDestination(for: UUID.self) { bronId in
            BronDetailView(bronId: bronId)
        }
    }
}

#Preview {
    BronListView()
        .environmentObject(AppState())
}

