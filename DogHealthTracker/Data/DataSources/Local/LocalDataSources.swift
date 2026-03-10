import Foundation
import UIKit

// MARK: - Local Data Source Protocols

protocol AnalysisLocalDataSourceProtocol: AnyObject {
    func saveAnalysis(_ result: PoopAnalysisResult) async throws
    func fetchAnalyses(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult]
    func fetchAnalyses(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult]
    func fetchAnalysis(byId id: UUID) async throws -> PoopAnalysisResult?
    func deleteAnalysis(id: UUID) async throws
    func deleteAllAnalyses() async throws
    func fetchAnalysisCount() async throws -> Int
}

protocol DogProfileLocalDataSourceProtocol: AnyObject {
    func fetchPrimaryDogProfile() async throws -> DogProfile?
    func fetchAllDogProfiles() async throws -> [DogProfile]
    func saveDogProfile(_ profile: DogProfile) async throws
    func deleteDogProfile(id: UUID) async throws
}

// MARK: - Storage Service Protocols

protocol LocalStorageServiceProtocol: AnyObject {
    func save<T: Encodable>(_ object: T, key: String) throws
    func load<T: Decodable>(key: String, type: T.Type) throws -> T?
    func delete(key: String) throws
    func loadAll<T: Decodable>(prefix: String, type: T.Type) throws -> [T]
}

protocol UserDefaultsServiceProtocol: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func removeObject(forKey key: String)
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func integer(forKey key: String) -> Int
}

protocol ImageStorageServiceProtocol: AnyObject {
    func saveImage(_ image: UIImage, fileName: String) throws -> String
    func loadImage(fromPath path: String) -> UIImage?
    func deleteImage(atPath path: String) throws
}

// MARK: - CoreData Storage Service (Simplified with JSON file storage for demonstration)
// In production: Replace with actual CoreData or SwiftData implementation

final class CoreDataStorageService: LocalStorageServiceProtocol {
    
    private let storageDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.storageDirectory = documentsDir.appendingPathComponent("DogHealthData", isDirectory: true)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
    }
    
    func save<T: Encodable>(_ object: T, key: String) throws {
        let data = try encoder.encode(object)
        let url = storageDirectory.appendingPathComponent("\(key).json")
        try data.write(to: url, options: .atomicWrite)
    }
    
    func load<T: Decodable>(key: String, type: T.Type) throws -> T? {
            let url = storageDirectory.appendingPathComponent("\(key).json")
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // File exists but is corrupted or schema changed — delete it and start fresh
                // rather than crashing the app with "data missing" errors
                try? FileManager.default.removeItem(at: url)
                return nil
            }
        }
    
    func delete(key: String) throws {
        let url = storageDirectory.appendingPathComponent("\(key).json")
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func loadAll<T: Decodable>(prefix: String, type: T.Type) throws -> [T] {
        let files = try FileManager.default.contentsOfDirectory(
            at: storageDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        return files
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? self.decoder.decode(T.self, from: data)
            }
    }
}

// MARK: - UserDefaults Service

final class UserDefaultsService: UserDefaultsServiceProtocol {
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func data(forKey key: String) -> Data?           { defaults.data(forKey: key) }
    func set(_ data: Data, forKey key: String)       { defaults.set(data, forKey: key) }
    func removeObject(forKey key: String)            { defaults.removeObject(forKey: key) }
    func string(forKey key: String) -> String?       { defaults.string(forKey: key) }
    func bool(forKey key: String) -> Bool            { defaults.bool(forKey: key) }
    func integer(forKey key: String) -> Int          { defaults.integer(forKey: key) }
}

// MARK: - Image Storage Service

final class FileSystemImageStorageService: ImageStorageServiceProtocol {
    
    private let imageDirectory: URL
    
    init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.imageDirectory = documentsDir.appendingPathComponent("DogImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
    }
    
    func saveImage(_ image: UIImage, fileName: String) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw ImageStorageError.encodingFailed
        }
        let fileURL = imageDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomicWrite)
        return fileURL.path
    }
    
    func loadImage(fromPath path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
    
    func deleteImage(atPath path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.removeItem(atPath: path)
    }
}

