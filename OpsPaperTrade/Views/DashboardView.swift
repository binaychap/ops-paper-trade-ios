import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var config: AppConfig

    @State private var response: TradesResponse?
    @State private var health: HealthResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var searchText = ""
    @State private var statusFilter = "all"

    private var trades: [Trade] { response?.trades ?? [] }

    private var availableStatuses: [String] {
        let statuses = Set(trades.compactMap { $0.status?.lowercased() })
        return ["all"] + statuses.sorted()
    }

    private var filteredTrades: [Trade] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trades.filter { trade in
            let matchesStatus = statusFilter == "all" || (trade.status ?? "").lowercased() == statusFilter
            let matchesSearch = query.isEmpty
                || (trade.symbol ?? "").lowercased().contains(query)
                || (trade.tradeId ?? "").lowercased().contains(query)
            return matchesStatus && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let health {
                    healthSection(health)
                }
                if let summary = response?.summary {
                    summarySection(summary)
                }
                if let notice = response?.notice, !notice.isEmpty {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Trades (\(filteredTrades.count))") {
                    ForEach(filteredTrades) { trade in
                        NavigationLink {
                            TradeDetailView(trade: trade)
                        } label: {
                            TradeRow(trade: trade)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .searchable(text: $searchText, prompt: "Search symbol or trade ID")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Status", selection: $statusFilter) {
                            ForEach(availableStatuses, id: \.self) { status in
                                Text(status == "all" ? "All" : status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .tag(status)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .overlay {
                if isLoading && response == nil {
                    ProgressView("Loading…")
                }
            }
            .alert("Could not load", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Sections

    private func healthSection(_ health: HealthResponse) -> some View {
        Section {
            HStack {
                Circle()
                    .fill(health.isAlive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(health.isAlive ? "Bot alive" : "Bot not reporting ok")
                    .font(.headline)
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
            if let settings = response?.settings {
                let schedulerText = (settings.schedulerRunning == true) ? "Running"
                    : (settings.schedulerEnabled == true) ? "Enabled"
                    : "Off"
                LabeledContent("Scheduler", value: schedulerText)
                if let exitTime = settings.exitTime {
                    LabeledContent("Exit time", value: exitTime)
                }
            }
        }
    }

    private func summarySection(_ summary: TradeSummary) -> some View {
        Section("Summary") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryTile(title: "Total", value: summary.total, color: .primary)
                summaryTile(title: "Ordered", value: summary.ordered, color: .green)
                summaryTile(title: "Active exits", value: summary.activeExits, color: .blue)
                summaryTile(title: "Needs attention", value: summary.attention, color: .red)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func summaryTile(title: String, value: Int?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value ?? 0)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try config.makeClient()
            async let healthResult = client.health()
            async let tradesResult = client.trades()
            health = try await healthResult
            response = try await tradesResult
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct TradeRow: View {
    let trade: Trade

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trade.displaySymbol)
                    .font(.headline)
                Spacer()
                StatusPill(status: trade.status)
            }
            HStack(spacing: 4) {
                if let direction = trade.direction {
                    Text(direction.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let strategy = trade.strategy {
                    Text("\u{00B7} \(strategy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let notional = trade.notionalUsd {
                    Text(Formatters.moneyString(notional))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let updated = trade.updatedAt {
                Text(Formatters.newYorkDateTimeString(updated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
