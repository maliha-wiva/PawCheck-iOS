import Foundation
import UIKit

// MARK: - Poop Analysis Result

/// The core domain entity representing a complete poop health analysis.
/// This is framework-agnostic and lives purely in the domain layer.
struct PoopAnalysisResult: Identifiable, Equatable {
    let id: UUID
    let dogId: UUID?
    let capturedAt: Date
    let imageLocalPath: String
    let detectionStatus: DetectionStatus
    let healthIndicators: HealthIndicators?
    let overallHealthScore: HealthScore?
    let recommendations: [HealthRecommendation]
    let rawAIResponse: String
    
    init(
        id: UUID = UUID(),
        dogId: UUID? = nil,
        capturedAt: Date = Date(),
        imageLocalPath: String,
        detectionStatus: DetectionStatus,
        healthIndicators: HealthIndicators? = nil,
        overallHealthScore: HealthScore? = nil,
        recommendations: [HealthRecommendation] = [],
        rawAIResponse: String
    ) {
        self.id = id
        self.dogId = dogId
        self.capturedAt = capturedAt
        self.imageLocalPath = imageLocalPath
        self.detectionStatus = detectionStatus
        self.healthIndicators = healthIndicators
        self.overallHealthScore = overallHealthScore
        self.recommendations = recommendations
        self.rawAIResponse = rawAIResponse
    }
    
    /// Whether poop was successfully detected and analyzed
    var isAnalyzed: Bool {
        detectionStatus == .detected && healthIndicators != nil
    }
}

// MARK: - Detection Status

/// Represents whether poop was actually found in the submitted image.
enum DetectionStatus: String, Codable, CaseIterable {
    case detected       = "detected"
    case notDetected    = "not_detected"
    case unclear        = "unclear"
    case error          = "error"
    
    var userFacingTitle: String {
        switch self {
        case .detected:    return "Poop Detected ✓"
        case .notDetected: return "No Poop Found"
        case .unclear:     return "Image Unclear"
        case .error:       return "Analysis Failed"
        }
    }
    
    var userFacingMessage: String {
        switch self {
        case .detected:    return "Analysis complete! See your dog's health insights below."
        case .notDetected: return "We couldn't find any poop in this image. Please try again with a clearer photo."
        case .unclear:     return "The image quality is too low for accurate analysis. Please take a clearer photo."
        case .error:       return "Something went wrong during analysis. Please try again."
        }
    }
}

// MARK: - Health Indicators

/// Detailed health observations extracted from the poop image.
struct HealthIndicators: Equatable {
    let color: PoopColor
    let consistency: PoopConsistency
    let shape: PoopShape
    let size: PoopSize
    let hasBlood: Bool
    let hasMucus: Bool
    let hasParasites: Bool
    let hasUndigestedFood: Bool
    let odorLevel: OdorLevel?         // Optional: AI may not detect this from image
    let additionalObservations: [String]
}

// MARK: - Poop Color

enum PoopColor: String, Codable, CaseIterable {
    case brown          = "brown"
    case darkBrown      = "dark_brown"
    case lightBrown     = "light_brown"
    case yellow         = "yellow"
    case green          = "green"
    case red            = "red"
    case black          = "black"
    case white          = "white"
    case orange         = "orange"
    case grey           = "grey"
    case unknown        = "unknown"
    
    var healthSignificance: HealthSignificance {
        switch self {
        case .brown, .darkBrown, .lightBrown:
            return .normal
        case .yellow:
            return .monitor
        case .green:
            return .monitor
        case .red:
            return .urgent
        case .black:
            return .urgent
        case .white:
            return .concern
        case .orange:
            return .concern
        case .grey:
            return .concern
        case .unknown:
            return .unknown
        }
    }
    
    var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - Poop Consistency (Bristol Stool Scale adapted for dogs)

enum PoopConsistency: String, Codable, CaseIterable {
    case solid          = "solid"           // Ideal
    case soft           = "soft"            // Slightly concerning
    case loose          = "loose"           // Concerning
    case liquid         = "liquid"          // Diarrhea - urgent
    case hard           = "hard"            // Constipation
    case veryHard       = "very_hard"       // Severe constipation
    case unknown        = "unknown"
    
    var score: Int {
        switch self {
        case .solid:    return 5
        case .soft:     return 4
        case .loose:    return 2
        case .liquid:   return 1
        case .hard:     return 3
        case .veryHard: return 2
        case .unknown:  return 0
        }
    }
    
    var healthSignificance: HealthSignificance {
        switch self {
        case .solid:    return .normal
        case .soft:     return .monitor
        case .loose:    return .concern
        case .liquid:   return .urgent
        case .hard:     return .concern
        case .veryHard: return .urgent
        case .unknown:  return .unknown
        }
    }
    
    var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - Poop Shape

enum PoopShape: String, Codable, CaseIterable {
    case logLike        = "log_like"
    case segmented      = "segmented"
    case pellets        = "pellets"
    case amorphous      = "amorphous"
    case unknown        = "unknown"
    
    var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - Poop Size

enum PoopSize: String, Codable, CaseIterable {
    case small          = "small"
    case medium         = "medium"
    case large          = "large"
    case veryLarge      = "very_large"
    case unknown        = "unknown"
    
