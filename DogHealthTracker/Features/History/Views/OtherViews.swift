import SwiftUI

// MARK: - History View

struct HistoryView: View {
    
    @StateObject var viewModel: HistoryViewModel
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                
                content
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !viewModel.results.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete All") {
                        viewModel.showDeleteAllConfirmation = true
                    }
                    .foregroundColor(AppTheme.Colors.destructive)
                    .font(AppTheme.Typography.subheadline())
                }
            }
        }
        .confirmationDialog(
            "Delete all analyses?",
            isPresented: $viewModel.showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { viewModel.deleteAll() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { viewModel.loadHistory() }
        .appAlert(error: $viewModel.alertError)
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(AppTheme.Typography.subheadline(viewModel.selectedFilter == filter ? .semibold : .regular))
                            .padding(.horizontal, AppTheme.Spacing.lg)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(viewModel.selectedFilter == filter
                                        ? AppTheme.Colors.primaryFallback
                                        : AppTheme.Colors.cardBackground)
                            .foregroundColor(viewModel.selectedFilter == filter
                                             ? .white
                                             : AppTheme.Colors.textSecondary)
                            .cornerRadius(AppTheme.CornerRadius.chip)
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.selectedFilter)
                }
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading history…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty, .idle:
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "No Analyses Yet",
                message: "Your analysis history will appear here after your first scan."
            )
        case .success, .failure:
            if viewModel.filteredResults.isEmpty {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Results",
                    message: "No analyses match the selected filter."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        ForEach(viewModel.filteredResults) { result in
                            NavigationLink {
                                AnalysisResultView(
                                    viewModel: AnalysisResultViewModel(
                                        result: result,
                                        deleteAnalysisUseCase: DeleteAnalysisUseCase(
                                            repository: PoopAnalysisRepository(
                                                remoteDataSource: OpenAIDataSource(networkClient: NetworkClient()),
                                                localDataSource: AnalysisLocalDataSource(storageService: CoreDataStorageService()),
                                                imageStorageService: FileSystemImageStorageService()
                                            )
                                        )
                                    ),
                                    onDismiss: {}
                                )
                            } label: {
                                HistoryItemRow(result: result)
                            }
                            .onAppear { viewModel.loadMoreIfNeeded(currentItem: result) }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
            }
        }
    }
}

// MARK: - History Item Row

private struct HistoryItemRow: View {
    let result: PoopAnalysisResult
    