enum ImageStorageError: LocalizedError {
    case encodingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode image for storage."
        case .fileNotFound:   return "Image file not found."
        }
    }
}

// MARK: - Persisted Analysis DTO (for JSON serialization)

private struct PersistedAnalysis: Codable {
    let id: String
    let dogId: String?
    let capturedAt: Date
    let imageLocalPath: String
    let detectionStatus: String
    let healthScore: Int?
    let color: String?
    let consistency: String?
    let shape: String?
    let size: String?
    let hasBlood: Bool
    let hasMucus: Bool
    let hasParasites: Bool
    let hasUndigestedFood: Bool
    let additionalObservations: [String]
    let recommendations: [PersistedRecommendation]
    let rawAIResponse: String
}

private struct PersistedRecommendation: Codable {
    let id: String
    let priority: String
    let category: String
    let title: String
    let description: String
    let actionItems: [String]
}

// MARK: - Analysis Local Data Source

final class AnalysisLocalDataSource: AnalysisLocalDataSourceProtocol {
    
    private let storageService: LocalStorageServiceProtocol
    private let keyPrefix = "analysis_"
    
    init(storageService: LocalStorageServiceProtocol) {
        self.storageService = storageService
    }
    
    func saveAnalysis(_ result: PoopAnalysisResult) async throws {
        let persisted = toPersistedModel(result)
        let key = "\(keyPrefix)\(result.id.uuidString)"
        try storageService.save(persisted, key: key)
    }
    
    func fetchAnalyses(page: Int, pageSize: Int) async throws -> [PoopAnalysisResult] {
        let all: [PersistedAnalysis] = (try? storageService.loadAll(prefix: keyPrefix, type: PersistedAnalysis.self)) ?? []
        let start = page * pageSize
        guard start < all.count else { return [] }
        let end = min(start + pageSize, all.count)
        return all[start..<end].compactMap(toDomainModel)
    }
    
    func fetchAnalyses(from startDate: Date, to endDate: Date) async throws -> [PoopAnalysisResult] {
        let all: [PersistedAnalysis] = (try? storageService.loadAll(prefix: keyPrefix, type: PersistedAnalysis.self)) ?? []
        return all
            .filter { $0.capturedAt >= startDate && $0.capturedAt <= endDate }
            .compactMap(toDomainModel)
    }
    
    func fetchAnalysis(byId id: UUID) async throws -> PoopAnalysisResult? {
        let key = "\(keyPrefix)\(id.uuidString)"
        let persisted: PersistedAnalysis? = try storageService.load(key: key, type: PersistedAnalysis.self)
        return persisted.flatMap(toDomainModel)
    }
    
    func deleteAnalysis(id: UUID) async throws {
        let key = "\(keyPrefix)\(id.uuidString)"
        try storageService.delete(key: key)
    }
    
    func deleteAllAnalyses() async throws {
        let all: [PersistedAnalysis] = (try? storageService.loadAll(prefix: keyPrefix, type: PersistedAnalysis.self)) ?? []
        for analysis in all {
            try? storageService.delete(key: "\(keyPrefix)\(analysis.id)")
        }
    }
    
    func fetchAnalysisCount() async throws -> Int {
        let all: [PersistedAnalysis] = (try? storageService.loadAll(prefix: keyPrefix, type: PersistedAnalysis.self)) ?? []
        return all.count
    }
    
    // MARK: - Mapping
    