    var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - Odor Level

enum OdorLevel: String, Codable {
    case mild       = "mild"
    case moderate   = "moderate"
    case strong     = "strong"
    case unknown    = "unknown"
}

// MARK: - Health Score

/// A 0–100 composite health score for the current sample.
struct HealthScore: Equatable {
    let value: Int      // 0–100
    
    var tier: HealthScoreTier {
        switch value {
        case 80...100: return .excellent
        case 60...79:  return .good
        case 40...59:  return .fair
        case 20...39:  return .poor
        default:       return .critical
        }
    }
    
    var clamped: Int { max(0, min(100, value)) }
}

enum HealthScoreTier: String {
    case excellent  = "Excellent"
    case good       = "Good"
    case fair       = "Fair"
    case poor       = "Poor"
    case critical   = "Critical"
    
    var colorHex: String {
        switch self {
        case .excellent: return "#22C55E"
        case .good:      return "#84CC16"
        case .fair:      return "#F59E0B"
        case .poor:      return "#F97316"
        case .critical:  return "#EF4444"
        }
    }
}

// MARK: - Health Significance

enum HealthSignificance {
    case normal
    case monitor
    case concern
    case urgent
    case unknown
}

// MARK: - Health Recommendation

struct HealthRecommendation: Identifiable, Equatable {
    let id: UUID
    let priority: RecommendationPriority
    let category: RecommendationCategory
    let title: String
    let description: String
    let actionItems: [String]
    
    init(
        id: UUID = UUID(),
        priority: RecommendationPriority,
        category: RecommendationCategory,
        title: String,
        description: String,
        actionItems: [String] = []
    ) {
        self.id = id
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.actionItems = actionItems
    }
}

enum RecommendationPriority: String, CaseIterable, Comparable {
    case low      = "low"
    case medium   = "medium"
    case high     = "high"
    case urgent   = "urgent"
    
    static func < (lhs: RecommendationPriority, rhs: RecommendationPriority) -> Bool {
        let order: [RecommendationPriority] = [.low, .medium, .high, .urgent]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

enum RecommendationCategory: String, CaseIterable {
    case diet           = "diet"
    case hydration      = "hydration"
    case veterinary     = "veterinary"
    case exercise       = "exercise"
    case medication     = "medication"
    case monitoring     = "monitoring"
    case general        = "general"
    
    var icon: String {
        switch self {
        case .diet:         return "fork.knife"
        case .hydration:    return "drop.fill"
        case .veterinary:   return "cross.case.fill"
        case .exercise:     return "figure.walk"
        case .medication:   return "pill.fill"
        case .monitoring:   return "eye.fill"
        case .general:      return "info.circle.fill"
        }
    }
}

// MARK: - Dog Profile

/// Represents the user's dog. Used for contextual AI analysis.
struct DogProfile: Identifiable, Equatable {
    let id: UUID
    var name: String
    var breed: String?
    var ageYears: Int?
    var weightKg: Double?
    var sex: DogSex?
    var isNeutered: Bool?
    var profileImagePath: String?
    var knownConditions: [String]
    var currentMedications: [String]
    var dietType: DietType?
    
    init(
        id: UUID = UUID(),
        name: String,
        breed: String? = nil,
        ageYears: Int? = nil,
        weightKg: Double? = nil,
        sex: DogSex? = nil,
        isNeutered: Bool? = nil,
        profileImagePath: String? = nil,
        knownConditions: [String] = [],
        currentMedications: [String] = [],
        dietType: DietType? = nil
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.ageYears = ageYears
        self.weightKg = weightKg
        self.sex = sex
        self.isNeutered = isNeutered
        self.profileImagePath = profileImagePath
        self.knownConditions = knownConditions
        self.currentMedications = currentMedications
        self.dietType = dietType
    }
    
    static var empty: DogProfile {
        DogProfile(name: "")
    }
}

enum DogSex: String, CaseIterable, Codable {
    case male   = "male"
    case female = "female"
    
    var displayName: String { rawValue.capitalized }
}

enum DietType: String, CaseIterable, Codable {
    case kibble         = "kibble"
    case wetFood        = "wet_food"
    case rawFood        = "raw_food"
    case homemade       = "homemade"
    case mixed          = "mixed"
    
    var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
}

// MARK: - App Settings

struct AppSettings: Equatable {
    var openAIAPIKey: String
    var notificationsEnabled: Bool
    var reminderIntervalHours: Int
    var measurementSystem: MeasurementSystem
    var privacyModeEnabled: Bool
    var exportFormat: ExportFormat
    
    static var defaultSettings: AppSettings {
        AppSettings(
            openAIAPIKey: "REPLACE_IT_WITH_YOURS",
            notificationsEnabled: false,
            reminderIntervalHours: 24,
            measurementSystem: .metric,
            privacyModeEnabled: false,
            exportFormat: .pdf
        )
    }
}

enum MeasurementSystem: String, CaseIterable, Codable {
    case metric   = "metric"
    case imperial = "imperial"
    
    var displayName: String { rawValue.capitalized }
}

enum ExportFormat: String, CaseIterable, Codable {
    case pdf  = "pdf"
    case csv  = "csv"
    case json = "json"
    
    var displayName: String { rawValue.uppercased() }
}
