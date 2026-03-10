import Foundation

// MARK: - OpenAI Analysis Mapper

/// Converts raw AI response DTOs into clean domain entities.
/// All data cleaning and defaulting happens here, keeping domain entities pure.
struct OpenAIAnalysisMapper {
    
    static func map(
        dto: OpenAIAnalysisDTO,
        imageLocalPath: String,
        dogId: UUID?
    ) -> PoopAnalysisResult {
        
        let detectionStatus = DetectionStatus(rawValue: dto.detectionStatus) ?? .error
        
        var healthIndicators: HealthIndicators?
        var healthScore: HealthScore?
        var recommendations: [HealthRecommendation] = []
        
        if detectionStatus == .detected {
            healthIndicators = mapHealthIndicators(from: dto)
            healthScore = HealthScore(value: max(0, min(100, dto.healthScore)))
            recommendations = dto.recommendations.compactMap { mapRecommendation(from: $0) }
        }
        
        return PoopAnalysisResult(
            imageLocalPath: imageLocalPath,
            detectionStatus: detectionStatus,
            healthIndicators: healthIndicators,
            overallHealthScore: healthScore,
            recommendations: recommendations.sorted { $0.priority > $1.priority },
            rawAIResponse: dto.summary
        )
    }
    
    // MARK: - Private Helpers
    
    private static func mapHealthIndicators(from dto: OpenAIAnalysisDTO) -> HealthIndicators {
        HealthIndicators(
            color:                  PoopColor(rawValue: dto.color) ?? .unknown,
            consistency:            PoopConsistency(rawValue: dto.consistency) ?? .unknown,
            shape:                  PoopShape(rawValue: dto.shape) ?? .unknown,
            size:                   PoopSize(rawValue: dto.size) ?? .unknown,
            hasBlood:               dto.hasBlood,
            hasMucus:               dto.hasMucus,
            hasParasites:           dto.hasParasites,
            hasUndigestedFood:      dto.hasUndigestedFood,
            odorLevel:              nil,    // Not provided by vision model
            additionalObservations: dto.additionalObservations
        )
    }
    
    private static func mapRecommendation(from dto: OpenAIRecommendationDTO) -> HealthRecommendation? {
        guard let priority = RecommendationPriority(rawValue: dto.priority),
              let category = RecommendationCategory(rawValue: dto.category) else {
            return nil
        }
        return HealthRecommendation(
            priority:    priority,
            category:    category,
            title:       dto.title,
            description: dto.description,
            actionItems: dto.actionItems
        )
    }
}
