import SwiftUI

// MARK: - App Theme

/// Centralized design system. All UI should reference these tokens.
/// Changing a value here propagates throughout the entire app.
enum AppTheme {
    
    // MARK: - Colors
    
    enum Colors {
        static let primary          = Color(hex: "#2D9B6F")//Color("AppPrimary", bundle: nil)  // Teal/Green-ish
        static let primaryFallback  = Color(hex: "#2D9B6F")
        static let secondary        = Color(hex: "#4F86C6")
        static let background       = Color(hex: "#F8F9FA")
        static let cardBackground   = Color.white
        static let textPrimary      = Color(hex: "#1A1A2E")
        static let textSecondary    = Color(hex: "#6B7280")
        static let textTertiary     = Color(hex: "#9CA3AF")
        static let divider          = Color(hex: "#E5E7EB")
        static let destructive      = Color(hex: "#EF4444")
        static let warning          = Color(hex: "#F59E0B")
        static let success          = Color(hex: "#22C55E")
        static let info             = Color(hex: "#3B82F6")
        
        // Health score tiers
        static func healthScoreColor(for tier: HealthScoreTier) -> Color {
            Color(hex: tier.colorHex)
        }
        
        // Detection status
        static func detectionStatusColor(for status: DetectionStatus) -> Color {
            switch status {
            case .detected:    return success
            case .notDetected: return textSecondary
            case .unclear:     return warning
            case .error:       return destructive
            }
        }
        
        // Recommendation priority
        static func priorityColor(for priority: RecommendationPriority) -> Color {
            switch priority {
            case .low:    return info
            case .medium: return warning
            case .high:   return Color(hex: "#F97316")
            case .urgent: return destructive
            }
        }
    }
    
    // MARK: - Typography
    
    enum Typography {
        static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
            .system(size: 34, weight: weight, design: .rounded)
        }
        static func title1(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: 28, weight: weight, design: .rounded)
        }
        static func title2(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: 22, weight: weight, design: .rounded)
        }
        static func title3(_ weight: Font.Weight = .medium) -> Font {
            .system(size: 20, weight: weight, design: .rounded)
        }
        static func headline(_ weight: Font.Weight = .semibold) -> Font {
            .system(size: 17, weight: weight, design: .default)
        }
        static func body(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 17, weight: weight, design: .default)
        }
        static func callout(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 16, weight: weight, design: .default)
        }
        static func subheadline(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 15, weight: weight, design: .default)
        }
        static func footnote(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 13, weight: weight, design: .default)
        }
        static func caption(_ weight: Font.Weight = .regular) -> Font {
            .system(size: 12, weight: weight, design: .default)
        }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 20
        static let xxl: CGFloat  = 24
        static let xxxl: CGFloat = 32
        static let section: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat  = 8
        static let medium: CGFloat = 12
        static let large: CGFloat  = 16
        static let xl: CGFloat     = 20
        static let card: CGFloat   = 16
        static let button: CGFloat = 12
        static let chip: CGFloat   = 20
    }
    
    // MARK: - Shadow
    
    enum Shadow {
        static let card = ShadowStyle(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        static let button = ShadowStyle(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let elevated = ShadowStyle(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
