import SwiftUI

struct TradeDetailView: View {
    let trade: Trade

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Symbol", value: trade.displaySymbol)
                HStack {
                    Text("Status")
                    Spacer()
                    StatusPill(status: trade.status)
                }
                if let direction = trade.direction {
                    LabeledContent("Direction", value: direction.capitalized)
                }
                if let strategy = trade.strategy {
                    LabeledContent("Strategy", value: strategy)
                }
                if let pipeline = trade.pipeline {
                    LabeledContent("Pipeline", value: pipeline)
                }
                if let action = trade.action {
                    LabeledContent("Action", value: action)
                }
                if let notional = trade.notionalUsd {
                    LabeledContent("Notional", value: Formatters.moneyString(notional))
                }
                if let tradeId = trade.tradeId {
                    LabeledContent("Trade ID", value: tradeId)
                }
                LabeledContent("Created", value: Formatters.newYorkDateTimeString(trade.createdAt))
                LabeledContent("Updated", value: Formatters.newYorkDateTimeString(trade.updatedAt))
            }

            if let rationale = trade.rationale, !rationale.isEmpty {
                Section("Rationale") {
                    Text(rationale)
                }
            }

            if let bracket = trade.bracket, bracket.hasAny {
                Section("Bracket orders") {
                    bracketRow("Entry", bracket.entryId)
                    bracketRow("Profit", bracket.profitId)
                    bracketRow("Stop", bracket.stopId)
                    bracketRow("Combo", bracket.comboId)
                }
            }

            if let exit = trade.exit {
                exitSection(exit)
            }
        }
        .navigationTitle(trade.displaySymbol)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func bracketRow(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            LabeledContent(label) {
                Text(value)
                    .font(.footnote.monospaced())
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func exitSection(_ exit: ExitJob) -> some View {
        Section("Exit job") {
            HStack {
                Text("Status")
                Spacer()
                StatusPill(status: exit.status)
            }
            if let dueAt = exit.dueAt {
                LabeledContent("Due", value: Formatters.newYorkDateTimeString(dueAt))
            }
            if let quantity = exit.quantity {
                LabeledContent("Quantity", value: Formatters.quantityString(quantity))
            }
            if let remaining = exit.remainingQuantity {
                LabeledContent("Remaining", value: Formatters.quantityString(remaining))
            }
            if let nextCheck = exit.nextCheckAt {
                LabeledContent("Next check", value: Formatters.newYorkDateTimeString(nextCheck))
            }
            if let error = exit.lastError, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let attempts = exit.marketOrders, !attempts.isEmpty {
                ForEach(Array(attempts.enumerated()), id: \.offset) { _, attempt in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(attempt.id ?? "Market order")
                                .font(.subheadline)
                            Spacer()
                            StatusPill(status: attempt.status)
                        }
                        Text("Qty \(Formatters.quantityString(attempt.quantity)) \u{00B7} Filled \(Formatters.quantityString(attempt.filledQuantity))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}