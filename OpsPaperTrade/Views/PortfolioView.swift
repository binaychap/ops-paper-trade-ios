import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject private var config: AppConfig

    @State private var account: AccountResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let account {
                    Section("Account") {
                        if let number = account.accountNumber {
                            LabeledContent("Account", value: number)
                        }
                        if let currency = account.currency {
                            LabeledContent("Currency", value: currency)
                        }
                        LabeledContent("Total value", value: Formatters.moneyString(account.totalValue))
                        LabeledContent("Cash", value: Formatters.moneyString(account.cash))
                        LabeledContent("Buying power", value: Formatters.moneyString(account.buyingPower))
                        if let asOf = account.asOf {
                            LabeledContent("As of", value: Formatters.newYorkDateTimeString(asOf))
                        }
                    }
                    Section("Positions (\((account.positions ?? []).count))") {
                        if let positions = account.positions, !positions.isEmpty {
                            ForEach(positions) { position in
                                PositionRow(position: position)
                            }
                        } else {
                            Text("No positions.")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if !isLoading {
                    Text("No account data yet. Pull to refresh.")
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Portfolio")
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if isLoading && account == nil {
                    ProgressView("Loading…")
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try config.makeClient()
            account = try await client.account()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PositionRow: View {
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(position.symbol ?? "\u{2014}")
                    .font(.headline)
                Spacer()
                Text(Formatters.moneyString(position.marketValue))
                    .font(.subheadline)
            }
            HStack {
                Text("Qty \(Formatters.quantityString(position.quantity)) @ \(Formatters.moneyString(position.avgCost))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Formatters.signedMoneyString(position.unrealizedPnl))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Formatters.pnlColor(position.unrealizedPnl))
            }
            if let price = position.marketPrice {
                Text("Last \(Formatters.moneyString(price))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}