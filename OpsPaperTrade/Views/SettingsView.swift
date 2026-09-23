import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var config: AppConfig

    @State private var testResult: String?
    @State private var isTesting = false
    @State private var health: HealthResponse?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.10:8000", text: $config.serverURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("iOS API key", text: $config.apiKey)
                        .textContentType(.password)
                    Button("Save API key to Keychain") {
                        config.saveAPIKey()
                    }
                    if let message = config.keychainMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("The API key is stored in the Keychain, never in plain text.")
                }

                Section("Connection") {
                    Button {
                        Task { await runTest() }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Text("Test connection")
                        }
                    }
                    .disabled(isTesting)
                    if let testResult {
                        Text(testResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let health {
                        HStack {
                            Circle()
                                .fill(health.isAlive ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(health.isAlive ? "Alive" : "Not reporting ok")
                                .font(.subheadline)
                            Spacer()
                            if health.dryRun == true {
                                Text("DRY RUN")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                Section("About") {
                    Text("Point the server URL at your Mac running the paper-trading bot (same Wi-Fi), e.g. http://192.168.1.10:8000.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("The Mac server must be started with --host 0.0.0.0 --port 8000, and IOS_API_KEY must be set in its .env for the trading tabs (Portfolio, Trade, Orders).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("With DRY_RUN=true (the default), orders are validated but never submitted to the broker.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: config.apiKey) { _, _ in
                config.keychainMessage = nil
            }
        }
    }

    private func runTest() async {
        isTesting = true
        defer { isTesting = false }
        testResult = nil
        health = nil
        do {
            let client = try config.makeClient()
            let result = try await client.health()
            health = result
            if result.isAlive {
                let mode = (result.dryRun ?? true) ? "DRY RUN" : "LIVE PAPER"
                testResult = "Connected. Server is alive (\(mode) mode)."
            } else {
                testResult = "Connected, but the server did not report status \"ok\"."
            }
        } catch {
            testResult = "Failed: \(error.localizedDescription)"
        }
    }
}
