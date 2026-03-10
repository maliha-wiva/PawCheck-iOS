import Foundation
import UIKit

// MARK: - Analyze Poop Use Case

/// Executes the core feature: AI-powered poop image analysis.
/// Validates preconditions before delegating to the repository.
protocol AnalyzePoopUseCaseProtocol {
    func execute(image: UIImage, dogProfile: DogProfile?) async throws -> PoopAnalysisResult
}

final class AnalyzePoopUseCase: AnalyzePoopUseCaseProtocol {
    
    private let repository: PoopAnalysisRepositoryProtocol
    
    init(repository: PoopAnalysisRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(image: UIImage, dogProfile: DogProfile?) async throws -> PoopAnalysisResult {
        // Validate image has minimum dimensions for reliable analysis
        let minDimension: CGFloat = 100
        guard image.size.width >= minDimension && image.size.height >= minDimension else {
            throw DomainError.imageTooSmall
        }
        
        // Delegate to repository (which handles AI call + local persistence)
        return try await repository.analyzeImage(image, dogProfile: dogProfile)
    }
}

// MARK: - Get Analysis History Use Case

protocol GetAnalysisHistoryUseCaseProtocol {
    func execute(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult]
    func execute(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult]
}

final class GetAnalysisHistoryUseCase: GetAnalysisHistoryUseCaseProtocol {
    
    private let repository: PoopAnalysisRepositoryProtocol
    
    init(repository: PoopAnalysisRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult] {
        guard page >= 0, pageSize > 0 else { throw DomainError.invalidPaginationParameters }
        return try await repository.fetchHistory(page: page, pageSize: pageSize)
    }
    
    func execute(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult] {
        guard startDate <= endDate else { throw DomainError.invalidDateRange }
        return try await repository.fetchHistory(from: startDate, to: endDate)
    }
}

// MARK: - Delete Analysis Use Case

protocol DeleteAnalysisUseCaseProtocol {
    func execute(id: UUID) async throws
    func executeDeleteAll() async throws
}

final class DeleteAnalysisUseCase: DeleteAnalysisUseCaseProtocol {
    
    private let repository: PoopAnalysisRepositoryProtocol
    
    init(repository: PoopAnalysisRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(id: UUID) async throws {
        try await repository.deleteAnalysis(id: id)
    }
    
    func executeDeleteAll() async throws {
        try await repository.deleteAllAnalyses()
    }
}

// MARK: - Get Dog Profile Use Case

protocol GetDogProfileUseCaseProtocol {
    func execute() async throws -> DogProfile?
}

final class GetDogProfileUseCase: GetDogProfileUseCaseProtocol {
    
    private let repository: DogProfileRepositoryProtocol
    
    init(repository: DogProfileRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() async throws -> DogProfile? {
        try await repository.fetchPrimaryDogProfile()
    }
}

// MARK: - Save Dog Profile Use Case

protocol SaveDogProfileUseCaseProtocol {
    func execute(_ profile: DogProfile) async throws -> DogProfile
}

final class SaveDogProfileUseCase: SaveDogProfileUseCaseProtocol {
    
    private let repository: DogProfileRepositoryProtocol
    
    init(repository: DogProfileRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(_ profile: DogProfile) async throws -> DogProfile {
        guard !profile.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw DomainError.dogNameRequired
        }
        return try await repository.saveDogProfile(profile)
    }
}

// MARK: - Domain Errors

enum DomainError: LocalizedError {
    case imageTooSmall
    case invalidPaginationParameters
    case invalidDateRange
    case dogNameRequired
    case apiKeyNotConfigured
    case analysisNotFound
    
    var errorDescription: String? {
        switch self {
        case .imageTooSmall:
            return "The image is too small for reliable analysis. Please use a clearer photo."
        case .invalidPaginationParameters:
            return "Invalid page parameters."
        case .invalidDateRange:
            return "The start date must be before the end date."
        case .dogNameRequired:
            return "Please enter your dog's name."
        case .apiKeyNotConfigured:
            return "OpenAI API key is not configured. Please add it in Settings."
        case .analysisNotFound:
            return "The requested analysis could not be found."
        }
    }
}
