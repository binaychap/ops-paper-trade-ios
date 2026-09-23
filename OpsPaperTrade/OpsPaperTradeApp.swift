import SwiftUI

@main
struct OpsPaperTradeApp: App {
    @StateObject private var config = AppConfig()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis") }
                PortfolioView()
                    .tabItem { Label("Portfolio", systemImage: "briefcase") }
                TradeTicketView()
                    .tabItem { Label("Trade", systemImage: "arrow.left.arrow.right") }
                OrdersView()
                    .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
            .environmentObject(config)
        }
    }
}