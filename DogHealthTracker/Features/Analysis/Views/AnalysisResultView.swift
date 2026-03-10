import SwiftUI

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    
    @StateObject var viewModel: AnalysisResultViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        detectionStatusBanner
                        
                        if viewModel.result.isAnalyzed {
                            healthScoreSection
                            indicatorsSection
                            alertsSection
                            recommendationsSection
                        }
                        
                        aiSummarySection
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.bottom, AppTheme.Spacing.xxxl)
                }
            }
            .navigationTitle("Analysis Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: onDismiss)
                        .font(AppTheme.Typography.body(.semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        viewModel.onDeleteTapped()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppTheme.Colors.destructive)
                    }
                }
            }
            .confirmationDialog(
                "Delete this analysis?",
                isPresented: $viewModel.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { viewModel.onConfirmDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the analysis and its image.")
            }
            .onChange(of: viewModel.isDeleted) { _, deleted in
                if deleted { onDismiss() }
            }
            .appAlert(error: $viewModel.alertError)
        }
    }
    
    // MARK: - Detection Banner
    
    private var detectionStatusBanner: some View {
        let status = viewModel.result.detectionStatus
        let color = AppTheme.Colors.detectionStatusColor(for: status)
        
        return CardView(padding: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.md) {
                // Captured image thumbnail
                if let image = loadImage(fromPath: viewModel.result.imageLocalPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(AppTheme.CornerRadius.medium)
                }
                
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: statusIcon(for: status))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.userFacingTitle)
                            .font(AppTheme.Typography.headline(.semibold))
                            .foregroundColor(color)
                        Text(viewModel.result.capturedAt, style: .date)
                            .font(AppTheme.Typography.footnote())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                
                if status != .detected {
                    Text(status.userFacingMessage)
                        .font(AppTheme.Typography.subheadline())
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, AppTheme.Spacing.lg)
    }
    
    // MARK: - Health Score
    
    private var healthScoreSection: some View {
        CardView {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Overall Health Score")
                        .font(AppTheme.Typography.headline(.semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if let score = viewModel.result.overallHealthScore {
                        Text(healthScoreDescription(for: score.tier))
                            .font(AppTheme.Typography.subheadline())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                if let score = viewModel.result.overallHealthScore {
                    HealthScoreRingView(score: score, size: 100)
                }
            }
        }
    }
    
    // MARK: - Health Indicators
    
    private var indicatorsSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            SectionHeader(title: "Health Indicators")
            
            if let indicators = viewModel.result.healthIndicators {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                    IndicatorCell(
                        title: "Color",
                        value: indicators.color.displayName,
                        icon: "circle.fill",
                        significance: indicators.color.healthSignificance
                    )
                    IndicatorCell(
                        title: "Consistency",
                        value: indicators.consistency.displayName,
                        icon: "water.waves",
                        significance: indicators.consistency.healthSignificance
                    )
                    IndicatorCell(
                        title: "Shape",
                        value: indicators.shape.displayName,
                        icon: "oval",
                        significance: .normal
                    )
                    IndicatorCell(
                        title: "Size",
                        value: indicators.size.displayName,
                        icon: "arrow.up.left.and.arrow.down.right",
                        significance: .normal
                    )
                }
            }
        }
    }
    
    // MARK: - Alerts Section
    
    @ViewBuilder
    private var alertsSection: some View {
        if viewModel.hasUrgentConcerns, let indicators = viewModel.result.healthIndicators {
            VStack(spacing: AppTheme.Spacing.lg) {
                SectionHeader(
                    title: "⚠️ Health Alerts",
                    subtitle: "Please consult a veterinarian promptly."
                )
                
                VStack(spacing: AppTheme.Spacing.sm) {
                    if indicators.hasBlood {
                        AlertRow(
                            icon: "exclamationmark.triangle.fill",
                            message: "Blood detected — seek veterinary care immediately",
                            color: AppTheme.Colors.destructive
                        )
                    }
                    if indicators.hasParasites {
                        AlertRow(
                            icon: "exclamationmark.triangle.fill",
                            message: "Possible parasites detected — veterinary examination required",
                            color: AppTheme.Colors.destructive
                        )
                    }
                    if indicators.hasMucus {
                        AlertRow(
                            icon: "info.circle.fill",
                            message: "Mucus present — monitor and consult vet if persistent",
                            color: AppTheme.Colors.warning
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Recommendations
    
    private var recommendationsSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            SectionHeader(
                title: "Recommendations",
                subtitle: "\(viewModel.sortedRecommendations.count) insights for your dog's health"
            )
            
            ForEach(viewModel.sortedRecommendations) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
    
    // MARK: - AI Summary
    
    private var aiSummarySection: some View {
        CardView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.Colors.primaryFallback)
                    Text("AI Summary")
                        .font(AppTheme.Typography.headline(.semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Text(viewModel.result.rawAIResponse)
                    .font(AppTheme.Typography.body())
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                Text("⚠️ This analysis is AI-generated and should not replace professional veterinary diagnosis.")
                    .font(AppTheme.Typography.caption())
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadImage(fromPath path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }
    
    private func statusIcon(for status: DetectionStatus) -> String {
        switch status {
        case .detected:    return "checkmark.circle.fill"
        case .notDetected: return "xmark.circle.fill"
        case .unclear:     return "questionmark.circle.fill"
        case .error:       return "exclamationmark.circle.fill"
        }
    }
    
    private func healthScoreDescription(for tier: HealthScoreTier) -> String {
        switch tier {
        case .excellent: return "Your dog appears to be in great digestive health!"
        case .good:      return "Digestive health looks good with minor things to watch."
        case .fair:      return "Some concerns detected. Monitor closely."
        case .poor:      return "Several issues found. Consult your vet soon."
        case .critical:  return "Urgent attention needed. See a vet immediately."
        }
    }
}

// MARK: - Supporting Views

private struct IndicatorCell: View {
    let title: String
    let value: String
    let icon: String
    let significance: HealthSignificance
    
    private var significanceColor: Color {
        switch significance {
        case .normal:  return AppTheme.Colors.success
        case .monitor: return AppTheme.Colors.warning
        case .concern: return Color(hex: "#F97316")
        case .urgent:  return AppTheme.Colors.destructive
        case .unknown: return AppTheme.Colors.textTertiary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(significanceColor)
                    .font(.system(size: 14))
                Text(title)
                    .font(AppTheme.Typography.caption(.medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            Text(value)
                .font(AppTheme.Typography.subheadline(.semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(significanceColor.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct AlertRow: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(message)
                .font(AppTheme.Typography.subheadline())
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .cornerRadius(AppTheme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct RecommendationCard: View {
    let recommendation: HealthRecommendation
    @State private var isExpanded = false
    
    var priorityColor: Color {
        AppTheme.Colors.priorityColor(for: recommendation.priority)
    }
    
    var body: some View {
        CardView(padding: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Header
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: recommendation.category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(priorityColor)
                        .frame(width: 36, height: 36)
                        .background(priorityColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.title)
                            .font(AppTheme.Typography.subheadline(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        IndicatorChip(
                            recommendation.priority.rawValue.capitalized,
                            color: priorityColor
                        )
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                
                // Expandable content
                if isExpanded {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text(recommendation.description)
                            .font(AppTheme.Typography.subheadline())
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if !recommendation.actionItems.isEmpty {
                            Divider()
                            Text("Action Steps")
                                .font(AppTheme.Typography.footnote(.semibold))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .textCase(.uppercase)
                            
                            ForEach(recommendation.actionItems, id: \.self) { item in
                                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                    Circle()
                                        .fill(priorityColor)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(item)
                                        .font(AppTheme.Typography.subheadline())
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}
