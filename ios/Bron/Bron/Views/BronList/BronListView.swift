//
//  BronListView.swift
//  Bron
//
//  Active Roster - Championship broadcast style
//

import SwiftUI

/// Filter for Bron list display
enum BronFilter: String, CaseIterable {
    case active = "Active"
    case completed = "Completed"
}

struct BronListView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedBronId: UUID?
    @State private var isCreating = false
    @State private var filter: BronFilter = .active
    
    private var allBrons: [BronInstance] {
        appState.bronRepository.brons
    }
    
    /// Filtered and sorted Brons
    private var brons: [BronInstance] {
        let filtered = allBrons.filter { bron in
            switch filter {
            case .active:
                return bron.status.isActive || bron.status == .idle
            case .completed:
                return bron.status == .completed
            }
        }
        
        // Sort by urgency: needsInfo first, then working, then by updated date
        return filtered.sorted { a, b in
            let urgencyA = urgencyScore(a.status)
            let urgencyB = urgencyScore(b.status)
            if urgencyA != urgencyB {
                return urgencyA > urgencyB
            }
            return a.updatedAt > b.updatedAt
        }
    }
    
    private var isLoading: Bool {
        appState.bronRepository.isLoading
    }
    
    private var completedCount: Int {
        allBrons.filter { $0.status == .completed }.count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BronColors.surface
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter tabs (only show if there are completed Brons)
                    if completedCount > 0 {
                        filterTabs
                    }
                    
                    if brons.isEmpty && !isLoading {
                        emptyState
                    } else {
                        bronList
                    }
                }
                
                // Loading overlay
                if isLoading && allBrons.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(filter == .active ? "ACTIVE BRONS" : "COMPLETED")
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
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(BronFilter.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        filter = tab
                    }
                } label: {
                    VStack(spacing: BronLayout.spacingXS) {
                        HStack(spacing: BronLayout.spacingXS) {
                            Text(tab.rawValue.uppercased())
                                .font(BronTypography.meta)
                                .tracking(1)
                            
                            if tab == .completed {
                                Text("\(completedCount)")
                                    .font(BronTypography.meta)
                                    .foregroundStyle(BronColors.textMeta)
                            }
                        }
                        .foregroundStyle(filter == tab ? BronColors.textPrimary : BronColors.textMeta)
                        
                        // Underline indicator
                        Rectangle()
                            .fill(filter == tab ? BronColors.black : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BronLayout.spacingS)
                }
            }
        }
        .padding(.horizontal, BronLayout.spacingM)
        .background(BronColors.surface)
    }
    
    /// Urgency score for sorting (higher = more urgent)
    private func urgencyScore(_ status: BronStatus) -> Int {
        switch status {
        case .needsInfo: return 100  // Needs user action
        case .ready: return 80       // Ready to execute
        case .working: return 60     // Actively working
        case .waiting: return 40     // Waiting on something
        case .idle: return 20        // Not doing anything
        case .completed: return 0    // Done
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: BronLayout.spacingXL) {
            BronAvatar(size: .hero, state: filter == .completed ? .success : .idle)
            
            VStack(spacing: BronLayout.spacingM) {
                Text(filter == .active ? "NO ACTIVE BRONS" : "NO COMPLETED BRONS")
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text(filter == .active 
                    ? "Tap + to create your first Bron." 
                    : "Completed tasks will appear here.")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BronLayout.spacingXL)
            }
            
            if filter == .active {
                Button("CREATE BRON") {
                    Task { @MainActor in
                        await createAndNavigate()
                    }
                }
                .buttonStyle(CommitButtonStyle())
                .disabled(isCreating)
            }
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
