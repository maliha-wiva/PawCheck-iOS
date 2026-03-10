import Foundation
import UIKit

// MARK: - Poop Analysis Repository

/// Concrete implementation of `PoopAnalysisRepositoryProtocol`.
/// Orchestrates the flow: AI analysis → image storage → local persistence.
final class PoopAnalysisRepository: PoopAnalysisRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let remoteDataSource: OpenAIDataSourceProtocol
    private let localDataSource: AnalysisLocalDataSourceProtocol
    private let imageStorageService: ImageStorageServiceProtocol
    
    // MARK: - Init
    
    init(
        remoteDataSource: OpenAIDataSourceProtocol,
        localDataSource: AnalysisLocalDataSourceProtocol,
        imageStorageService: ImageStorageServiceProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
        self.imageStorageService = imageStorageService
    }
    
    // MARK: - PoopAnalysisRepositoryProtocol
    
    func analyzeImage(_ image: UIImage, dogProfile: DogProfile?) async throws -> PoopAnalysisResult {
        // 1. Save image to local filesystem first (so we always have a reference)
        let imageFileName = "poop_\(UUID().uuidString).jpg"
        let imageLocalPath = try imageStorageService.saveImage(image, fileName: imageFileName)
        
        // 2. Call OpenAI Vision API
        let dto = try await remoteDataSource.analyzePoopImage(image, dogContext: dogProfile)
        
        // 3. Map DTO → Domain Entity
        let result = OpenAIAnalysisMapper.map(
            dto: dto,
            imageLocalPath: imageLocalPath,
            dogId: dogProfile?.id
        )
        
        // 4. Persist result locally for offline access
        try await localDataSource.saveAnalysis(result)
        
        return result
    }
    
    func fetchHistory(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult] {
        try await localDataSource.fetchAnalyses(page: page, pageSize: pageSize)
    }
    
    func fetchHistory(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult] {
        try await localDataSource.fetchAnalyses(from: startDate, to: endDate)
    }
    
    func fetchAnalysis(byId id: UUID) async throws -> PoopAnalysisResult? {
        try await localDataSource.fetchAnalysis(byId: id)
    }
    
    func deleteAnalysis(id: UUID) async throws {
        // Fetch first to get the image path for cleanup
        if let analysis = try await localDataSource.fetchAnalysis(byId: id) {
            try? imageStorageService.deleteImage(atPath: analysis.imageLocalPath)
        }
        try await localDataSource.deleteAnalysis(id: id)
    }
    
    func deleteAllAnalyses() async throws {
        let allAnalyses = try await localDataSource.fetchAnalyses(page: 0, pageSize: Int.max)
        allAnalyses.forEach { analysis in
            try? imageStorageService.deleteImage(atPath: analysis.imageLocalPath)
        }
        try await localDataSource.deleteAllAnalyses()
    }
    
    func fetchAnalysisCount() async throws -> Int {
        try await localDataSource.fetchAnalysisCount()
    }
}

// MARK: - Dog Profile Repository

final class DogProfileRepository: DogProfileRepositoryProtocol {
    
    private let localDataSource: DogProfileLocalDataSourceProtocol
    
    init(localDataSource: DogProfileLocalDataSourceProtocol) {
        self.localDataSource = localDataSource
    }
    
    func fetchPrimaryDogProfile() async throws -> DogProfile? {
        try await localDataSource.fetchPrimaryDogProfile()
    }
    
    func saveDogProfile(_ profile: DogProfile) async throws -> DogProfile {
        try await localDataSource.saveDogProfile(profile)
        return profile
    }
    
    func deleteDogProfile(id: UUID) async throws {
        try await localDataSource.deleteDogProfile(id: id)
    }
    
    func fetchAllDogProfiles() async throws -> [DogProfile] {
        try await localDataSource.fetchAllDogProfiles()
    }
}

// MARK: - Settings Repository

final class SettingsRepository: SettingsRepositoryProtocol {
    
    private let userDefaultsService: UserDefaultsServiceProtocol
    
    private enum Keys {
        static let settings = "app_settings_v1"
    }
    
    init(userDefaultsService: UserDefaultsServiceProtocol) {
        self.userDefaultsService = userDefaultsService
    }
    
    func loadSettings() -> AppSettings {
        guard let data = userDefaultsService.data(forKey: Keys.settings),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaultSettings
        }
        return settings
    }
    
    func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaultsService.set(data, forKey: Keys.settings)
    }
    
    func resetToDefaults() {
        userDefaultsService.removeObject(forKey: Keys.settings)
    }
    
    var hasValidAPIKey: Bool {
        let key = loadSettings().openAIAPIKey.trimmingCharacters(in: .whitespaces)
        return key.hasPrefix("sk-") && key.count > 20
    }
}
