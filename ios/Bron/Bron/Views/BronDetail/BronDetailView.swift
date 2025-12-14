//
//  BronDetailView.swift
//  Bron
//
//  Chat Workspace - championship broadcast style
//  Calm, neutral, feels like notes between teammates
//

import SwiftUI

struct BronDetailView: View {
    let bronId: UUID
    
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var isTaskDrawerOpen: Bool = false
    @FocusState private var isInputFocused: Bool
    
    init(bronId: UUID) {
        self.bronId = bronId
        _viewModel = StateObject(wrappedValue: ChatViewModel(bronId: bronId))
    }
    
    private var currentTaskState: String? {
        viewModel.messages.last?.taskStateUpdate
    }
    
    private var suggestions: [Suggestion] {
        Suggestion.contextual(for: currentTaskState)
    }
    
    private var avatarState: AvatarState {
        AvatarState.from(taskState: currentTaskState)
    }
    
    var body: some View {
        ZStack {
            BronColors.surface
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages
                messagesView
                
                // Error banner
                errorBanner
                
                // Composer
                MessageComposer(
                    text: $inputText,
                    onSend: sendMessage,
                    suggestions: inputText.isEmpty ? suggestions : nil,
                    onSuggestionTap: { suggestion in
                        inputText = suggestion.text
                        sendMessage()
                    },
                    isLoading: viewModel.isLoading,
                    placeholder: "Message \(bronName)..."
                )
                .focused($isInputFocused)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: BronLayout.spacingS) {
                    BronAvatar(size: .small, state: avatarState, isAnimated: false)
                    
                    Text(bronName.uppercased())
                        .displayStyle(.small)
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isTaskDrawerOpen.toggle()
                } label: {
                    Image(systemName: "square.split.2x1")
                        .foregroundStyle(BronColors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $isTaskDrawerOpen) {
            TaskDrawer(bronId: bronId)
                .environmentObject(appState)
        }
        .task {
            await viewModel.loadHistory()
        }
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: BronLayout.spacingL) {
                    // Welcome message
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        welcomeView
                    }
                    
                    // Messages
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            onRecipeAction: handleRecipeAction,
                            onRecipeSubmit: handleRecipeSubmit
                        )
                        .id(message.id)
                    }
                    
                    // Typing indicator
                    if viewModel.isLoading {
                        typingIndicator
                            .id("typing")
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(BronLayout.spacingM)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        VStack(spacing: BronLayout.spacingXL) {
            Spacer()
                .frame(height: 40)
            
            BronAvatar(size: .hero, state: .idle)
            
            VStack(spacing: BronLayout.spacingM) {
                Text(bronName.uppercased())
                    .displayStyle(.large)
                    .foregroundStyle(BronColors.textPrimary)
                
                Text("What do you need done?")
                    .utilityStyle(.medium)
                    .foregroundStyle(BronColors.textSecondary)
            }
            
            // Quick start
            VStack(spacing: BronLayout.spacingS) {
                ForEach(quickStartSuggestions, id: \.self) { suggestion in
                    Button {
                        inputText = suggestion
                    } label: {
                        Text(suggestion)
                            .utilityStyle(.medium)
                            .foregroundStyle(BronColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(BronLayout.spacingM)
                            .background(BronColors.gray050)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(BronColors.gray300, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BronLayout.spacingXL)
            
            Spacer()
        }
    }
    
    private var quickStartSuggestions: [String] {
        [
            "Submit my expense receipt",
            "Plan my study schedule",
            "Draft an email",
        ]
    }
    
    // MARK: - Typing Indicator
    
    private var typingIndicator: some View {
        HStack(spacing: BronLayout.spacingM) {
            BronAvatar(size: .small, state: .thinking, isAnimated: true)
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(BronColors.gray500)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, BronLayout.spacingM)
            .padding(.vertical, BronLayout.spacingS)
            .background(BronColors.gray050)
            
            Spacer()
        }
    }
    
    // MARK: - Error Banner
    
    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.error {
            HStack(spacing: BronLayout.spacingS) {
                Text(error)
                    .utilityStyle(.small)
                    .foregroundStyle(BronColors.textSecondary)
                
                Spacer()
                
                Button {
                    viewModel.error = nil
                } label: {
                    Text("DISMISS")
                        .font(BronTypography.meta)
                        .foregroundStyle(BronColors.textMeta)
                }
            }
            .padding(BronLayout.spacingM)
            .background(BronColors.gray050)
            .overlay(
                Rectangle()
                    .strokeBorder(BronColors.gray300, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helpers
    
    private var bronName: String {
        appState.bronRepository.brons.first { $0.id == bronId }?.name ?? "Bron"
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
    
    private func handleRecipeAction(_ action: String) {
        print("Recipe action: \(action)")
    }
    
    private func handleRecipeSubmit(_ data: [String: String]) {
        Task {
            await viewModel.submitRecipe(data)
        }
    }
}

#Preview {
    NavigationStack {
        BronDetailView(bronId: UUID())
            .environmentObject(AppState(persistenceController: .preview))
    }
}
