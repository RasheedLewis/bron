//
//  BronService.swift
//  Bron
//
//  Service for Bron-related API operations
//

import Foundation

/// Service for managing Brons
actor BronService {
    static let shared = BronService()
    private let api = APIClient.shared
    
    private init() {}
    
    /// Fetch all Brons
    func fetchBrons() async throws -> [BronInstance] {
        struct Response: Decodable {
            let brons: [BronInstance]
            let total: Int
        }
        let response: Response = try await api.get("brons")
        return response.brons
    }
    
    /// Create a new Bron
    func createBron(name: String? = nil) async throws -> BronInstance {
        struct Request: Encodable {
            let name: String?
        }
        return try await api.post("brons", body: Request(name: name))
    }
    
    /// Fetch a specific Bron
    func fetchBron(id: UUID) async throws -> BronInstance {
        return try await api.get("brons/\(id.uuidString)")
    }
    
    /// Delete a Bron
    func deleteBron(id: UUID) async throws {
        try await api.delete("brons/\(id.uuidString)")
    }
}

