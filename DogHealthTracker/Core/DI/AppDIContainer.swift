import Foundation
import SwiftUI
import Combine

/// Shared observable store for dog profile — acts as an in-memory
/// reactive bridge between DogProfileViewModel and HomeViewModel.
/// Any screen that needs the current dog profile observes this object.
final class DogProfileStore: ObservableObject {
    @Published var dogProfile: DogProfile?
}

/// Central Dependency Injection Container following the Service Locator + Factory pattern.
/// This is the composition root of the application.
/// All dependencies are assembled here to maintain a single source of truth.
///
/// Architecture:
/// - Shared services (singletons) are created once and reused.
/// - ViewModels are created fresh (transient) per screen to avoid state leakage.
final class AppDIContainer {
    
    /// Shared store — same instance injected into both Home and DogProfile ViewModels
    let dogProfileStore = DogProfileStore()
        
    // MARK: - Shared Infrastructure (Singletons)
    
    private lazy var networkClient: NetworkClientProtocol = {
        NetworkClient()
    }()
    
    private lazy var localStorageService: LocalStorageServiceProtocol = {
        CoreDataStorageService()
    }()
    
    private lazy var userDefaultsService: UserDefaultsServiceProtocol = {
        UserDefaultsService()
    }()
    
    private lazy var imageStorageService: ImageStorageServiceProtocol = {
        FileSystemImageStorageService()
    }()
    
    // MARK: - Remote Data Sources
    
    private lazy var openAIDataSource: OpenAIDataSourceProtocol = {
        OpenAIDataSource(networkClient: networkClient)
    }()
    
    // MARK: - Local Data Sources
    
    private lazy var analysisLocalDataSource: AnalysisLocalDataSourceProtocol = {
        AnalysisLocalDataSource(storageService: localStorageService)
    }()
    
    private lazy var dogProfileLocalDataSource: DogProfileLocalDataSourceProtocol = {
        DogProfileLocalDataSource(storageService: localStorageService)
    }()
    
    // MARK: - Repositories
    
    private lazy var poopAnalysisRepository: PoopAnalysisRepositoryProtocol = {
        PoopAnalysisRepository(
            remoteDataSource: openAIDataSource,
            localDataSource: analysisLocalDataSource,
            imageStorageService: imageStorageService
        )
    }()
    
    private lazy var dogProfileRepository: DogProfileRepositoryProtocol = {
        DogProfileRepository(localDataSource: dogProfileLocalDataSource)
    }()
    
    private lazy var settingsRepository: SettingsRepositoryProtocol = {
        SettingsRepository(userDefaultsService: userDefaultsService)
    }()
    
    // MARK: - Use Cases
    
    private func makeAnalyzePoopUseCase() -> AnalyzePoopUseCaseProtocol {
        AnalyzePoopUseCase(repository: poopAnalysisRepository)
    }
    
    private func makeGetAnalysisHistoryUseCase() -> GetAnalysisHistoryUseCaseProtocol {
        GetAnalysisHistoryUseCase(repository: poopAnalysisRepository)
    }
    
    private func makeDeleteAnalysisUseCase() -> DeleteAnalysisUseCaseProtocol {
        DeleteAnalysisUseCase(repository: poopAnalysisRepository)
    }
    
    private func makeSaveDogProfileUseCase() -> SaveDogProfileUseCaseProtocol {
        SaveDogProfileUseCase(repository: dogProfileRepository)
    }
    
    private func makeGetDogProfileUseCase() -> GetDogProfileUseCaseProtocol {
        GetDogProfileUseCase(repository: dogProfileRepository)
    }
    
    // MARK: - ViewModel Factories (Transient — new instance per call)
    
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            analyzePoopUseCase: makeAnalyzePoopUseCase(),
            getDogProfileUseCase: makeGetDogProfileUseCase(),
            dogProfileStore: dogProfileStore
        )
    }
    
    func makeAnalysisResultViewModel(result: PoopAnalysisResult) -> AnalysisResultViewModel {
        AnalysisResultViewModel(
            result: result,
            deleteAnalysisUseCase: makeDeleteAnalysisUseCase()
        )
    }
    
    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(
            getAnalysisHistoryUseCase: makeGetAnalysisHistoryUseCase(),
            deleteAnalysisUseCase: makeDeleteAnalysisUseCase()
        )
    }
    
    func makeDogProfileViewModel() -> DogProfileViewModel {
        DogProfileViewModel(
            getDogProfileUseCase: makeGetDogProfileUseCase(),
            saveDogProfileUseCase: makeSaveDogProfileUseCase(),
            dogProfileStore: dogProfileStore
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(settingsRepository: settingsRepository)
    }
}