    private func toPersistedModel(_ result: PoopAnalysisResult) -> PersistedAnalysis {
        PersistedAnalysis(
            id:                     result.id.uuidString,
            dogId:                  result.dogId?.uuidString,
            capturedAt:             result.capturedAt,
            imageLocalPath:         result.imageLocalPath,
            detectionStatus:        result.detectionStatus.rawValue,
            healthScore:            result.overallHealthScore?.value,
            color:                  result.healthIndicators?.color.rawValue,
            consistency:            result.healthIndicators?.consistency.rawValue,
            shape:                  result.healthIndicators?.shape.rawValue,
            size:                   result.healthIndicators?.size.rawValue,
            hasBlood:               result.healthIndicators?.hasBlood ?? false,
            hasMucus:               result.healthIndicators?.hasMucus ?? false,
            hasParasites:           result.healthIndicators?.hasParasites ?? false,
            hasUndigestedFood:      result.healthIndicators?.hasUndigestedFood ?? false,
            additionalObservations: result.healthIndicators?.additionalObservations ?? [],
            recommendations:        result.recommendations.map {
                PersistedRecommendation(
                    id: $0.id.uuidString,
                    priority: $0.priority.rawValue,
                    category: $0.category.rawValue,
                    title: $0.title,
                    description: $0.description,
                    actionItems: $0.actionItems
                )
            },
            rawAIResponse:          result.rawAIResponse
        )
    }
    
    private func toDomainModel(_ persisted: PersistedAnalysis) -> PoopAnalysisResult? {
        guard let id = UUID(uuidString: persisted.id) else { return nil }
        let detectionStatus = DetectionStatus(rawValue: persisted.detectionStatus) ?? .error
        
        var healthIndicators: HealthIndicators?
        if detectionStatus == .detected {
            healthIndicators = HealthIndicators(
                color:                  PoopColor(rawValue: persisted.color ?? "") ?? .unknown,
                consistency:            PoopConsistency(rawValue: persisted.consistency ?? "") ?? .unknown,
                shape:                  PoopShape(rawValue: persisted.shape ?? "") ?? .unknown,
                size:                   PoopSize(rawValue: persisted.size ?? "") ?? .unknown,
                hasBlood:               persisted.hasBlood,
                hasMucus:               persisted.hasMucus,
                hasParasites:           persisted.hasParasites,
                hasUndigestedFood:      persisted.hasUndigestedFood,
                odorLevel:              nil,
                additionalObservations: persisted.additionalObservations
            )
        }
        
        return PoopAnalysisResult(
            id:                     id,
            dogId:                  persisted.dogId.flatMap { UUID(uuidString: $0) },
            capturedAt:             persisted.capturedAt,
            imageLocalPath:         persisted.imageLocalPath,
            detectionStatus:        detectionStatus,
            healthIndicators:       healthIndicators,
            overallHealthScore:     persisted.healthScore.map { HealthScore(value: $0) },
            recommendations:        persisted.recommendations.compactMap { rec in
                guard let recId = UUID(uuidString: rec.id),
                      let priority = RecommendationPriority(rawValue: rec.priority),
                      let category = RecommendationCategory(rawValue: rec.category) else { return nil }
                return HealthRecommendation(id: recId, priority: priority, category: category,
                                            title: rec.title, description: rec.description,
                                            actionItems: rec.actionItems)
            },
            rawAIResponse:          persisted.rawAIResponse
        )
    }
}

// MARK: - Dog Profile Local Data Source

final class DogProfileLocalDataSource: DogProfileLocalDataSourceProtocol {
    
    private let storageService: LocalStorageServiceProtocol
    private let primaryKey = "dog_profile_primary"
    
    init(storageService: LocalStorageServiceProtocol) {
        self.storageService = storageService
    }
    
    func fetchPrimaryDogProfile() async throws -> DogProfile? {
        try storageService.load(key: primaryKey, type: DogProfile.self)
    }
    
    func fetchAllDogProfiles() async throws -> [DogProfile] {
        guard let primary = try? storageService.load(key: primaryKey, type: DogProfile.self) else {
            return []
        }
        return [primary]
    }
    
    func saveDogProfile(_ profile: DogProfile) async throws {
        // Currently supports single primary dog profile.
        // Multi-dog support: use "dog_profile_\(profile.id.uuidString)" as key.
        try storageService.save(profile, key: primaryKey)
    }
    
    func deleteDogProfile(id: UUID) async throws {
        try storageService.delete(key: primaryKey)
    }
}

// MARK: - DogProfile Codable Extension

