import Foundation
import UIKit
import PhotosUI
import Combine

// MARK: - Home ViewModel

@MainActor
final class HomeViewModel: BaseViewModel {
    
    // MARK: - Published State
    
    @Published var dogProfile: DogProfile?
    @Published var analysisState: ViewState<PoopAnalysisResult> = .idle
    @Published var showImageSourcePicker: Bool = false
    @Published var showCamera: Bool = false
    @Published var showPhotoLibrary: Bool = false
    @Published var showAnalysisResult: Bool = false
    @Published var selectedImage: UIImage?
    @Published var analysisResult: PoopAnalysisResult?
    
    // MARK: - Dependencies
    
    private let analyzePoopUseCase: AnalyzePoopUseCaseProtocol
    private let getDogProfileUseCase: GetDogProfileUseCaseProtocol
    private let dogProfileStore: DogProfileStore
    
    // MARK: - Init
    
    init(
        analyzePoopUseCase: AnalyzePoopUseCaseProtocol,
        getDogProfileUseCase: GetDogProfileUseCaseProtocol,
        dogProfileStore: DogProfileStore
    ) {
        self.analyzePoopUseCase = analyzePoopUseCase
        self.getDogProfileUseCase = getDogProfileUseCase
        self.dogProfileStore = dogProfileStore
        super.init()
        loadDogProfile()
        
        // Observe shared store — whenever dog profile is saved anywhere,
        // Home screen updates automatically without any extra work
        dogProfileStore.$dogProfile
            .receive(on: DispatchQueue.main)
            .assign(to: &$dogProfile)
        
    }
    
    // MARK: - Intent Methods
    
    func onAnalyzeButtonTapped() {
        showImageSourcePicker = true
    }
    
    func onCameraSelected() {
        showCamera = true
    }
    
    func onPhotoLibrarySelected() {
        showPhotoLibrary = true
    }
    
    func onImageSelected(_ image: UIImage) {
        selectedImage = image
        analyzeImage(image)
    }
    
    func onDismissResult() {
        analysisState = .idle
        analysisResult = nil
        selectedImage = nil
        showAnalysisResult = false
    }
    
    func onRetryAnalysis() {
        guard let image = selectedImage else { return }
        analyzeImage(image)
    }
    
    // MARK: - Private
    
    private func loadDogProfile() {
        Task {
            let profile = try? await getDogProfileUseCase.execute()
            dogProfile = profile
            dogProfileStore.dogProfile = profile   // seed the store on first load
            
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        analysisState = .loading
        
        Task {
            do {
                let result = try await analyzePoopUseCase.execute(
                    image: image,
                    dogProfile: dogProfile
                )
                analysisResult = result
                analysisState = .success(result)
                showAnalysisResult = true
            } catch {
                analysisState = .failure(AppError.from(error))
                alertError = AppError.from(error)
            }
        }
    }
}
