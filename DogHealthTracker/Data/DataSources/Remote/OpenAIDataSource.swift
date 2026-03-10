import Foundation
import UIKit
internal import os

// MARK: - Protocol

protocol OpenAIDataSourceProtocol: AnyObject {
    func analyzePoopImage(_ image: UIImage, dogContext: DogProfile?) async throws -> OpenAIAnalysisDTO
}

// MARK: - Endpoint

struct OpenAIVisionEndpoint: EndpointProtocol {
    let apiKey: String
    let requestBody: OpenAIRequestDTO
    
    var baseURL: String { "https://api.openai.com" }
    var path: String { "/v1/chat/completions" }
    var method: HTTPMethod { .POST }
    var timeoutInterval: TimeInterval { 90.0 }  // Vision requests can be slow
    
    var headers: [String: String] {
        [
            "Content-Type":  "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    var body: Encodable? { requestBody }
}

// MARK: - Implementation

final class OpenAIDataSource: OpenAIDataSourceProtocol {
    
    private let networkClient: NetworkClientProtocol
    private let promptBuilder: AnalysisPromptBuilderProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    
    init(
        networkClient: NetworkClientProtocol,
        promptBuilder: AnalysisPromptBuilderProtocol = AnalysisPromptBuilder(),
        settingsRepository: SettingsRepositoryProtocol = SettingsRepository(
            userDefaultsService: UserDefaultsService()
        )
    ) {
        self.networkClient = networkClient
        self.promptBuilder = promptBuilder
        self.settingsRepository = settingsRepository
    }
    
    func analyzePoopImage(_ image: UIImage, dogContext: DogProfile?) async throws -> OpenAIAnalysisDTO {
        guard settingsRepository.hasValidAPIKey else {
            throw DomainError.apiKeyNotConfigured
        }
        
        let apiKey = settingsRepository.loadSettings().openAIAPIKey
        
        // Compress image for API efficiency (max 1MB)
        guard let base64Image = image.compressedBase64(maxSizeKB: 1024) else {
            throw NetworkError.unknownError(underlying: NSError(
                domain: "ImageEncoding", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"]
            ))
        }
        
        let systemPrompt = promptBuilder.buildSystemPrompt()
        let userPrompt = promptBuilder.buildUserPrompt(dogContext: dogContext)
        
        let requestBody = OpenAIRequestDTO(
            model: "gpt-4o",
            messages: [
                OpenAIMessageDTO(
                    role: "system",
                    content: .text(systemPrompt)
                ),
                OpenAIMessageDTO(
                    role: "user",
                    content: .multipart([
                        .text(userPrompt),
                        .imageURL(OpenAIImageURLDTO(
                            url: "data:image/jpeg;base64,\(base64Image)",
                            detail: "high"
                        ))
                    ])
                )
            ],
            maxTokens: 2000,
            responseFormat: OpenAIResponseFormatDTO(type: "json_object")
        )
        
        let endpoint = OpenAIVisionEndpoint(apiKey: apiKey, requestBody: requestBody)
        let response: OpenAIResponseDTO = try await networkClient.request(
            endpoint: endpoint,
            responseType: OpenAIResponseDTO.self
        )
        
        guard let rawContent = response.choices.first?.message.content,
              case .text(let jsonString) = rawContent,
              let jsonData = jsonString.data(using: .utf8) else {
            throw NetworkError.decodingFailure(underlying: NSError(
                domain: "OpenAI", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No valid JSON content in response"]
            ))
        }
        // ─── RAW RESPONSE LOG ───────────────────────────────────────────────
                AppLogger.api.debug("""

                ╔══════════════════════════════════════════════════════╗
                ║           OpenAI Raw Response (pre-parse)           ║
                ╚══════════════════════════════════════════════════════╝
                \(jsonString, privacy: .public)
                ────────────────────────────────────────────────────────
                """)
                // ────────────────────────────────────────────────────────────────────
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let result = try decoder.decode(OpenAIAnalysisDTO.self, from: jsonData)
            AppLogger.api.info("OpenAI response parsed successfully.")
            return result
        } catch {
            AppLogger.api.error("""

            ╔══════════════════════════════════════════════════════╗
            ║              OpenAI Parsing FAILED                  ║
            ╚══════════════════════════════════════════════════════╝
            Error     : \(error.localizedDescription, privacy: .public)
            Raw JSON  : \(jsonString, privacy: .public)
            ────────────────────────────────────────────────────────
            """)
            throw NetworkError.decodingFailure(underlying: error)
        }
    }
}

// MARK: - Prompt Builder Protocol

protocol AnalysisPromptBuilderProtocol {
    func buildSystemPrompt() -> String
    func buildUserPrompt(dogContext: DogProfile?) -> String
}

// MARK: - Prompt Builder Implementation

/// Centralizes all AI prompt engineering.
/// Prompts are structured to return machine-readable JSON for reliable parsing.
final class AnalysisPromptBuilder: AnalysisPromptBuilderProtocol {
    
