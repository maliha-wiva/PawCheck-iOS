import Foundation

// MARK: - Protocol

/// Abstraction over HTTP networking. Conforming types handle request building,
/// execution, and response decoding. Inject this protocol to enable easy mocking in tests.
protocol NetworkClientProtocol: AnyObject {
    func request<T: Decodable>(
        endpoint: EndpointProtocol,
        responseType: T.Type
    ) async throws -> T
    
    func requestRaw(endpoint: EndpointProtocol) async throws -> Data
}

// MARK: - Endpoint Protocol

protocol EndpointProtocol {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: Encodable? { get }
    var queryItems: [URLQueryItem]? { get }
    var timeoutInterval: TimeInterval { get }
}

extension EndpointProtocol {
    var queryItems: [URLQueryItem]? { nil }
    var timeoutInterval: TimeInterval { 60.0 }
    
    func buildURLRequest() throws -> URLRequest {
        guard var urlComponents = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }
        return request
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case noInternetConnection
    case timeout
    case unauthorized
    case serverError(statusCode: Int, message: String?)
    case decodingFailure(underlying: Error)
    case unknownError(underlying: Error)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "The URL is malformed."
        case .noInternetConnection:   return "No internet connection. Please try again."
        case .timeout:                return "The request timed out. Please retry."
        case .unauthorized:           return "Unauthorized. Check your API key in Settings."
        case .serverError(let code, let msg): return "Server error \(code): \(msg ?? "Unknown")"
        case .decodingFailure:        return "Failed to parse the server response."
        case .unknownError(let err):  return "Unexpected error: \(err.localizedDescription)"
        case .rateLimitExceeded:      return "API rate limit exceeded. Please wait and try again."
        }
    }
}

// MARK: - Implementation

final class NetworkClient: NetworkClientProtocol {
    
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func request<T: Decodable>(
        endpoint: EndpointProtocol,
        responseType: T.Type
    ) async throws -> T {
        let data = try await requestRaw(endpoint: endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailure(underlying: error)
        }
    }
    
    func requestRaw(endpoint: EndpointProtocol) async throws -> Data {
        let urlRequest = try endpoint.buildURLRequest()
        
        let (data, response) = try await performRequest(urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknownError(underlying: URLError(.badServerResponse))
        }
        
        try validateStatusCode(httpResponse.statusCode, data: data)
        return data
    }
    
    // MARK: - Private
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknownError(underlying: error)
        }
    }
    
    private func validateStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299: return
        case 401:       throw NetworkError.unauthorized
        case 429:       throw NetworkError.rateLimitExceeded
        case 500...599:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: statusCode, message: message)
        default:
            let message = String(data: data, encoding: .utf8)
            throw NetworkError.serverError(statusCode: statusCode, message: message)
        }
    }
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .timeout
        default:
            return .unknownError(underlying: error)
        }
    }
}
