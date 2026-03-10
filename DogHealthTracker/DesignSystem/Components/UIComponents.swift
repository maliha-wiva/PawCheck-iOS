import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(AppTheme.Typography.headline())
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isDisabled ? Color.gray.opacity(0.4) : AppTheme.Colors.primaryFallback)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.button)
            .shadow(
                color: AppTheme.Shadow.button.color,
                radius: AppTheme.Shadow.button.radius,
                x: AppTheme.Shadow.button.x,
                y: AppTheme.Shadow.button.y
            )
        }
        .disabled(isLoading || isDisabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Card View

struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat = AppTheme.Spacing.lg
    
    init(padding: CGFloat = AppTheme.Spacing.lg, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.card)
            .shadow(
                color: AppTheme.Shadow.card.color,
                radius: AppTheme.Shadow.card.radius,
                x: AppTheme.Shadow.card.x,
                y: AppTheme.Shadow.card.y
            )
    }
}

// MARK: - Health Score Ring

struct HealthScoreRingView: View {
    let score: HealthScore
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10
    
    private var progress: Double { Double(score.clamped) / 100.0 }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Colors.divider, lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    scoreColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            
            VStack(spacing: 2) {
                Text("\(score.clamped)")
                    .font(AppTheme.Typography.title2(.bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(score.tier.rawValue)
                    .font(AppTheme.Typography.caption())
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
    
    private var scoreColor: Color {
        AppTheme.Colors.healthScoreColor(for: score.tier)
    }
}

// MARK: - Indicator Chip

struct IndicatorChip: View {
    let label: String
    let icon: String?
    let color: Color
    var isAlert: Bool = false
    
    init(_ label: String, icon: String? = nil, color: Color = AppTheme.Colors.primary) {
        self.label = label
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(label)
                .font(AppTheme.Typography.caption(.medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(color.opacity(0.12))
        .cornerRadius(AppTheme.CornerRadius.chip)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(AppTheme.Typography.title3(.semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.subheadline())
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(AppTheme.Typography.title3(.semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text(message)
                    .font(AppTheme.Typography.body())
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xxxl)
            }
            
            if let actionTitle, let action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.horizontal, AppTheme.Spacing.xxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Loading Overlay

struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: AppTheme.Spacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.4)
                
                Text(message)
                    .font(AppTheme.Typography.subheadline(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }
            .padding(AppTheme.Spacing.xxl)
            .background(Color.black.opacity(0.7))
            .cornerRadius(AppTheme.CornerRadius.large)
        }
    }
}

// MARK: - Alert Modifier

extension View {
    func appAlert(error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        alert(
            error.wrappedValue?.title ?? "Error",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { appError in
            if appError.isRetryable, let onRetry {
                Button("Retry", action: onRetry)
            }
            Button("Dismiss", role: .cancel) {}
        } message: { appError in
            Text(appError.message)
        }
    }
}
