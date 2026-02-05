# UI/UX Design Specifications: FlowDoc
**Design System & Interface Guidelines**
**Version:** 1.0 MVP
**Platform:** iOS 16.0+
**Last Updated:** February 4, 2026

---

## 1. DESIGN PHILOSOPHY

### 1.1 Core Principles

**Inspired by Linear's "Boring Design" Philosophy:**
- **Clarity over cleverness** - Every element has a clear purpose
- **Speed over spectacle** - Fast, keyboard-accessible, minimal friction
- **Consistency over creativity** - Predictable patterns, reliable behavior
- **Function over form** - Beautiful as a byproduct of functionality

**Hardware Team Context:**
- **Gloves-friendly** - Large touch targets for field/lab use
- **Glanceable** - Key info visible at a glance (recording status, time)
- **Interruptible** - Easy to pause/resume without losing context
- **Low cognitive load** - Minimal decisions, clear hierarchy

### 1.2 Design Influences

| Product | What We Adopt | What We Avoid |
|---------|---------------|---------------|
| **Linear** | Clean typography, minimal chrome, keyboard shortcuts, dark mode excellence | Over-reliance on keyboard (we need touch-first) |
| **Notion** | Flexible content blocks, nested hierarchy, drag-to-reorder | Complex editing (we're read-focused) |
| **Otter.ai** | Real-time transcript scroll, speaker labels, highlight/share | Cluttered UI, too many buttons |
| **tldv** | Video timestamp sync, keyword tags, clean export | Video-centric (we're audio-first) |
| **Cluely** | Minimal overlay, context-aware suggestions | Hidden UI (we need visibility) |

---

## 2. COLOR SYSTEM

### 2.1 Foundation Colors

**Light Mode (Default):**
```swift
// Backgrounds
let backgroundPrimary = Color(hex: "#FCFCF9")   // Cream white
let backgroundSecondary = Color(hex: "#FFFFFF")  // Pure white
let backgroundTertiary = Color(hex: "#F5F5F5")   // Light gray

// Text
let textPrimary = Color(hex: "#13343B")          // Dark slate
let textSecondary = Color(hex: "#626C71")        // Medium gray
let textTertiary = Color(hex: "#A7A9A9")         // Light gray

// Borders
let borderPrimary = Color(hex: "#5E5240").opacity(0.2)    // Brown-gray 20%
let borderSecondary = Color(hex: "#5E5240").opacity(0.12) // Brown-gray 12%
```

**Dark Mode:**
```swift
// Backgrounds
let backgroundPrimary = Color(hex: "#1F2121")    // Charcoal
let backgroundSecondary = Color(hex: "#262828")  // Darker charcoal
let backgroundTertiary = Color(hex: "#2C2E2E")   // Medium charcoal

// Text
let textPrimary = Color(hex: "#F5F5F5")          // Off-white
let textSecondary = Color(hex: "#A7A9A9").opacity(0.7) // Gray 70%
let textTertiary = Color(hex: "#77787C")         // Darker gray

// Borders
let borderPrimary = Color(hex: "#77787C").opacity(0.3)
let borderSecondary = Color(hex: "#77787C").opacity(0.15)
```

### 2.2 Semantic Colors

**Accent Colors:**
```swift
// Primary Action (Teal)
let accentPrimary = Color(hex: "#21808D")        // Light mode
let accentPrimaryDark = Color(hex: "#32B8C6")    // Dark mode

// Recording State (Red)
let stateRecording = Color(hex: "#C0152F")       // Light mode
let stateRecordingDark = Color(hex: "#FF5459")   // Dark mode

// Success (Green/Teal)
let stateSuccess = Color(hex: "#21808D")

// Warning (Orange)
let stateWarning = Color(hex: "#A84B2F")         // Light mode
let stateWarningDark = Color(hex: "#E68161")     // Dark mode

// Error (Red)
let stateError = Color(hex: "#C0152F")
```

---

## 3. TYPOGRAPHY

### 3.1 Font Stack

**Primary Font:** SF Pro (System default)
- Excellent readability
- Optimized for Apple devices
- Free, no licensing

### 3.2 Type Scale

```swift
// Display (Large headers)
let fontDisplay = Font.system(size: 30, weight: .semibold)

// Title (Section headers)
let fontTitle1 = Font.system(size: 24, weight: .semibold)
let fontTitle2 = Font.system(size: 20, weight: .semibold)

// Body (Default text)
let fontBody = Font.system(size: 16, weight: .regular)
let fontBodyMedium = Font.system(size: 16, weight: .medium)

// Small (Secondary text)
let fontSmall = Font.system(size: 14, weight: .regular)

// Caption (Timestamps, metadata)
let fontCaption = Font.system(size: 12, weight: .regular)

// Tiny (Labels, tags)
let fontTiny = Font.system(size: 11, weight: .medium)
```

---

## 4. SPACING SYSTEM

### 4.1 Base Unit: 4px

```swift
let space4 = 4.0    // 4px  - Base unit
let space8 = 8.0    // 8px  - Default small spacing
let space12 = 12.0  // 12px - Medium spacing
let space16 = 16.0  // 16px - Default spacing
let space20 = 20.0  // 20px - Large spacing
let space24 = 24.0  // 24px - Section spacing
let space32 = 32.0  // 32px - Major section spacing
```

### 4.2 Touch Targets

- Minimum: 44x44 pt (Apple HIG)
- Buttons: 48pt height recommended
- List rows: 56pt minimum

---

## 5. COMPONENT LIBRARY

### 5.1 Buttons

**Primary Button:**
```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#FCFCF9"))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(hex: "#21808D"))
                .cornerRadius(10)
        }
    }
}
```

**Secondary Button:**
```swift
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "#13343B"))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(hex: "#5E5240").opacity(0.12))
                .cornerRadius(10)
        }
    }
}
```

### 5.2 Recording Dot

```swift
struct RecordingDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color(hex: "#C0152F"))
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}
```

### 5.3 Status Badge

```swift
struct StatusBadge: View {
    enum Status {
        case recording, paused, processing, completed
    }
    
    let status: Status
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .cornerRadius(999)
    }
    
    private var statusColor: Color {
        switch status {
        case .recording: return Color(hex: "#C0152F")
        case .paused: return Color(hex: "#A84B2F")
        case .processing: return Color(hex: "#21808D")
        case .completed: return Color(hex: "#626C71")
        }
    }
    
    private var statusText: String {
        switch status {
        case .recording: return "Recording"
        case .paused: return "Paused"
        case .processing: return "Processing"
        case .completed: return "Completed"
        }
    }
}
```

### 5.4 Tag View

```swift
struct TagView: View {
    let text: String
    var color: Color = Color(hex: "#21808D")
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}
```

---

## 6. SCREEN LAYOUTS

### 6.1 Home Screen (Session List)

**Layout:**
```
┌─────────────────────────────────┐
│ ☰  FlowDoc            🔍  ⚙️   │ ← Navigation bar
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🔴 Current Session        │ │ ← Active session card
│  │ Workshop - 2:34:15        │ │
│  │ [Pause] [Stop] [📷]       │ │
│  └───────────────────────────┘ │
│                                 │
│  Recent Sessions                │
│                                 │
│  ┌───────────────────────────┐ │
│  │ AgriScan Test             │ │ ← Session cards
│  │ Feb 3 • 1:23:45           │ │
│  │ 🏷️ hardware 🏷️ agriscan   │ │
│  └───────────────────────────┘ │
│                                 │
└─────────────────────────────────┘
│         [+] New Session         │ ← FAB
└─────────────────────────────────┘
```

### 6.2 Recording Screen

**Layout:**
```
┌─────────────────────────────────┐
│ ← Back    Recording        ⋮    │
├─────────────────────────────────┤
│                                 │
│     🔴 2:34:15                  │ ← Timer
│                                 │
│  Live Transcript                │
│  ──────────────────────────     │
│                                 │
│  [00:15:23]                     │
│  Speaker 1: Testing sensor...   │
│                                 │
│  [00:16:42]                     │
│  Speaker 2: Voltage reading...  │
│                                 │
└─────────────────────────────────┘
│  [⏸️]   [⏹️]   [📷]            │ ← Controls
└─────────────────────────────────┘
```

### 6.3 Session Detail Screen

**Layout:**
```
┌─────────────────────────────────┐
│ ← Sessions   Detail   🔍 ⋮      │
├─────────────────────────────────┤
│  AgriScan Prototype Test        │
│  Feb 3, 2026 • 1:23:45          │
│  🏷️ hardware                    │
│                                 │
│  ┌─────────────────────────┐   │
│  │ 💡 Summary              │   │
│  │ • Tested sensor         │   │
│  │ • Voltage issues found  │   │
│  └─────────────────────────┘   │
│                                 │
│  📸 Media (3)                   │
│  ┌───┐ ┌───┐ ┌───┐            │
│  │   │ │   │ │   │            │
│  └───┘ └───┘ └───┘            │
│                                 │
│  📝 Transcript                  │
│  [00:00:15] Speaker 1: ...     │
│                                 │
└─────────────────────────────────┘
│  [Export HTML] [Share]          │
└─────────────────────────────────┘
```

---

## 7. INTERACTION PATTERNS

### 7.1 Gestures

- **Pull-to-Refresh:** Session list
- **Swipe Left:** Delete session
- **Swipe Right:** Quick export
- **Long Press:** Context menu
- **Pinch-to-Zoom:** Media viewer

### 7.2 Animations

**Timing:**
- Fast: 150ms (button presses)
- Normal: 250ms (card animations)
- Slow: 400ms (modals)

**Key Animations:**
- Recording dot: Pulsing (1s loop)
- Nudge banner: Slide up (250ms)
- Transcript: Auto-scroll smoothly
- Button press: Scale to 0.95

### 7.3 Haptics

```swift
// Light - Non-destructive actions
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// Medium - Important actions
UIImpactFeedbackGenerator(style: .medium).impactOccurred()

// Heavy - Critical actions
UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
```

---

## 8. ACCESSIBILITY

### 8.1 VoiceOver Support

```swift
Button(action: startRecording) {
    Image(systemName: "mic.circle.fill")
}
.accessibilityLabel("Start recording")
.accessibilityHint("Begins a new recording session")
```

### 8.2 Dynamic Type

Support all iOS text size preferences using `.font(.body)` which automatically scales.

### 8.3 Color Contrast

**WCAG AA Compliance:**
- Normal text: 4.5:1 minimum
- Large text: 3:1 minimum
- UI components: 3:1 minimum

---

## 9. DARK MODE

### 9.1 Automatic Switching

```swift
@Environment(\.colorScheme) var colorScheme

var backgroundColor: Color {
    colorScheme == .dark ? Color(hex: "#1F2121") : Color(hex: "#FCFCF9")
}
```

---

## 10. DESIGN TOKENS

### 10.1 Complete Token System

```swift
struct DesignTokens {
    struct Colors {
        static let backgroundPrimaryLight = Color(hex: "#FCFCF9")
        static let backgroundPrimaryDark = Color(hex: "#1F2121")
        static let textPrimaryLight = Color(hex: "#13343B")
        static let textPrimaryDark = Color(hex: "#F5F5F5")
        static let accentPrimaryLight = Color(hex: "#21808D")
        static let accentPrimaryDark = Color(hex: "#32B8C6")
    }
    
    struct Typography {
        static let display = Font.system(size: 30, weight: .semibold)
        static let title1 = Font.system(size: 24, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
    }
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
```

---

## 11. ICON SYSTEM

### 11.1 SF Symbols Used

| Icon | SF Symbol | Usage |
|------|-----------|-------|
| 🎙️ | `mic.circle.fill` | Recording |
| ⏸️ | `pause.circle.fill` | Pause |
| ⏹️ | `stop.circle.fill` | Stop |
| 📷 | `camera.fill` | Camera |
| 🔍 | `magnifyingglass` | Search |
| ⚙️ | `gearshape.fill` | Settings |
| ➕ | `plus.circle.fill` | New session |

---

**END OF UI/UX SPECIFICATIONS**
