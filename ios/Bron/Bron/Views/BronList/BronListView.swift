//
//  BronListView.swift
//  Bron
//
//  Active Roster - Championship broadcast style
//

import SwiftUI

struct BronListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedBronId: UUID?
    @State private var isCreating = false
    
    private var brons: [BronInstance] {
        appState.bronRepository.brons
    }
    
    private var isLoading: Bool {
        appState.bronRepository.isLoading
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BronColors.surface
                    .ignoresSafeArea()
                
                if brons.isEmpty && !isLoading {
                    emptyState
                } else {
                    bronList
                }
                
                // Loading overlay
                if isLoading && brons.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ACTIVE BRONS")
                        .displayStyle(.medium)
                        .foregroundStyle(BronColors.textPrimary)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        print("📱 Plus button tapped")
                        Task {
                            await createAndNavigate()
                        }
                    } label: {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus")
                                .foregroundStyle(BronColors.textPrimary)
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isCreating)
                }
            }
            .refreshable {
                await appState.syncWithServer()
            }
            .task {
                await appState.syncWithServer()
            }
            .navigationDestination(for: UUID.self) { bronId in
                BronDetailView(bronId: bronId)
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedBronId != nil },
                set: { if !$0 { selectedBronId = nil } }
            )) {
                if let bronId = selectedBronId {
                    BronDetailView(bronId: bronId)
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BronLayout.spacingXL) {
            BronAvatar(size: .hero, state: .idle)
            
            VStack(spacing: BronLayout.spacingM) {
                Text("NO ACTIVE BRONS")
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("Tap + to create your first Bron.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BronLayout.spacingXL)
            }
            
            Button("CREATE BRON") {
                Task { @MainActor in
                    await createAndNavigate()
                }
            }
            .buttonStyle(CommitButtonStyle())
            .disabled(isCreating)
        }
    }
    
    // MARK: - Bron List
    
    private var bronList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header rule
                BronDivider(weight: BronLayout.dividerThick, color: BronColors.black)
                    .padding(.horizontal)
                
                ForEach(brons) { bron in
                    NavigationLink(value: bron.id) {
                        ActiveBronCard(bron: bron)
                    }
                    .buttonStyle(.plain)
                    
                    BronDivider()
                        .padding(.horizontal)
                }
            }
            .padding(.top, BronLayout.spacingM)
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    private func createAndNavigate() async {
        guard !isCreating else { return }
        print("🚀 Creating new Bron...")
        isCreating = true
        
        if let bron = await appState.createBron(name: "New Bron") {
            print("✅ Bron created: \(bron.id), navigating...")
            selectedBronId = bron.id
        } else {
            print("❌ Failed to create Bron")
        }
        
        isCreating = false
    }
}

#Preview {
    BronListView()
        .environmentObject(AppState(persistenceController: .preview))
}
