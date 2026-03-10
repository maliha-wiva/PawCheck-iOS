import SwiftUI
import PhotosUI

// MARK: - Home View

struct HomeView: View {
    
    @StateObject var viewModel: HomeViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    headerSection
                    dogGreetingCard
                    analyzeSection
                    quickTipsSection
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.xxxl)
            }
            
            // Loading overlay during AI analysis
            if case .loading = viewModel.analysisState {
                LoadingOverlayView(message: "Analyzing with AI…\nThis may take a moment")
            }
        }
        .navigationTitle("Dog Health Tracker")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.primaryFallback)
            }
        }
        // Image source action sheet
        .confirmationDialog(
            "Choose Photo Source",
            isPresented: $viewModel.showImageSourcePicker,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { viewModel.onCameraSelected() }
            Button("Choose from Library") { viewModel.onPhotoLibrarySelected() }
            Button("Cancel", role: .cancel) {}
        }
        // Camera
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(onImageCaptured: { image in
                viewModel.showCamera = false
                viewModel.onImageSelected(image)
            }, onCancel: {
                viewModel.showCamera = false
            })
        }
        // Photo library
        .photosPicker(
            isPresented: $viewModel.showPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.onImageSelected(image)
                }
                selectedPhotoItem = nil
            }
        }
        // Analysis result sheet
        .sheet(isPresented: $viewModel.showAnalysisResult) {
            if let result = viewModel.analysisResult {
                AnalysisResultView(
                    viewModel: AnalysisResultViewModel(
                        result: result,
                        deleteAnalysisUseCase: DeleteAnalysisUseCase(
                            repository: PoopAnalysisRepository(
                                remoteDataSource: OpenAIDataSource(
                                    networkClient: NetworkClient()
                                ),
                                localDataSource: AnalysisLocalDataSource(
                                    storageService: CoreDataStorageService()
                                ),
                                imageStorageService: FileSystemImageStorageService()
                            )
                        )
                    ),
                    onDismiss: viewModel.onDismissResult
                )
            }
        }
        .appAlert(error: $viewModel.alertError, onRetry: viewModel.onRetryAnalysis)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(greeting)
                    .font(AppTheme.Typography.callout())
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("Ready to check on \(viewModel.dogProfile?.name ?? "your pup")?")
                    .font(AppTheme.Typography.title3(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.top, AppTheme.Spacing.sm)
    }
    
    private var dogGreetingCard: some View {
        CardView {
            HStack(spacing: AppTheme.Spacing.lg) {
                // Dog avatar
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primaryFallback.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 26))
                        .foregroundColor(AppTheme.Colors.primaryFallback)
                }
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    if let dog = viewModel.dogProfile {
                        Text(dog.name)
                            .font(AppTheme.Typography.headline(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: AppTheme.Spacing.sm) {
                            if let breed = dog.breed {
                                IndicatorChip(breed, color: AppTheme.Colors.secondary)
                            }
                            if let age = dog.ageYears {
                                IndicatorChip("\(age) yr\(age == 1 ? "" : "s")", color: AppTheme.Colors.primaryFallback)
                            }
                        }
                    } else {
                        Text("No dog profile yet")
                            .font(AppTheme.Typography.headline())
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Add your dog's info for better analysis")
                            .font(AppTheme.Typography.subheadline())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
            }
        }
    }
    
    private var analyzeSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            SectionHeader(
                title: "New Analysis",
                subtitle: "Take or upload a photo of your dog's poop for AI-powered health insights."
            )
            
            // Preview of selected image (if any before result shown)
            if let image = viewModel.selectedImage, case .loading = viewModel.analysisState {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(AppTheme.CornerRadius.large)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                            .stroke(AppTheme.Colors.divider, lineWidth: 1)
                    )
            }
            
            PrimaryButton(
                "Analyze Poop",
                icon: "camera.fill",
                isLoading: {
                    if case .loading = viewModel.analysisState { return true }
                    return false
                }(),
                action: viewModel.onAnalyzeButtonTapped
            )
            
            // Disclaimer
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Text("AI analysis is not a substitute for professional veterinary care.")
                    .font(AppTheme.Typography.caption())
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var quickTipsSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            SectionHeader(title: "Quick Tips")
            
            VStack(spacing: AppTheme.Spacing.md) {
                ForEach(quickTips, id: \.title) { tip in
                    QuickTipRow(tip: tip)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning 🌅"
        case 12..<17: return "Good afternoon ☀️"
        case 17..<21: return "Good evening 🌇"
        default:      return "Good night 🌙"
        }
    }
    
    private var quickTips: [QuickTip] {
        [
            QuickTip(icon: "camera.macro", title: "Good Lighting", description: "Take photos in natural light for best results."),
            QuickTip(icon: "arrow.up.left.and.arrow.down.right", title: "Clear Frame", description: "Ensure the entire sample is visible."),
            QuickTip(icon: "calendar", title: "Track Regularly", description: "Daily checks help identify patterns over time.")
        ]
    }
}

// MARK: - Quick Tip Row

private struct QuickTip {
    let icon: String
    let title: String
    let description: String
}

private struct QuickTipRow: View {
    let tip: QuickTip
    
    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: tip.icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.Colors.primaryFallback)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.primaryFallback.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(AppTheme.Typography.subheadline(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(tip.description)
                    .font(AppTheme.Typography.footnote())
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
    }
}
