//
//  BronDetailView.swift
//  Bron
//
//  Chat-based interaction with a single Bron
//

import SwiftUI

struct BronDetailView: View {
    let bronId: UUID
    
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var isTaskDrawerOpen: Bool = false
    @FocusState private var isInputFocused: Bool
    
    init(bronId: UUID) {
        self.bronId = bronId
        _viewModel = StateObject(wrappedValue: ChatViewModel(bronId: bronId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Loading indicator
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Pending UI Recipe
            if let recipe = viewModel.pendingRecipe {
                PendingRecipeView(
                    recipe: recipe,
                    onSubmit: { data in
                        Task {
                            await viewModel.submitRecipe(data)
                        }
                    },
                    onDismiss: {
                        viewModel.dismissRecipe()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Error banner
            if let error = viewModel.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.error = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }
            
            Divider()
            
            // Composer
            MessageComposer(text: $inputText) {
                sendMessage()
            }
            .focused($isInputFocused)
            .disabled(viewModel.isLoading)
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
        .task {
            await viewModel.loadHistory()
        }
    }
    
    private func sendMessage() {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        inputText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(content)
        }
    }
}

// MARK: - Pending Recipe View

struct PendingRecipeView: View {
    let recipe: UIRecipe
    let onSubmit: ([String: String]) -> Void
    let onDismiss: () -> Void
    
    @State private var formData: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(recipe.title ?? "Information Needed")
                    .font(.headline)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Form fields (simplified - will be expanded in PR-04)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let description = recipe.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    ForEach(Array(recipe.schema.keys.sorted()), id: \.self) { key in
                        if let field = recipe.schema[key] {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(field.label ?? key.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField(
                                    field.placeholder ?? "",
                                    text: Binding(
                                        get: { formData[key] ?? "" },
                                        set: { formData[key] = $0 }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Submit button
            Button {
                onSubmit(formData)
            } label: {
                Text("Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
        .padding()
    }
    
    private var isFormValid: Bool {
        recipe.requiredFields.allSatisfy { field in
            let value = formData[field] ?? ""
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

#Preview {
    NavigationStack {
        BronDetailView(bronId: UUID())
    }
}
