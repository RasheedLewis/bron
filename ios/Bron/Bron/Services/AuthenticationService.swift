//
//  AuthenticationService.swift
//  Bron
//
//  Handles OAuth authentication flows using ASWebAuthenticationSession
//

import Foundation
import AuthenticationServices

/// Service for handling OAuth authentication flows
@MainActor
class AuthenticationService: NSObject, ObservableObject {
    
    static let shared = AuthenticationService()
    
    @Published var isAuthenticating = false
    @Published var lastError: String?
    
    private var currentSession: ASWebAuthenticationSession?
    private var presentationAnchor: ASPresentationAnchor?
    
    // MARK: - OAuth Configuration
    
    private let baseURL = "http://localhost:8000/api/v1"
    
    /// Custom URL scheme for OAuth callbacks
    private let callbackScheme = "bron"
    
    // MARK: - Public API
    
    /// Start OAuth flow for a provider
    /// - Parameters:
    ///   - provider: OAuth provider (google, apple)
    ///   - bronId: ID of the Bron requesting auth
    ///   - scopes: Optional specific scopes to request
    /// - Returns: Result with success message or error
    func startOAuth(
        provider: String,
        bronId: String,
        scopes: [String]? = nil
    ) async throws -> OAuthResult {
        isAuthenticating = true
        lastError = nil
        
        defer { isAuthenticating = false }
        
        // Step 1: Get auth URL from server
        let startResponse = try await requestAuthURL(
            provider: provider,
            bronId: bronId,
            scopes: scopes
        )
        
        // Step 2: Open ASWebAuthenticationSession
        let callbackURL = try await openAuthSession(
            url: URL(string: startResponse.authUrl)!,
            callbackScheme: callbackScheme
        )
        
        // Step 3: Extract code from callback URL
        guard let code = extractCode(from: callbackURL) else {
            throw OAuthError.invalidCallback("No authorization code in callback")
        }
        
        // Step 4: Exchange code for token via server
        let tokenResponse = try await exchangeCode(
            provider: provider,
            code: code,
            state: startResponse.state
        )
        
        return OAuthResult(
            success: tokenResponse.success,
            provider: provider,
            message: tokenResponse.message
        )
    }
    
    /// Check if authenticated with a provider
    func checkAuthStatus(provider: String, bronId: String) async throws -> AuthStatus {
        let url = URL(string: "\(baseURL)/oauth/check/\(provider)?bron_id=\(bronId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AuthStatusResponse.self, from: data)
        
        return AuthStatus(
            authenticated: response.authenticated,
            userEmail: response.userEmail,
            reason: response.reason
        )
    }
    
    // MARK: - Private Methods
    
    private func requestAuthURL(
        provider: String,
        bronId: String,
        scopes: [String]?
    ) async throws -> OAuthStartResponse {
        let url = URL(string: "\(baseURL)/oauth/start")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OAuthStartRequest(
            provider: provider,
            bronId: bronId,
            scopes: scopes
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw OAuthError.serverError(errorResponse.detail)
            }
            throw OAuthError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(OAuthStartResponse.self, from: data)
    }
    
    private func openAuthSession(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: OAuthError.authSessionError(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuthError.invalidCallback("No callback URL"))
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            
            self.currentSession = session
            
            if !session.start() {
                continuation.resume(throwing: OAuthError.authSessionError("Failed to start auth session"))
            }
        }
    }
    
    private func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        return queryItems.first(where: { $0.name == "code" })?.value
    }
    
    private func exchangeCode(
        provider: String,
        code: String,
        state: String
    ) async throws -> OAuthTokenResponse {
        let url = URL(string: "\(baseURL)/oauth/callback")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = OAuthTokenRequest(
            provider: provider,
            code: code,
            state: state
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw OAuthError.serverError(errorResponse.detail)
            }
            throw OAuthError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get the key window
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Models

struct OAuthStartRequest: Encodable {
    let provider: String
    let bronId: String
    let scopes: [String]?
    
    enum CodingKeys: String, CodingKey {
        case provider
        case bronId = "bron_id"
        case scopes
    }
}

struct OAuthStartResponse: Decodable {
    let authUrl: String
    let state: String
    
    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
        case state
    }
}

struct OAuthTokenRequest: Encodable {
    let provider: String
    let code: String
    let state: String
}

struct OAuthTokenResponse: Decodable {
    let success: Bool
    let provider: String
    let message: String
}

struct AuthStatusResponse: Decodable {
    let authenticated: Bool
    let userEmail: String?
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case authenticated
        case userEmail = "user_email"
        case reason
    }
}

struct ErrorResponse: Decodable {
    let detail: String
}

struct OAuthResult {
    let success: Bool
    let provider: String
    let message: String
}

struct AuthStatus {
    let authenticated: Bool
    let userEmail: String?
    let reason: String?
}

enum OAuthError: Error, LocalizedError {
    case cancelled
    case networkError(String)
    case serverError(String)
    case authSessionError(String)
    case invalidCallback(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Authentication was cancelled"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .authSessionError(let message):
            return "Auth session error: \(message)"
        case .invalidCallback(let message):
            return "Invalid callback: \(message)"
        }
    }
}