    func buildSystemPrompt() -> String {
        """
        You are a veterinary AI assistant specializing in canine digestive health analysis. \
        Your role is to analyze dog poop images and provide health insights to concerned pet owners.
        
        IMPORTANT GUIDELINES:
        1. You MUST respond with valid JSON only — no markdown, no extra text.
        2. You are NOT providing veterinary diagnoses. Always recommend consulting a vet for serious concerns.
        3. Be compassionate and clear in your recommendations.
        4. If the image does not contain dog poop, clearly indicate this.
        5. Base your analysis on established veterinary knowledge.
        
        REQUIRED JSON RESPONSE FORMAT:
        {
          "detection_status": "detected" | "not_detected" | "unclear",
          "detection_confidence": 0.0-1.0,
          "health_score": 0-100,
          "color": "brown" | "dark_brown" | "light_brown" | "yellow" | "green" | "red" | "black" | "white" | "orange" | "grey" | "unknown",
          "consistency": "solid" | "soft" | "loose" | "liquid" | "hard" | "very_hard" | "unknown",
          "shape": "log_like" | "segmented" | "pellets" | "amorphous" | "unknown",
          "size": "small" | "medium" | "large" | "very_large" | "unknown",
          "has_blood": true | false,
          "has_mucus": true | false,
          "has_parasites": true | false,
          "has_undigested_food": true | false,
          "additional_observations": ["string"],
          "recommendations": [
            {
              "priority": "low" | "medium" | "high" | "urgent",
              "category": "diet" | "hydration" | "veterinary" | "exercise" | "medication" | "monitoring" | "general",
              "title": "string",
              "description": "string",
              "action_items": ["string"]
            }
          ],
          "summary": "string"
        }
        """
    }
    
    func buildUserPrompt(dogContext: DogProfile?) -> String {
        var prompt = "Please analyze this dog poop image and provide a complete health assessment."
        
        if let dog = dogContext {
            prompt += "\n\nDog Context:"
            prompt += "\n- Name: \(dog.name)"
            if let breed = dog.breed   { prompt += "\n- Breed: \(breed)" }
            if let age = dog.ageYears  { prompt += "\n- Age: \(age) years" }
            if let weight = dog.weightKg { prompt += "\n- Weight: \(weight) kg" }
            if let sex = dog.sex       { prompt += "\n- Sex: \(sex.displayName)" }
            if let neutered = dog.isNeutered { prompt += "\n- Neutered: \(neutered ? "Yes" : "No")" }
            if let diet = dog.dietType { prompt += "\n- Diet: \(diet.displayName)" }
            if !dog.knownConditions.isEmpty {
                prompt += "\n- Known conditions: \(dog.knownConditions.joined(separator: ", "))"
            }
            if !dog.currentMedications.isEmpty {
                prompt += "\n- Current medications: \(dog.currentMedications.joined(separator: ", "))"
            }
        }
        
        prompt += "\n\nReturn only the JSON response as specified."
        return prompt
    }
}
