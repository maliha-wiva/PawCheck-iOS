import Foundation
import Combine

// MARK: - View State

/// Generic view state enum used across all screens.
/// Parameterized to carry screen-specific data payloads.
enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case empty
    case failure(AppError)
}

// MARK: - App Error

/// Unified error type for the presentation layer.
/// Wraps domain/network errors into user-friendly messages.
struct AppError: LocalizedError, Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    let isRetryable: Bool
    
    init(
        id: UUID = UUID(),
        title: String = "Something Went Wrong",
        message: String,
        isRetryable: Bool = true
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
    
    var errorDescription: String? { message }
    
    /// Maps any Error into a user-facing AppError.
    static func from(_ error: Error) -> AppError {
        if let domainError = error as? DomainError {
            return AppError(
                title: "Oops!",
                message: domainError.localizedDescription,
                isRetryable: true
            )
        }
        if let networkError = error as? NetworkError {
            return AppError(
                title: networkErrorTitle(for: networkError),
                message: networkError.localizedDescription,
                isRetryable: {
                    if case .unauthorized = networkError { return false }
                    return true
                }()
            )
        }
        return AppError(message: error.localizedDescription)
    }
    
    private static func networkErrorTitle(for error: NetworkError) -> String {
        switch error {
        case .noInternetConnection: return "No Connection"
        case .unauthorized:         return "Authentication Error"
        case .rateLimitExceeded:    return "Rate Limit Reached"
        case .timeout:              return "Request Timed Out"
        default:                    return "Network Error"
        }
    }
    
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Base ViewModel

/// Base class providing common @MainActor-safe state management for all ViewModels.
/// Centralizes error handling, loading state, and Combine cancellable management.
@MainActor
class BaseViewModel: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var alertError: AppError? = nil
    
    var cancellables = Set<AnyCancellable>()
    
    /// Executes an async operation with automatic loading state management and error handling.
    /// - Parameters:
    ///   - showLoading: Whether to set isLoading = true during execution.
    ///   - operation: The async throwing work to perform.
    ///   - onSuccess: Optional callback on success.
    func perform(
        showLoading: Bool = true,
        _ operation: @escaping () async throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        Task {
            if showLoading { isLoading = true }
            defer { if showLoading { isLoading = false } }
            
            do {
                try await operation()
                onSuccess?()
            } catch {
                alertError = AppError.from(error)
            }
        }
    }
}