    var body: some View {
        CardView(padding: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Thumbnail or status icon
                Group {
                    if let image = UIImage(contentsOfFile: result.imageLocalPath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.Colors.divider)
                    }
                }
                .frame(width: 60, height: 60)
                .clipped()
                .cornerRadius(AppTheme.CornerRadius.small)
                
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text(result.detectionStatus.userFacingTitle)
                            .font(AppTheme.Typography.subheadline(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        if let score = result.overallHealthScore {
                            Text("\(score.clamped)")
                                .font(AppTheme.Typography.subheadline(.bold))
                                .foregroundColor(AppTheme.Colors.healthScoreColor(for: score.tier))
                        }
                    }
                    
                    Text(result.capturedAt, style: .relative)
                        .font(AppTheme.Typography.footnote())
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if result.isAnalyzed {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            if let indicators = result.healthIndicators {
                                IndicatorChip(indicators.color.displayName, color: AppTheme.Colors.textSecondary)
                                IndicatorChip(indicators.consistency.displayName, color: AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Dog Profile View

struct DogProfileView: View {
    
    @StateObject var viewModel: DogProfileViewModel
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            Form {
                Section("Basic Info") {
                    LabeledTextField(label: "Name *", text: $viewModel.profile.name, placeholder: "e.g. Buddy")
                    LabeledTextField(label: "Breed", text: Binding(
                        get: { viewModel.profile.breed ?? "" },
                        set: { viewModel.profile.breed = $0.isEmpty ? nil : $0 }
                    ), placeholder: "e.g. Labrador")
                    
                    Stepper(
                        "Age: \(viewModel.profile.ageYears.map { "\($0) yr\($0 == 1 ? "" : "s")" } ?? "Unknown")",
                        value: Binding(
                            get: { viewModel.profile.ageYears ?? 0 },
                            set: { viewModel.profile.ageYears = $0 == 0 ? nil : $0 }
                        ),
                        in: 0...30
                    )
                }
                
                Section("Physical Details") {
                    Picker("Sex", selection: Binding(
                        get: { viewModel.profile.sex },
                        set: { viewModel.profile.sex = $0 }
                    )) {
                        Text("Unknown").tag(Optional<DogSex>.none)
                        ForEach(DogSex.allCases, id: \.self) { sex in
                            Text(sex.displayName).tag(Optional(sex))
                        }
                    }
                    
                    Picker("Diet Type", selection: Binding(
                        get: { viewModel.profile.dietType },
                        set: { viewModel.profile.dietType = $0 }
                    )) {
                        Text("Not specified").tag(Optional<DietType>.none)
                        ForEach(DietType.allCases, id: \.self) { diet in
                            Text(diet.displayName).tag(Optional(diet))
                        }
                    }
                }
                
                Section("Health Context") {
                    Text("Add known conditions and medications to improve AI analysis accuracy.")
                        .font(AppTheme.Typography.footnote())
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Section {
                    if viewModel.isSaved {
                        HStack {
                            Spacer()
                            HStack(spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.success)
                                Text("Profile Saved!")
                                    .font(AppTheme.Typography.subheadline(.semibold))
                                    .foregroundColor(AppTheme.Colors.success)
                            }
                            .transition(.scale.combined(with: .opacity))
                            Spacer()
                        }
                        .listRowBackground(AppTheme.Colors.success.opacity(0.08))
                    } else if viewModel.hasUnsavedChanges {
                        PrimaryButton(
                            "Save Profile",
                            icon: "checkmark",
                            isLoading: viewModel.isLoading,
                            action: viewModel.onSaveTapped
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.hasUnsavedChanges)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isSaved)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("My Dog")
        .appAlert(error: $viewModel.alertError)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    
    @StateObject var viewModel: SettingsViewModel
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()
            
            Form {
                Section {
                    HStack {
                        Image(systemName: viewModel.hasValidAPIKey ? "checkmark.seal.fill" : "key.fill")
                            .foregroundColor(viewModel.hasValidAPIKey ? AppTheme.Colors.success : AppTheme.Colors.warning)
                        VStack(alignment: .leading) {
                            Text("OpenAI API Key")
                                .font(AppTheme.Typography.subheadline(.semibold))
                            Text(viewModel.hasValidAPIKey ? "Configured ✓" : "Required for analysis")
                                .font(AppTheme.Typography.footnote())
                                .foregroundColor(viewModel.hasValidAPIKey
                                                 ? AppTheme.Colors.success
                                                 : AppTheme.Colors.warning)
                        }
                        Spacer()
                        Button { viewModel.onToggleAPIKeyVisibility() } label: {
                            Image(systemName: viewModel.isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    if viewModel.isAPIKeyVisible {
                        SecureField("sk-...", text: $viewModel.settings.openAIAPIKey)
                            .font(AppTheme.Typography.footnote())
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("AI Configuration")
                } footer: {
                    Text("Your API key is stored locally and never shared. Get yours at platform.openai.com")
                }
                
                Section("Preferences") {
                    Picker("Measurement System", selection: $viewModel.settings.measurementSystem) {
                        ForEach(MeasurementSystem.allCases, id: \.self) { system in
                            Text(system.displayName).tag(system)
                        }
                    }
                    
                    Toggle("Enable Notifications", isOn: $viewModel.settings.notificationsEnabled)
                }
                
                Section("Privacy") {
                    Toggle("Privacy Mode", isOn: $viewModel.settings.privacyModeEnabled)
                        .tint(AppTheme.Colors.primaryFallback)
                }
                
                Section {
                    PrimaryButton(
                        "Save Settings",
                        icon: "checkmark",
                        action: viewModel.onSaveSettings
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    
                    Button(role: .destructive) {
                        viewModel.showResetConfirmation = true
                    } label: {
                        Text("Reset to Defaults")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(AppTheme.Colors.destructive)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset all settings?",
            isPresented: $viewModel.showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { viewModel.onResetToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
        .appAlert(error: $viewModel.alertError)
    }
}

// MARK: - Helper Components

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTheme.Typography.footnote(.medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            TextField(placeholder, text: $text)
                .font(AppTheme.Typography.body())
        }
    }
}
