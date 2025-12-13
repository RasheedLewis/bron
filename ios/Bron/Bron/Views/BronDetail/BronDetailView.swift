//
//  BronDetailView.swift
//  Bron
//
//  Chat-based interaction with a single Bron
//

import SwiftUI

struct BronDetailView: View {
    let bronId: UUID
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTaskDrawerOpen: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Composer
            MessageComposer(text: $inputText) {
                sendMessage()
            }
        }
        .navigationTitle("Bron")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isTaskDrawerOpen.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
            }
        }
        .sheet(isPresented: $isTaskDrawerOpen) {
            TaskDrawer(bronId: bronId)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = ChatMessage(
            id: UUID(),
            bronId: bronId,
            role: .user,
            content: inputText,
            createdAt: Date()
        )
        messages.append(message)
        inputText = ""
        
        // TODO: Send to server and get response
    }
}

#Preview {
    NavigationStack {
        BronDetailView(bronId: UUID())
    }
}

