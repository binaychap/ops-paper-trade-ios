# OpsPaperTrade iOS

Native SwiftUI trading client for the `ops-paper-trade` paper-trading bot.
No third-party dependencies. iOS 17+.

## Tabs

- **Dashboard** — bot health (alive dot, DRY RUN badge, scheduler state), trade summary cards (total / ordered / active exits / needs attention), searchable and filterable trade-idea list, and a detail view with decision rationale, bracket order IDs, and the exit-job state.
- **Portfolio** — account summary (total value, cash, buying power) and positions with P&L coloring.
- **Trade** — order ticket (symbol, buy/sell, market/limit, quantity, limit price) with a server-side **preview** step showing risk checks, warnings, estimated notional, and dry-run state; **Confirm & submit** is disabled until the preview passes, then asks for a second confirmation.
- **Orders** — recent orders with status pills.
- **Settings** — server URL, Keychain-backed API key, and a connection test.

All trading calls send `Authorization: Bearer <IOS_API_KEY>`. The dashboard endpoints (`/health`, `/api/trades`) need no auth, matching the web dashboard. Timestamps are displayed in America/New_York.

## 1. Server setup (on your Mac)

The app expects these endpoints on the bot's FastAPI server:

- `GET /health` → `{"status": "ok", "dry_run": bool}` (already exists)
- `GET /api/trades` (already exists)
- `GET /api/trading/account` — `{"account_number","currency","total_value","cash","buying_power","positions":[{"symbol","quantity","avg_cost","market_price","market_value","unrealized_pnl","unrealized_pnl_pct"}],"as_of"}`
- `GET /api/trading/orders?limit=50` — `{"orders":[{"order_id","client_order_id","symbol","side","order_type","quantity","limit_price","status","filled_quantity","created_at","source"}],"as_of"}`
- `POST /api/trading/orders/preview` — request `{"symbol","side","order_type","quantity","limit_price"}`; response `{"ok","symbol","side","order_type","quantity","limit_price","reference_price","estimated_notional","max_notional_usd","within_notional_cap","market_open","dry_run","checks":[{"name","passed","detail"}],"warnings":[]}`
- `POST /api/trading/orders` — same fields plus `"confirm": true`; response `{"dry_run","status","order_id","client_order_id","preview","message"}`

All `/api/trading/*` routes must require `Authorization: Bearer <IOS_API_KEY>`.

Steps:

1. Set `IOS_API_KEY` in the bot repo's `.env` (pick a long random value).
2. Start the server bound to all interfaces so your iPhone can reach it:

   ```bash
   cd /Users/binayrai/github/ops-paper-trade
   PYTHONPATH=. uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

3. Find your Mac's LAN IP: System Settings → Wi-Fi → Details, or run `ipconfig getifaddr en0` in Terminal.
4. Keep `DRY_RUN=true` (the default) while testing — orders are validated but never submitted to the broker.

## 2. App setup (in Xcode)

1. Open `OpsPaperTrade.xcodeproj` in Xcode 16+.
2. Select the **OpsPaperTrade** target → **Signing & Capabilities** → choose your Apple Developer **Team** (required to run on a physical iPhone).
3. Connect your iPhone (same Wi-Fi as the Mac) and press Run.
4. In the app's **Settings** tab enter `http://<mac-lan-ip>:8000` and your `IOS_API_KEY`, tap **Save API key to Keychain**, then **Test connection**.

## Notes

- Plain HTTP is allowed via `NSAppTransportSecurity` (`NSAllowsArbitraryLoads`) because the bot serves HTTP on your LAN. Do not expose this server to the internet.
- No credentials are stored in the project — the API key lives only in the iOS Keychain.
- Project structure: `Config/` (AppConfig, KeychainHelper, UIHelpers), `API/` (APIClient), `Models/` (Codable models), `Views/` (one file per tab).