import Foundation
import Combine

@MainActor
final class AnalysisResultViewModel: BaseViewModel {
    
    // MARK: - Published State
    
    @Published var result: PoopAnalysisResult
    @Published var isDeleted: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    
    // MARK: - Dependencies
    
    private let deleteAnalysisUseCase: DeleteAnalysisUseCaseProtocol
    
    // MARK: - Init
    
    init(result: PoopAnalysisResult, deleteAnalysisUseCase: DeleteAnalysisUseCaseProtocol) {
        self.result = result
        self.deleteAnalysisUseCase = deleteAnalysisUseCase
        super.init()
    }
    
    // MARK: - Computed Properties
    
    var healthScoreGrade: String {
        result.overallHealthScore?.tier.rawValue ?? "N/A"
    }
    
    var sortedRecommendations: [HealthRecommendation] {
        result.recommendations.sorted { $0.priority > $1.priority }
    }
    
    var urgentRecommendations: [HealthRecommendation] {
        result.recommendations.filter { $0.priority == .urgent }
    }
    
    var hasUrgentConcerns: Bool {
        !urgentRecommendations.isEmpty ||
        result.healthIndicators?.hasBlood == true ||
        result.healthIndicators?.hasParasites == true
    }
    
    // MARK: - Intents
    
    func onDeleteTapped() {
        showDeleteConfirmation = true
    }
    
    func onConfirmDelete() {
        perform {
            try await self.deleteAnalysisUseCase.execute(id: self.result.id)
            await MainActor.run { self.isDeleted = true }
        }
    }
}
