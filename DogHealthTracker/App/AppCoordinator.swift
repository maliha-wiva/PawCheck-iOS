import SwiftUI

/// Root coordinator that manages the primary navigation structure of the app.
/// Responsible for setting up the tab-based navigation and injecting dependencies.
struct AppCoordinator: View {
    
    // MARK: - Properties
    let container: AppDIContainer
    @State private var selectedTab: AppTab = .home
    
    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
            historyTab
            dogProfileTab
            settingsTab
        }
        .accentColor(AppTheme.Colors.primary)
    }
    
    // MARK: - Tabs
    
    private var homeTab: some View {
        NavigationStack {
            HomeView(viewModel: container.makeHomeViewModel())
        }
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(AppTab.home)
    }
    
    private var historyTab: some View {
        NavigationStack {
            HistoryView(viewModel: container.makeHistoryViewModel())
        }
        .tabItem {
            Label("History", systemImage: "clock.fill")
        }
        .tag(AppTab.history)
    }
    
    private var dogProfileTab: some View {
        NavigationStack {
            DogProfileView(viewModel: container.makeDogProfileViewModel())
        }
        .tabItem {
            Label("My Dog", systemImage: "pawprint.fill")
        }
        .tag(AppTab.dogProfile)
    }
    
    private var settingsTab: some View {
        NavigationStack {
            SettingsView(viewModel: container.makeSettingsViewModel())
        }
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
        .tag(AppTab.settings)
    }
}

// MARK: - App Tab Enum

enum AppTab: Hashable {
    case home
    case history
    case dogProfile
    case settings
}
