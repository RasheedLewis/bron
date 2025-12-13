//
//  AppState.swift
//  Bron
//
//  Global application state
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedBronId: UUID?
    @Published var isLoading: Bool = false
    
    init() {
        // Initialize app state
    }
}

