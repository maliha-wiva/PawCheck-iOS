import Foundation
import UIKit

// MARK: - Poop Analysis Repository Protocol

/// Abstracts all data operations for poop analysis results.
/// Implementations can swap between local-only, remote-only, or hybrid strategies.
protocol PoopAnalysisRepositoryProtocol: AnyObject {
    
    /// Submits an image for AI analysis and persists the result locally.
    /// - Parameters:
    ///   - image: The captured or selected poop image.
    ///   - dogProfile: Optional dog context for more accurate analysis.
    /// - Returns: A fully populated `PoopAnalysisResult`.
    func analyzeImage(_ image: UIImage, dogProfile: DogProfile?) async throws -> PoopAnalysisResult
    
    /// Fetches the paginated history of past analyses.
    func fetchHistory(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult]
    
    /// Fetches all analyses for a given date range.
    func fetchHistory(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult]
    
    /// Fetches a single analysis by its identifier.
    func fetchAnalysis(byId id: UUID) async throws -> PoopAnalysisResult?
    
    /// Deletes a single analysis and its associated image.
    func deleteAnalysis(id: UUID) async throws
    
    /// Deletes all stored analyses and images.
    func deleteAllAnalyses() async throws
    
    /// Returns the total count of stored analyses.
    func fetchAnalysisCount() async throws -> Int
}

// MARK: - Dog Profile Repository Protocol

protocol DogProfileRepositoryProtocol: AnyObject {
    
    /// Fetches the primary dog profile, if one exists.
    func fetchPrimaryDogProfile() async throws -> DogProfile?
    
    /// Saves (insert or update) a dog profile.
    func saveDogProfile(_ profile: DogProfile) async throws -> DogProfile
    
    /// Deletes a dog profile and its associated data.
    func deleteDogProfile(id: UUID) async throws
    
    /// Fetches all saved dog profiles (for multi-dog support in future).
    func fetchAllDogProfiles() async throws -> [DogProfile]
}

// MARK: - Settings Repository Protocol

protocol SettingsRepositoryProtocol: AnyObject {
    
    /// Loads the current app settings.
    func loadSettings() -> AppSettings
    
    /// Persists updated settings.
    func saveSettings(_ settings: AppSettings)
    
    /// Resets settings to their factory defaults.
    func resetToDefaults()
    
    /// Returns whether a valid OpenAI API key has been configured.
    var hasValidAPIKey: Bool { get }
}
