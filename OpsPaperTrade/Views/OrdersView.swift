import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var config: AppConfig

    @State private var orders: [OrderRecord] = []
    @State private var asOf: String?
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
                if orders.isEmpty && !isLoading {
                    Text("No orders yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(orders) { order in
                    OrderRow(order: order)
                }
                if let asOf {
                    Text("As of \(Formatters.newYorkDateTimeString(asOf))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Orders")
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if isLoading && orders.isEmpty {
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
            let response = try await client.orders(limit: 50)
            orders = response.orders ?? []
            asOf = response.asOf
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OrderRow: View {
    let order: OrderRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.symbol ?? "\u{2014}")
                    .font(.headline)
                Text((order.side ?? "").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text((order.orderType ?? "").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                StatusPill(status: order.status)
            }
            HStack {
                Text("Qty \(Formatters.quantityString(order.quantity))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let limit = order.limitPrice {
                    Text("@ \(Formatters.moneyString(limit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let filled = order.filledQuantity, filled > 0 {
                    Text("Filled \(Formatters.quantityString(filled))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let created = order.createdAt {
                Text(Formatters.newYorkDateTimeString(created))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}