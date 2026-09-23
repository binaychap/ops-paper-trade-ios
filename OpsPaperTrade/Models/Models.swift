import Foundation

// MARK: - Health

/// GET /health — every field optional; the server currently returns
/// {"status": "ok", "dry_run": bool}.
struct HealthResponse: Codable {
    var status: String?
    var dryRun: Bool?

    var isAlive: Bool { (status ?? "").lowercased() == "ok" }
}

// MARK: - Dashboard trades

/// GET /api/trades
struct TradesResponse: Codable {
    var trades: [Trade]?
    var notice: String?
    var asOf: String?
    var summary: TradeSummary?
    var settings: DashboardSettings?
}

struct TradeSummary: Codable {
    var total: Int?
    var ordered: Int?
    var activeExits: Int?
    var completedExits: Int?
    var attention: Int?
}

struct DashboardSettings: Codable {
    var dryRun: Bool?
    var schedulerEnabled: Bool?
    var schedulerRunning: Bool?
    var exitTime: String?
    var timezone: String?
}

struct Trade: Codable, Identifiable {
    var key: String?
    var tradeId: String?
    var symbol: String?
    var direction: String?
    var strategy: String?
    var pipeline: String?
    var status: String?
    var createdAt: String?
    var updatedAt: String?
    var action: String?
    var notionalUsd: Double?
    var rationale: String?
    var bracket: Bracket?
    var exit: ExitJob?

    /// The server always provides `key`; fall back to trade_id so rows stay stable.
    var id: String { key ?? tradeId ?? "unknown" }
    var displaySymbol: String { symbol ?? "\u{2014}" }
}

struct Bracket: Codable {
    var entryId: String?
    var profitId: String?
    var stopId: String?
    var comboId: String?

    var hasAny: Bool {
        [entryId, profitId, stopId, comboId].contains { ($0 ?? "").isEmpty == false }
    }
}

struct ExitJob: Codable {
    var id: String?
    var symbol: String?
    var status: String?
    var updatedAt: String?
    var entryId: String?
    var profitId: String?
    var stopId: String?
    var comboId: String?
    var dueAt: String?
    var entryFilledAt: String?
    var entryFilledQuantity: Double?
    var bracketFilledQuantity: Double?
    var remainingQuantity: Double?
    var quantity: Double?
    var lastError: String?
    var nextCheckAt: String?
    var entrySubmissionError: String?
    var orderSnapshots: [String: OrderSnapshot]?
    var marketOrders: [MarketOrderAttempt]?
}

struct OrderSnapshot: Codable {
    var status: String?
    var filledQuantity: Double?
}

struct MarketOrderAttempt: Codable {
    var id: String?
    var quantity: Double?
    var status: String?
    var filledQuantity: Double?
}

// MARK: - Account

/// GET /api/trading/account
struct AccountResponse: Codable {
    var accountNumber: String?
    var currency: String?
    var totalValue: Double?
    var cash: Double?
    var buyingPower: Double?
    var positions: [Position]?
    var asOf: String?
}

struct Position: Codable, Identifiable {
    var symbol: String?
    var quantity: Double?
    var avgCost: Double?
    var marketPrice: Double?
    var marketValue: Double?
    var unrealizedPnl: Double?
    var unrealizedPnlPct: Double?

    var id: String { symbol ?? UUID().uuidString }
}

// MARK: - Orders

/// GET /api/trading/orders
struct OrdersResponse: Codable {
    var orders: [OrderRecord]?
    var asOf: String?
}

struct OrderRecord: Codable, Identifiable {
    var orderId: String?
    var clientOrderId: String?
    var symbol: String?
    var side: String?
    var orderType: String?
    var quantity: Double?
    var limitPrice: Double?
    var status: String?
    var filledQuantity: Double?
    var createdAt: String?
    var source: String?

    var id: String { orderId ?? clientOrderId ?? UUID().uuidString }
}

// MARK: - Order preview / submit

/// POST /api/trading/orders/preview — request body.
struct OrderPreviewRequest: Codable {
    var symbol: String
    var side: String        // "buy" | "sell"
    var orderType: String   // "market" | "limit"
    var quantity: Double
    var limitPrice: Double?
}

/// POST /api/trading/orders — request body (preview fields + confirm).
struct OrderSubmitRequest: Codable {
    var symbol: String
    var side: String
    var orderType: String
    var quantity: Double
    var limitPrice: Double?
    var confirm: Bool

    init(preview: OrderPreviewRequest) {
        self.symbol = preview.symbol
        self.side = preview.side
        self.orderType = preview.orderType
        self.quantity = preview.quantity
        self.limitPrice = preview.limitPrice
        self.confirm = true
    }
}

/// POST /api/trading/orders/preview — response.
struct OrderPreviewResponse: Codable {
    var ok: Bool?
    var symbol: String?
    var side: String?
    var orderType: String?
    var quantity: Double?
    var limitPrice: Double?
    var referencePrice: Double?
    var estimatedNotional: Double?
    var maxNotionalUsd: Double?
    var withinNotionalCap: Bool?
    var marketOpen: Bool?
    var dryRun: Bool?
    var checks: [PreviewCheck]?
    var warnings: [String]?
}

struct PreviewCheck: Codable {
    var name: String?
    var passed: Bool?
    var detail: String?
}

/// POST /api/trading/orders — response.
struct OrderSubmitResponse: Codable {
    var dryRun: Bool?
    var status: String?
    var orderId: String?
    var clientOrderId: String?
    var preview: OrderPreviewResponse?
    var message: String?
}