//extension DogProfile: Codable {
//    enum CodingKeys: String, CodingKey {
//        case id, name, breed, ageYears, weightKg, sex, isNeutered
//        case profileImagePath, knownConditions, currentMedications, dietType
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try container.decode(UUID.self, forKey: .id)
//        self.name = try container.decode(String.self, forKey: .name)
//        self.breed = try container.decodeIfPresent(String.self, forKey: .breed)
//        
////        if let ageDouble = try container.decodeIfPresent(Double.self, forKey: .ageYears) {
////            self.ageYears = ageDouble
////        } else if let ageInt = try container.decodeIfPresent(Int.self, forKey: .ageYears) {
////            self.ageYears = Double(ageInt)
////        } else {
////            self.ageYears = nil
////        }
//        
//        if let weightDouble = try container.decodeIfPresent(Double.self, forKey: .weightKg) {
//            self.weightKg = weightDouble
//        } else if let weightInt = try container.decodeIfPresent(Int.self, forKey: .weightKg) {
//            self.weightKg = Double(weightInt)
//        } else {
//            self.weightKg = nil
//        }
//        
//        if let sexEnum = try? container.decodeIfPresent(DogSex.self, forKey: .sex) {
//            self.sex = sexEnum
//        } else if let sexRaw = try container.decodeIfPresent(String.self, forKey: .sex) {
//            self.sex = DogSex(rawValue: sexRaw)
//        } else {
//            self.sex = nil
//        }
//        
//        self.isNeutered = try container.decodeIfPresent(Bool.self, forKey: .isNeutered) ?? false
//        self.profileImagePath = try container.decodeIfPresent(String.self, forKey: .profileImagePath)
//        self.knownConditions = try container.decodeIfPresent([String].self, forKey: .knownConditions) ?? []
//        self.currentMedications = try container.decodeIfPresent([String].self, forKey: .currentMedications) ?? []
//        
//        if let dietEnum = try? container.decodeIfPresent(DietType.self, forKey: .dietType) {
//            self.dietType = dietEnum
//        } else if let dietRaw = try container.decodeIfPresent(String.self, forKey: .dietType) {
//            self.dietType = DietType(rawValue: dietRaw)
//        } else {
//            self.dietType = nil
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(id, forKey: .id)
//        try container.encode(name, forKey: .name)
//        try container.encodeIfPresent(breed, forKey: .breed)
//        if let ageYears = ageYears { try container.encode(ageYears, forKey: .ageYears) }
//        if let weightKg = weightKg { try container.encode(weightKg, forKey: .weightKg) }
//        try container.encodeIfPresent(sex?.rawValue, forKey: .sex)
//        try container.encode(isNeutered, forKey: .isNeutered)
//        try container.encodeIfPresent(profileImagePath, forKey: .profileImagePath)
//        try container.encode(knownConditions, forKey: .knownConditions)
//        try container.encode(currentMedications, forKey: .currentMedications)
//        try container.encodeIfPresent(dietType?.rawValue, forKey: .dietType)
//    }
//}
extension DogProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, breed, ageYears, weightKg, sex, isNeutered
        case profileImagePath, knownConditions, currentMedications, dietType
    }

    // Manual decode so missing optional fields never crash with "data missing" error.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decodeIfPresent(UUID.self,    forKey: .id)               ?? UUID()
        name               = try c.decodeIfPresent(String.self,  forKey: .name)             ?? ""
        breed              = try c.decodeIfPresent(String.self,  forKey: .breed)
        ageYears           = try c.decodeIfPresent(Int.self,     forKey: .ageYears)
        weightKg           = try c.decodeIfPresent(Double.self,  forKey: .weightKg)
        sex                = try c.decodeIfPresent(DogSex.self,  forKey: .sex)
        isNeutered         = try c.decodeIfPresent(Bool.self,    forKey: .isNeutered)
        profileImagePath   = try c.decodeIfPresent(String.self,  forKey: .profileImagePath)
        knownConditions    = try c.decodeIfPresent([String].self, forKey: .knownConditions)    ?? []
        currentMedications = try c.decodeIfPresent([String].self, forKey: .currentMedications) ?? []
        dietType           = try c.decodeIfPresent(DietType.self, forKey: .dietType)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,                 forKey: .id)
        try c.encode(name,               forKey: .name)
        try c.encodeIfPresent(breed,              forKey: .breed)
        try c.encodeIfPresent(ageYears,           forKey: .ageYears)
        try c.encodeIfPresent(weightKg,           forKey: .weightKg)
        try c.encodeIfPresent(sex,                forKey: .sex)
        try c.encodeIfPresent(isNeutered,         forKey: .isNeutered)
        try c.encodeIfPresent(profileImagePath,   forKey: .profileImagePath)
        try c.encode(knownConditions,    forKey: .knownConditions)
        try c.encode(currentMedications, forKey: .currentMedications)
        try c.encodeIfPresent(dietType,           forKey: .dietType)
    }
}
extension AppSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case openAIAPIKey, notificationsEnabled, reminderIntervalHours
        case measurementSystem, privacyModeEnabled, exportFormat
    }

    public init(from decoder: Decoder) throws {
        let defaults = AppSettings.defaultSettings
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.openAIAPIKey = try container.decodeIfPresent(String.self, forKey: .openAIAPIKey) ?? defaults.openAIAPIKey
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? defaults.notificationsEnabled
        self.reminderIntervalHours = try container.decodeIfPresent(Int.self, forKey: .reminderIntervalHours) ?? defaults.reminderIntervalHours
        
        self.privacyModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .privacyModeEnabled) ?? defaults.privacyModeEnabled

        if let system = try? container.decodeIfPresent(MeasurementSystem.self, forKey: .measurementSystem) {
            self.measurementSystem = system
        } else if let rawSystem = try container.decodeIfPresent(String.self, forKey: .measurementSystem),
                  let system = MeasurementSystem(rawValue: rawSystem) {
            self.measurementSystem = system
        } else {
            self.measurementSystem = .metric
        }

        if let export = try? container.decodeIfPresent(ExportFormat.self, forKey: .exportFormat) {
            self.exportFormat = export
        } else if let rawExport = try container.decodeIfPresent(String.self, forKey: .exportFormat),
                  let export = ExportFormat(rawValue: rawExport) {
            self.exportFormat = export
        } else {
            self.exportFormat = .json
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(openAIAPIKey, forKey: .openAIAPIKey)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(reminderIntervalHours, forKey: .reminderIntervalHours)
        try container.encode(measurementSystem.rawValue, forKey: .measurementSystem)
        try container.encode(privacyModeEnabled, forKey: .privacyModeEnabled)
        try container.encode(exportFormat.rawValue, forKey: .exportFormat)
    }
}

