import Foundation

// MARK: - OpenAI Request DTOs

struct OpenAIRequestDTO: Encodable {
    let model: String
    let messages: [OpenAIMessageDTO]
    let maxTokens: Int
    let responseFormat: OpenAIResponseFormatDTO
    
    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(maxTokens, forKey: .maxTokens)
        try container.encode(responseFormat, forKey: .responseFormat)
    }
}

struct OpenAIMessageDTO: Encodable {
    let role: String
    let content: OpenAIContentDTO
}

enum OpenAIContentDTO: Encodable {
    case text(String)
    case multipart([OpenAIContentPartDTO])
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .multipart(let parts):
            try container.encode(parts)
        }
    }
}

enum OpenAIContentPartDTO: Encodable {
    case text(String)
    case imageURL(OpenAIImageURLDTO)
    
    enum CodingKeys: String, CodingKey {
        case type, text, imageUrl = "image_url"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let imageURL):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageURL, forKey: .imageUrl)
        }
    }
}

struct OpenAIImageURLDTO: Encodable {
    let url: String
    let detail: String
}

struct OpenAIResponseFormatDTO: Encodable {
    let type: String
}

// MARK: - OpenAI Response DTOs

struct OpenAIResponseDTO: Decodable {
    let id: String
    let choices: [OpenAIChoiceDTO]
    let usage: OpenAIUsageDTO?
}

struct OpenAIChoiceDTO: Decodable {
    let index: Int
    let message: OpenAIResponseMessageDTO
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIResponseMessageDTO: Decodable {
    let role: String
    let content: OpenAIContentDTO
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        let rawContent = try container.decode(String.self, forKey: .content)
        content = .text(rawContent)
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
}

struct OpenAIUsageDTO: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

// MARK: - Analysis Response DTO (parsed from AI JSON output)

/// Maps directly to the JSON schema defined in the system prompt.
/// No manual CodingKeys needed — the decoder uses .convertFromSnakeCase
/// which automatically maps e.g. "detection_status" -> detectionStatus.
/// Having both CodingKeys AND .convertFromSnakeCase causes "missing key" errors.
struct OpenAIAnalysisDTO: Decodable {
    let detectionStatus: String
    let detectionConfidence: Double
    let healthScore: Int
    let color: String
    let consistency: String
    let shape: String
    let size: String
    let hasBlood: Bool
    let hasMucus: Bool
    let hasParasites: Bool
    let hasUndigestedFood: Bool
    let additionalObservations: [String]
    let recommendations: [OpenAIRecommendationDTO]
    let summary: String
}

/// Same rule — no CodingKeys, let .convertFromSnakeCase handle action_items -> actionItems.
struct OpenAIRecommendationDTO: Decodable {
    let priority: String
    let category: String
    let title: String
    let description: String
    let actionItems: [String]
}



//// MARK: - OpenAI Request DTOs
//
//struct OpenAIRequestDTO: Encodable {
//    let model: String
//    let messages: [OpenAIMessageDTO]
//    let maxTokens: Int
//    let responseFormat: OpenAIResponseFormatDTO
//    
//    enum CodingKeys: String, CodingKey {
//        case model, messages
//        case maxTokens = "max_tokens"
//        case responseFormat = "response_format"
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(model, forKey: .model)
//        try container.encode(messages, forKey: .messages)
//        try container.encode(maxTokens, forKey: .maxTokens)
//        try container.encode(responseFormat, forKey: .responseFormat)
//    }
//}
//
//struct OpenAIMessageDTO: Encodable {
//    let role: String
//    let content: OpenAIContentDTO
//}
//
//enum OpenAIContentDTO: Encodable {
//    case text(String)
//    case multipart([OpenAIContentPartDTO])
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        switch self {
//        case .text(let text):
//            try container.encode(text)
//        case .multipart(let parts):
//            try container.encode(parts)
//        }
//    }
//}
//
//enum OpenAIContentPartDTO: Encodable {
//    case text(String)
//    case imageURL(OpenAIImageURLDTO)
//    
//    enum CodingKeys: String, CodingKey {
//        case type, text, imageUrl = "image_url"
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        switch self {
//        case .text(let text):
//            try container.encode("text", forKey: .type)
//            try container.encode(text, forKey: .text)
//        case .imageURL(let imageURL):
//            try container.encode("image_url", forKey: .type)
//            try container.encode(imageURL, forKey: .imageUrl)
//        }
//    }
//}
//
//struct OpenAIImageURLDTO: Encodable {
//    let url: String
//    let detail: String
//}
//
//struct OpenAIResponseFormatDTO: Encodable {
//    let type: String
//}
//
//// MARK: - OpenAI Response DTOs
//
//struct OpenAIResponseDTO: Decodable {
//    let id: String
//    let choices: [OpenAIChoiceDTO]
//    let usage: OpenAIUsageDTO?
//}
//
//struct OpenAIChoiceDTO: Decodable {
//    let index: Int
//    let message: OpenAIResponseMessageDTO
//    let finishReason: String?
//    
//    enum CodingKeys: String, CodingKey {
//        case index, message
//        case finishReason = "finish_reason"
//    }
//}
//
//struct OpenAIResponseMessageDTO: Decodable {
//    let role: String
//    let content: OpenAIContentDTO
//    
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        role = try container.decode(String.self, forKey: .role)
//        let rawContent = try container.decode(String.self, forKey: .content)
//        content = .text(rawContent)
//    }
//    
//    enum CodingKeys: String, CodingKey {
//        case role, content
//    }
//}
//
//struct OpenAIUsageDTO: Decodable {
//    let promptTokens: Int
//    let completionTokens: Int
//    let totalTokens: Int
//}
//
//// MARK: - Analysis Response DTO (parsed from AI JSON output)
//
///// Maps directly to the JSON schema defined in the system prompt.
//struct OpenAIAnalysisDTO: Decodable {
//    let detectionStatus: String
//    let detectionConfidence: Double
//    let healthScore: Int
//    let color: String
//    let consistency: String
//    let shape: String
//    let size: String
//    let hasBlood: Bool
//    let hasMucus: Bool
//    let hasParasites: Bool
//    let hasUndigestedFood: Bool
//    let additionalObservations: [String]
//    let recommendations: [OpenAIRecommendationDTO]
//    let summary: String
//    
//    enum CodingKeys: String, CodingKey {
//        case detectionStatus        = "detection_status"
//        case detectionConfidence    = "detection_confidence"
//        case healthScore            = "health_score"
//        case color
//        case consistency
//        case shape
//        case size
//        case hasBlood               = "has_blood"
//        case hasMucus               = "has_mucus"
//        case hasParasites           = "has_parasites"
//        case hasUndigestedFood      = "has_undigested_food"
//        case additionalObservations = "additional_observations"
//        case recommendations
//        case summary
//    }
//}
//
//struct OpenAIRecommendationDTO: Decodable {
//    let priority: String
//    let category: String
//    let title: String
//    let description: String
//    let actionItems: [String]
//    
//    enum CodingKeys: String, CodingKey {
//        case priority
//        case category
//        case title
//        case description
//        case actionItems = "action_items"
//    }
//}
