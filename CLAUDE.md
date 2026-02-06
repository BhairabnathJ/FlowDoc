# FlowDoc - Claude Code Guide

This document explains how to work with the FlowDoc codebase using Claude Code and its project-scoped subagents.

## Table of Contents
- [Project Overview](#project-overview)
- [Subagents](#subagents)
- [Recommended Workflow](#recommended-workflow)
- [Example Usage](#example-usage)
- [Tech Stack Reference](#tech-stack-reference)

---

## Project Overview

**FlowDoc** is an iOS app for hardware teams that provides:
- Always-on audio recording with background support
- On-device speech transcription (WhisperKit)
- In-session photo/video capture
- HTML export for Notion/Obsidian workflows
- Privacy-first, local-only processing (no cloud sync)

### Key Documentation
- `PRD.md` - Product Requirements Document
- `Technical Specifications.md` - Architecture, models, performance targets
- `UI UX Specifications.md` - Design system, components, patterns
- `Claude Code Prompt.md` - Original build instructions

### Core Principles
1. **Local-only** - No networking, cloud sync, or external APIs
2. **Privacy-first** - No logging sensitive data externally
3. **Minimal over-engineering** - Keep solutions simple and focused
4. **Battery-aware** - Avoid busy loops, excessive timers
5. **SwiftUI + DesignTokens** - All UI uses design tokens

---

## Subagents

FlowDoc has **three project-scoped subagents** that follow a Plan → Build → Verify workflow:

### 1. planner-flowdoc
**Role:** Explores specs and creates concrete implementation plans (read-only, no code edits)

**When to use:**
- Before starting a new feature
- When you need to understand requirements from specs
- When you want to identify which files will change
- When you need to surface spec conflicts or missing details

**What it does:**
- Reads PRD, technical specs, and UI/UX specs
- Summarizes behavior, edge cases, and UX states (5-10 bullets)
- Lists files that will need changes
- Calls out spec conflicts or missing details
- Outputs a structured plan (suitable for GitHub issues)

**Constraints:**
- ✅ Can read files, search code, consult specs
- ❌ Cannot edit or write code
- ❌ Cannot run builds or bash commands

**Example prompts:**
```
Use planner-flowdoc to plan the kill switch feature
Plan the photo capture integration using planner-flowdoc
What files need to change for the HTML export feature? Use planner-flowdoc
```

---

### 2. builder-flowdoc
**Role:** Implements Swift/SwiftUI features after a plan is confirmed

**When to use:**
- After planner-flowdoc has created a plan and you've confirmed it
- When implementing approved features
- When fixing diagnosed bugs

**What it does:**
- Follows existing code patterns (DesignTokens, DB schema, services)
- Uses SwiftUI + DesignTokens for all UI
- Keeps everything local-only (no networking)
- Makes minimal, targeted edits to identified files
- Respects privacy (no logging sensitive data)
- Avoids blocking main thread

**Constraints:**
- ✅ Can read, edit, write files
- ✅ Can run bash commands and builds
- ❌ No large refactors unless explicitly requested
- ❌ No features beyond the accepted plan
- ❌ No networking or cloud sync
- ❌ No logging sensitive data externally

**Example prompts:**
```
Use builder-flowdoc to implement the camera capture plan
Build the kill switch feature using builder-flowdoc
Use builder-flowdoc to add the HTML export button
```

---

### 3. verifier-flowdoc
**Role:** Reviews code changes for quality and guardrails

**When to use:**
- After builder-flowdoc has implemented a feature
- When reviewing a PR or diff
- When debugging unexpected behavior
- When you want a quality check on recent changes

**What it does:**
- Checks for over-engineering and unnecessary abstractions
- Checks for privacy violations (accidental networking, sensitive logging)
- Checks for performance issues (busy loops, main thread blocking)
- Checks for robustness issues (error handling, nil checks)
- Provides 3-7 concrete findings with file/line numbers
- Suggests minimal, specific fixes

**Constraints:**
- ✅ Can read and search code
- ✅ Can make targeted edits (if you ask for fixes)
- ❌ Cannot silently rewrite large parts of codebase
- ❌ Cannot add new features
- Focus on review, not refactoring

**Example prompts:**
```
Use verifier-flowdoc to review the camera capture implementation
Verify the AudioRecorder changes for performance issues
Check SessionDetailView for privacy violations using verifier-flowdoc
```

---

## Recommended Workflow

### Standard Feature Development Flow

```
1. PLAN
   → Use planner-flowdoc to create implementation plan
   → Review plan, ask clarifying questions
   → Confirm plan before moving forward

2. BUILD
   → Use builder-flowdoc to implement the approved plan
   → Builder will edit files and run build
   → Fix any compile errors

3. VERIFY
   → Use verifier-flowdoc to review the implementation
   → Address any findings (privacy, performance, over-engineering)
   → Make targeted corrections if needed

4. TEST
   → Run app in simulator
   → Test edge cases (permissions, backgrounding, phone calls)
   → Confirm acceptance criteria from plan
```

### Quick Fixes Flow

For small bug fixes or tweaks:
```
1. Diagnose issue (read code, check logs)
2. Use builder-flowdoc to make targeted fix
3. (Optional) Use verifier-flowdoc for quick sanity check
```

### Code Review Flow

When reviewing existing code or PRs:
```
1. Use verifier-flowdoc to review specific files
2. Review findings and prioritize critical issues
3. Use builder-flowdoc to apply fixes (if requested)
4. Re-verify with verifier-flowdoc
```

---

## Example Usage

### Example 1: Adding a New Feature

**Goal:** Add a "pause recording on phone call" feature

```bash
# Step 1: Plan
You: "Use planner-flowdoc to plan automatic pause on phone calls"
# Agent reads Technical Specifications.md (FR-3 kill switch)
# Agent outputs structured plan with behavior, files, edge cases

# Step 2: Review plan with user
You: "Looks good, but also handle FaceTime calls"
# Update requirements

# Step 3: Build
You: "Use builder-flowdoc to implement the phone call pause feature"
# Agent edits AudioRecorder.swift, adds AVAudioSession notification
# Agent runs build, confirms success

# Step 4: Verify
You: "Use verifier-flowdoc to review the AudioRecorder changes"
# Agent checks for performance issues, robustness, privacy
# Agent provides review with 3-5 findings
```

### Example 2: Reviewing Existing Code

**Goal:** Audit CameraController for issues

```bash
You: "Use verifier-flowdoc to review Services/CameraController.swift"
# Agent reads file
# Agent checks: privacy, performance, robustness, over-engineering
# Agent outputs structured review with findings

You: "Fix the issues you found"
# Agent makes targeted edits using Edit tool
# Agent runs build to confirm
```

### Example 3: Understanding a Feature

**Goal:** Understand how HTML export works

```bash
You: "Use planner-flowdoc to analyze the HTML export implementation"
# Agent reads HTMLExporter.swift, SessionDetailView.swift
# Agent reads Technical Specifications.md (Feature 1.5)
# Agent summarizes: behavior, file structure, integration points
```

---

## Tech Stack Reference

### Languages & Frameworks
- **Swift 5.9+**
- **SwiftUI** (all UI)
- **AVFoundation** (audio recording, camera)
- **WhisperKit** (on-device transcription, requires manual SPM addition)
- **SQLite.swift** (future, currently JSON stub)

### iOS Target
- **iOS 26.2** (Xcode 26.2)
- Deployment target: iOS 26.2
- Uses new iOS 26 APIs:
  - `UIPasteboard.general` (not `.shared`)
  - `AVAudioSession` with `.allowBluetoothHFP`
  - Requires explicit `import Combine` for @Published

### Project Structure
```
FlowDoc/
├── Design/
│   ├── DesignTokens.swift       # Colors, Typography, Spacing, CornerRadius
│   └── ColorExtensions.swift    # Color(hex:) extension
├── Models/
│   ├── Session.swift            # Recording session
│   ├── Segment.swift            # Transcript segment
│   ├── Transcript.swift         # Full transcript
│   └── MediaCapture.swift       # Photo/video
├── Services/
│   ├── DatabaseManager.swift    # JSON persistence (singleton)
│   ├── AudioRecorder.swift      # AVAudioRecorder wrapper (ObservableObject)
│   ├── TranscriptionEngine.swift # WhisperKit stub
│   ├── HTMLExporter.swift       # HTML generation (singleton)
│   ├── CameraController.swift   # AVCaptureSession (ObservableObject)
│   └── KillSwitchDetector.swift # Volume gesture detection
├── Views/
│   ├── Components/              # PrimaryButton, RecordingDot, StatusBadge, TagView
│   ├── Home/                    # HomeView, SessionCard
│   ├── Recording/               # RecordingView, TranscriptRow, CameraView
│   └── Detail/                  # SessionDetailView, MediaGridView
└── FlowDocApp.swift             # App entry, owns AudioRecorder
```

### Design System (DesignTokens)

**Always use DesignTokens for UI:**
```swift
// Colors (adaptive for light/dark mode)
DesignTokens.Colors.backgroundPrimary(for: colorScheme)
DesignTokens.Colors.textPrimary(for: colorScheme)
DesignTokens.Colors.accentPrimary(for: colorScheme)
DesignTokens.Colors.stateRecording(for: colorScheme)  // Red
DesignTokens.Colors.statePaused(for: colorScheme)     // Orange

// Typography
DesignTokens.Typography.display      // 40pt
DesignTokens.Typography.title1       // 28pt
DesignTokens.Typography.body         // 16pt
DesignTokens.Typography.small        // 13pt

// Spacing
DesignTokens.Spacing.xs   // 4pt
DesignTokens.Spacing.sm   // 8pt
DesignTokens.Spacing.md   // 12pt
DesignTokens.Spacing.lg   // 16pt
DesignTokens.Spacing.xl   // 20pt
DesignTokens.Spacing.xxl  // 32pt

// Corner Radius
DesignTokens.CornerRadius.sm  // 6pt
DesignTokens.CornerRadius.md  // 10pt
DesignTokens.CornerRadius.lg  // 12pt
```

### Build Commands
```bash
# Build for simulator (iPhone 17 Pro)
xcodebuild -scheme FlowDoc \
  -destination 'platform=iOS Simulator,id=95638297-6C07-4134-855A-ACA7771CEC50' \
  -configuration Debug

# Or use generic simulator destination
xcodebuild -scheme FlowDoc \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug
```

---

## Listing and Inspecting Subagents

### View all subagents in Claude Code
```
/agents
```
This shows all available agents including the three FlowDoc project-scoped agents.

### Check agent details
```
/agents planner-flowdoc
/agents builder-flowdoc
/agents verifier-flowdoc
```

### Manually inspect agent files
Agent definitions are in:
```
.claude/agents/planner-flowdoc.md
.claude/agents/builder-flowdoc.md
.claude/agents/verifier-flowdoc.md
```

---

## Tips & Best Practices

### When to use which agent
- **Unsure about requirements?** → planner-flowdoc
- **Ready to implement?** → builder-flowdoc
- **Want quality check?** → verifier-flowdoc
- **Bug fix?** → builder-flowdoc directly
- **Code review?** → verifier-flowdoc

### Effective prompts
Be specific:
```
✅ "Use planner-flowdoc to plan the kill switch feature from FR-3"
✅ "Use builder-flowdoc to implement the camera capture plan we discussed"
✅ "Use verifier-flowdoc to check CameraController.swift for performance issues"

❌ "Plan something"
❌ "Build the app"
❌ "Review the code"
```

### Agent handoffs
Agents are designed to hand off to each other:
```
planner-flowdoc: "Plan is ready. Use builder-flowdoc to implement."
builder-flowdoc: "Implementation complete. Use verifier-flowdoc to review."
verifier-flowdoc: "Found 3 issues. Use builder-flowdoc to fix."
```

### When NOT to use agents
- Very simple changes (typo fixes, single-line edits) → just do it
- Exploratory work (understanding code) → regular chat is fine
- Complex multi-phase features → use Plan Mode instead

---

## Troubleshooting

### Agent not found
If Claude Code doesn't recognize the agent:
1. Check `.claude/agents/` directory exists
2. Verify YAML frontmatter is valid
3. Restart Claude Code or refresh project

### Agent doing the wrong thing
If an agent violates its constraints:
1. Check the agent definition (`.claude/agents/[name].md`)
2. Update the constraints section
3. Be more explicit in your prompt

### Build failures
If builder-flowdoc encounters build errors:
- Check for missing `import Combine`
- Check for iOS 26 API changes (UIPasteboard.general)
- Check actor isolation (@MainActor)
- Read full error output, not just summary

---

## Additional Resources

- **PRD:** `PRD.md` - Product requirements and goals
- **Technical Specs:** `Technical Specifications.md` - Architecture and models
- **UI/UX Specs:** `UI UX Specifications.md` - Design system and patterns
- **Build Plan:** `Claude Code Prompt.md` - Original build instructions
- **Memory:** `/Users/theri/.claude/projects/-Users-theri-Documents-trials-FlowDoc-FlowDoc/memory/MEMORY.md` - Lessons learned

---

*Last updated: February 2026*
