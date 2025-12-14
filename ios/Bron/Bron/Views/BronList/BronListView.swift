//
//  BronListView.swift
//  Bron
//
//  Dashboard showing all active Brons
//

import SwiftUI

struct BronListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingCreateSheet = false
    @State private var newBronName = ""
    
    private var brons: [BronInstance] {
        appState.bronRepository.brons
    }
    
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
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                createBronSheet
            }
            .refreshable {
                appState.bronRepository.fetchAll()
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
                showingCreateSheet = true
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
    
    private var createBronSheet: some View {
        NavigationStack {
            Form {
                Section("New Bron") {
                    TextField("Name", text: $newBronName)
                }
            }
            .navigationTitle("Create Bron")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newBronName = ""
                        showingCreateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = newBronName.isEmpty ? "New Bron" : newBronName
                        _ = appState.createBron(name: name)
                        newBronName = ""
                        showingCreateSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    BronListView()
        .environmentObject(AppState(persistenceController: .preview))
}