//extension AppSettings: Codable {
//    enum CodingKeys: String, CodingKey {
//        case openAIAPIKey, notificationsEnabled, reminderIntervalHours
//        case measurementSystem, privacyModeEnabled, exportFormat
//    }
//
//    // Manual decode so missing fields fall back to defaults instead of crashing.
//    init(from decoder: Decoder) throws {
//        let defaults = AppSettings.defaultSettings
//        let c = try decoder.container(keyedBy: CodingKeys.self)
//        openAIAPIKey           = try c.decodeIfPresent(String.self,            forKey: .openAIAPIKey)           ?? defaults.openAIAPIKey
//        notificationsEnabled   = try c.decodeIfPresent(Bool.self,              forKey: .notificationsEnabled)   ?? defaults.notificationsEnabled
//        reminderIntervalHours  = try c.decodeIfPresent(Int.self,               forKey: .reminderIntervalHours)  ?? defaults.reminderIntervalHours
//        measurementSystem      = try c.decodeIfPresent(MeasurementSystem.self, forKey: .measurementSystem)      ?? defaults.measurementSystem
//        privacyModeEnabled     = try c.decodeIfPresent(Bool.self,              forKey: .privacyModeEnabled)     ?? defaults.privacyModeEnabled
//        exportFormat           = try c.decodeIfPresent(ExportFormat.self,      forKey: .exportFormat)           ?? defaults.exportFormat
//    }
//}

