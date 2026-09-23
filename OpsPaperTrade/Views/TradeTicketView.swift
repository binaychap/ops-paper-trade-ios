import SwiftUI

struct TradeTicketView: View {
    @EnvironmentObject private var config: AppConfig

    @State private var symbol = ""
    @State private var side = "buy"
    @State private var orderType = "market"
    @State private var quantity: Double = 1
    @State private var limitPriceText = ""

    @State private var preview: OrderPreviewResponse?
    @State private var isPreviewing = false
    @State private var previewError: String?

    @State private var showingConfirm = false
    @State private var isSubmitting = false
    @State private var submitResult: OrderSubmitResponse?
    @State private var submitError: String?

    private var limitPrice: Double? {
        guard orderType == "limit" else { return nil }
        let value = Double(limitPriceText) ?? 0
        return value > 0 ? value : nil
    }

    private var isValid: Bool {
        !symbol.trimmingCharacters(in: .whitespaces).isEmpty
            && quantity > 0
            && (orderType == "market" || limitPrice != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Order") {
                    TextField("Symbol (e.g. AAPL)", text: $symbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("Side", selection: $side) {
                        Text("Buy").tag("buy")
                        Text("Sell").tag("sell")
                    }
                    .pickerStyle(.segmented)
                    Picker("Type", selection: $orderType) {
                        Text("Market").tag("market")
                        Text("Limit").tag("limit")
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("Qty", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                        Stepper("", value: $quantity, in: 1...1_000_000, step: 1)
                            .labelsHidden()
                    }
                    if orderType == "limit" {
                        HStack {
                            Text("Limit price")
                            Spacer()
                            TextField("0.00", text: $limitPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await previewOrder() }
                    } label: {
                        if isPreviewing {
                            ProgressView()
                        } else {
                            Text("Preview order")
                        }
                    }
                    .disabled(!isValid || isPreviewing)
                } footer: {
                    Text("Preview asks the bot to validate the order (risk checks, notional cap, market hours) before anything is submitted.")
                }

                if let previewError {
                    Section {
                        Text(previewError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let preview {
                    previewSection(preview)
                }

                if let submitError {
                    Section {
                        Text(submitError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let submitResult {
                    resultSection(submitResult)
                }
            }
            .navigationTitle("Trade")
            .confirmationDialog("Submit this order?", isPresented: $showingConfirm, titleVisibility: .visible) {
                Button("Submit", role: .destructive) {
                    Task { await submitOrder() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This sends the order to the paper-trading bot.")
            }
        }
    }

    // MARK: - Networking

    private func previewRequest() -> OrderPreviewRequest {
        OrderPreviewRequest(
            symbol: symbol.trimmingCharacters(in: .whitespaces).uppercased(),
            side: side,
            orderType: orderType,
            quantity: quantity,
            limitPrice: limitPrice
        )
    }

    private func previewOrder() async {
        isPreviewing = true
        defer { isPreviewing = false }
        preview = nil
        previewError = nil
        submitResult = nil
        submitError = nil
        do {
            let client = try config.makeClient()
            preview = try await client.previewOrder(previewRequest())
        } catch {
            previewError = error.localizedDescription
        }
    }

    private func submitOrder() async {
        isSubmitting = true
        defer { isSubmitting = false }
        submitError = nil
        do {
            let client = try config.makeClient()
            submitResult = try await client.submitOrder(OrderSubmitRequest(preview: previewRequest()))
            preview = nil
        } catch {
            submitError = error.localizedDescription
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func previewSection(_ preview: OrderPreviewResponse) -> some View {
        Section("Preview") {
            if preview.dryRun == true {
                Text("DRY RUN \u{2014} validated only, nothing will be submitted")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }
            LabeledContent("Estimated notional", value: Formatters.moneyString(preview.estimatedNotional))
            if let reference = preview.referencePrice {
                LabeledContent("Reference price", value: Formatters.moneyString(reference))
            }
            LabeledContent("Within notional cap", value: (preview.withinNotionalCap == true) ? "Yes" : "No")
            LabeledContent("Market open", value: (preview.marketOpen == true) ? "Yes" : "No")
            if let checks = preview.checks, !checks.isEmpty {
                ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                    HStack(alignment: .top) {
                        Image(systemName: (check.passed == true) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle((check.passed == true) ? Color.green : Color.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(check.name ?? "Check")
                                .font(.subheadline)
                            if let detail = check.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if let warnings = preview.warnings, !warnings.isEmpty {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            Button {
                showingConfirm = true
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Confirm & submit")
                }
            }
            .disabled((preview.ok != true) || isSubmitting)
        } footer: {
            Text("Submit is disabled until the preview passes (ok).")
        }
    }

    @ViewBuilder
    private func resultSection(_ result: OrderSubmitResponse) -> some View {
        Section("Result") {
            if result.dryRun == true {
                Label("Dry run \u{2014} the order was validated but not submitted.", systemImage: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            if let status = result.status {
                HStack {
                    Text("Status")
                    Spacer()
                    StatusPill(status: status)
                }
            }
            if let orderId = result.orderId {
                LabeledContent("Order ID", value: orderId)
            }
            if let clientId = result.clientOrderId {
                LabeledContent("Client order ID", value: clientId)
            }
            if let message = result.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("New order") {
                submitResult = nil
                previewError = nil
                submitError = nil
                symbol = ""
                limitPriceText = ""
            }
        }
    }
}