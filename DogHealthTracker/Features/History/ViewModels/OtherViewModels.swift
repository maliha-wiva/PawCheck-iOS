import Foundation

// MARK: - History ViewModel
import Combine

@MainActor
final class HistoryViewModel: BaseViewModel {
    
    @Published var state: ViewState<[PoopAnalysisResult]> = .idle
    @Published var results: [PoopAnalysisResult] = []
    @Published var selectedFilter: HistoryFilter = .all
    @Published var showDeleteAllConfirmation: Bool = false
    
    private let getAnalysisHistoryUseCase: GetAnalysisHistoryUseCaseProtocol
    private let deleteAnalysisUseCase: DeleteAnalysisUseCaseProtocol
    private var currentPage = 0
    private let pageSize = 20
    
    init(
        getAnalysisHistoryUseCase: GetAnalysisHistoryUseCaseProtocol,
        deleteAnalysisUseCase: DeleteAnalysisUseCaseProtocol
    ) {
        self.getAnalysisHistoryUseCase = getAnalysisHistoryUseCase
        self.deleteAnalysisUseCase = deleteAnalysisUseCase
        super.init()
        loadHistory()
    }
    
    var filteredResults: [PoopAnalysisResult] {
        switch selectedFilter {
        case .all:
            return results
        case .detected:
            return results.filter { $0.detectionStatus == .detected }
        case .urgent:
            return results.filter { result in
                result.recommendations.contains { $0.priority == .urgent }
            }
        case .thisWeek:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return results.filter { $0.capturedAt >= weekAgo }
        }
    }
    
    func loadHistory() {
        state = .loading
        Task {
            do {
                let fetched = try await getAnalysisHistoryUseCase.execute(page: 0, pageSize: pageSize)
                results = fetched
                state = fetched.isEmpty ? .empty : .success(fetched)
                currentPage = 0
            } catch {
                state = .failure(AppError.from(error))
            }
        }
    }
    
    func loadMoreIfNeeded(currentItem: PoopAnalysisResult) {
        guard let lastItem = results.last, lastItem.id == currentItem.id else { return }
        loadNextPage()
    }
    
    func deleteItem(id: UUID) {
        perform {
            try await self.deleteAnalysisUseCase.execute(id: id)
            await MainActor.run {
                self.results.removeAll { $0.id == id }
                if self.results.isEmpty { self.state = .empty }
            }
        }
    }
    
    func deleteAll() {
        perform {
            try await self.deleteAnalysisUseCase.executeDeleteAll()
            await MainActor.run {
                self.results = []
                self.state = .empty
            }
        }
    }
    
    private func loadNextPage() {
        currentPage += 1
        Task {
            do {
                let moreFetched = try await getAnalysisHistoryUseCase.execute(
                    page: currentPage,
                    pageSize: pageSize
                )
                results.append(contentsOf: moreFetched)
            } catch {
                alertError = AppError.from(error)
                currentPage -= 1  // Roll back on failure
            }
        }
    }
}

enum HistoryFilter: String, CaseIterable {
    case all      = "All"
    case detected = "Analyzed"
    case urgent   = "Urgent"
    case thisWeek = "This Week"
}

// MARK: - Dog Profile ViewModel

@MainActor
final class DogProfileViewModel: BaseViewModel {
    
    @Published var profile: DogProfile = .empty
    @Published var savedProfile: DogProfile? = nil   // last successfully saved snapshot
    @Published var isSaved: Bool = false
    @Published var isEditing: Bool = false
    
    /// True only when the current form values differ from the last saved snapshot.
    /// Controls save button visibility — no changes = no save button shown.
    var hasUnsavedChanges: Bool {
        guard let saved = savedProfile else {
            // Never saved before — show save button only if name is filled
            return !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return profile != saved
    }
    
    private let getDogProfileUseCase: GetDogProfileUseCaseProtocol
    private let saveDogProfileUseCase: SaveDogProfileUseCaseProtocol
    private let dogProfileStore: DogProfileStore
    
    init(
        getDogProfileUseCase: GetDogProfileUseCaseProtocol,
        saveDogProfileUseCase: SaveDogProfileUseCaseProtocol,
        dogProfileStore: DogProfileStore
    ) {
        self.getDogProfileUseCase = getDogProfileUseCase
        self.saveDogProfileUseCase = saveDogProfileUseCase
        self.dogProfileStore = dogProfileStore
        super.init()
        loadProfile()
    }
    
    func onSaveTapped() {
        perform(showLoading: true) {
            let saved = try await self.saveDogProfileUseCase.execute(self.profile)
            await MainActor.run {
                self.profile = saved
                self.savedProfile = saved          // update snapshot → hasUnsavedChanges becomes false
                self.dogProfileStore.dogProfile = saved  // notify HomeViewModel instantly
                self.isSaved = true
                self.isEditing = false
                
                // Auto-hide the saved feedback after 2 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.isSaved = false
                }
            }
        }
    }
    
    func onEditTapped() {
        isEditing = true
        isSaved = false
    }
    
    func onCancelEdit() {
        isEditing = false
        isSaved = false
        // Restore form to last saved values, discarding changes
        if let saved = savedProfile {
            profile = saved
        } else {
            profile = .empty
        }
    }
    
    private func loadProfile() {
        Task {
            if let loaded = try? await getDogProfileUseCase.execute() {
                profile = loaded
                savedProfile = loaded    // seed snapshot so hasUnsavedChanges = false on load
                dogProfileStore.dogProfile = loaded
            }
        }
    }
}

// MARK: - Settings ViewModel

@MainActor
final class SettingsViewModel: BaseViewModel {
    
    @Published var settings: AppSettings = .defaultSettings
    @Published var isAPIKeyVisible: Bool = false
    @Published var showResetConfirmation: Bool = false
    @Published var savedFeedback: Bool = false
    
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(settingsRepository: SettingsRepositoryProtocol) {
        self.settingsRepository = settingsRepository
        super.init()
        settings = settingsRepository.loadSettings()
    }
    
    var hasValidAPIKey: Bool { settingsRepository.hasValidAPIKey }
    
    func onSaveSettings() {
        settingsRepository.saveSettings(settings)
        savedFeedback = true
    }
    
    func onResetToDefaults() {
        settingsRepository.resetToDefaults()
        settings = .defaultSettings
    }
    
    func onToggleAPIKeyVisibility() {
        isAPIKeyVisible.toggle()
    }
}
