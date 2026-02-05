import SwiftUI

struct DesignTokens {

    // MARK: - Colors
    struct Colors {
        // --- Light mode ---
        static let backgroundPrimaryLight   = Color(hex: "#FCFCF9")
        static let backgroundSecondaryLight = Color(hex: "#FFFFFF")
        static let backgroundTertiaryLight  = Color(hex: "#F5F5F5")
        static let textPrimaryLight         = Color(hex: "#13343B")
        static let textSecondaryLight       = Color(hex: "#626C71")
        static let textTertiaryLight        = Color(hex: "#A7A9A9")

        // --- Dark mode ---
        static let backgroundPrimaryDark    = Color(hex: "#1F2121")
        static let backgroundSecondaryDark  = Color(hex: "#262828")
        static let backgroundTertiaryDark   = Color(hex: "#2C2E2E")
        static let textPrimaryDark          = Color(hex: "#F5F5F5")
        static let textSecondaryDark        = Color(hex: "#A7A9A9").opacity(0.7)
        static let textTertiaryDark         = Color(hex: "#77787C")

        // --- Accent ---
        static let accentPrimaryLight = Color(hex: "#21808D")
        static let accentPrimaryDark  = Color(hex: "#32B8C6")

        // --- State: recording (red) ---
        static let stateRecordingLight = Color(hex: "#C0152F")
        static let stateRecordingDark  = Color(hex: "#FF5459")

        // --- State: paused (orange) ---
        static let statePausedLight = Color(hex: "#A84B2F")
        static let statePausedDark  = Color(hex: "#E68161")

        // MARK: Adaptive helpers
        static func backgroundPrimary(for cs: ColorScheme)   -> Color { cs == .dark ? backgroundPrimaryDark   : backgroundPrimaryLight }
        static func backgroundSecondary(for cs: ColorScheme) -> Color { cs == .dark ? backgroundSecondaryDark : backgroundSecondaryLight }
        static func backgroundTertiary(for cs: ColorScheme)  -> Color { cs == .dark ? backgroundTertiaryDark  : backgroundTertiaryLight }
        static func textPrimary(for cs: ColorScheme)         -> Color { cs == .dark ? textPrimaryDark         : textPrimaryLight }
        static func textSecondary(for cs: ColorScheme)       -> Color { cs == .dark ? textSecondaryDark       : textSecondaryLight }
        static func textTertiary(for cs: ColorScheme)        -> Color { cs == .dark ? textTertiaryDark        : textTertiaryLight }
        static func accentPrimary(for cs: ColorScheme)       -> Color { cs == .dark ? accentPrimaryDark       : accentPrimaryLight }
        static func stateRecording(for cs: ColorScheme)      -> Color { cs == .dark ? stateRecordingDark      : stateRecordingLight }
        static func statePaused(for cs: ColorScheme)         -> Color { cs == .dark ? statePausedDark         : statePausedLight }
    }

    // MARK: - Typography
    struct Typography {
        static let display    = Font.system(size: 30, weight: .semibold)
        static let title1     = Font.system(size: 24, weight: .semibold)
        static let title2     = Font.system(size: 20, weight: .semibold)
        static let body       = Font.system(size: 16, weight: .regular)
        static let bodyMedium = Font.system(size: 16, weight: .medium)
        static let small      = Font.system(size: 14, weight: .regular)
        static let caption    = Font.system(size: 12, weight: .regular)
        static let tiny       = Font.system(size: 11, weight: .medium)
    }

    // MARK: - Spacing   (base unit 4 pt)
    struct Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
    }
}
