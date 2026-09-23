import Foundation
import SwiftUI
import Combine

/// App-wide configuration: server URL (persisted with @AppStorage) and the
/// iOS API key (persisted in the Keychain, never in UserDefaults or files).
final class AppConfig: ObservableObject {
    @AppStorage("serverBaseURL") var serverURLString: String = "http://"
    @Published var apiKey: String = ""
    @Published var keychainMessage: String?

    private let keychainService = "com.binayrai.OpsPaperTrade"
    private let keychainAccount = "ios-api-key"

    init() {
        apiKey = KeychainHelper.shared.read(service: keychainService, account: keychainAccount) ?? ""
    }

    var trimmedServerURL: String {
        serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Persist the API key (or clear it) in the Keychain.
    func saveAPIKey() {
        let key = trimmedAPIKey
        if key.isEmpty {
            KeychainHelper.shared.delete(service: keychainService, account: keychainAccount)
            keychainMessage = "API key cleared from Keychain."
        } else if KeychainHelper.shared.save(key, service: keychainService, account: keychainAccount) {
            keychainMessage = "API key saved to Keychain."
        } else {
            keychainMessage = "Could not save the API key."
        }
    }

    /// Build a client for the configured server. Throws APIError.invalidURL when
    /// the server URL is missing or malformed.
    func makeClient() throws -> APIClient {
        let raw = trimmedServerURL
        guard !raw.isEmpty, raw != "http://", raw != "https://",
              let url = URL(string: raw),
              (url.scheme == "http" || url.scheme == "https"),
              url.host != nil
        else {
            throw APIError.invalidURL
        }
        let key = trimmedAPIKey
        return APIClient(baseURL: url, apiKey: key.isEmpty ? nil : key)
    }

    /// Quick connectivity check used by Settings: hits /health and reports
    /// whether the bot is alive and in dry-run mode.
    func testConnection() async -> String {
        do {
            let client = try makeClient()
            let health = try await client.health()
            if health.isAlive {
                let mode = (health.dryRun ?? true) ? "DRY RUN" : "LIVE PAPER"
                return "Connected. Server is alive (\(mode) mode)."
            } else {
                return "Connected, but the server did not report status \"ok\"."
            }
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }
}