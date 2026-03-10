import SwiftUI

@main
struct DogHealthTrackerApp: App {
    
    // MARK: - Dependencies
    private let appContainer: AppDIContainer
    
    init() {
        self.appContainer = AppDIContainer()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator(container: appContainer)
                .preferredColorScheme(.light)
        }
    }
}
