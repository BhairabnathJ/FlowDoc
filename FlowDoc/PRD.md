# FlowDoc — Product Requirements Document (PRD)

**Product:** FlowDoc (AI Teammate Documentation App) 
**Version:** 1.0 (MVP)
**Platform:** iOS 16.0+ 
**Last Updated:** February 4, 2026
**Owner:** (You)
**Stakeholders:** Engineering, Design, Product, Hardware Lab Leads, Security/Privacy

---

## 1) Executive Summary

FlowDoc is an always-on, on-device AI teammate for hardware teams. It continuously records and transcribes work sessions, nudges users to capture key documentation moments, supports in-session photo/video capture, and exports clean HTML that fits existing documentation workflows (e.g., Notion/Obsidian/Slack) — all without cloud dependency for privacy and zero API costs. 

**Core value proposition**

* Always-on documentation without breaking flow 
* Local-first: processing stays on-device (privacy + no API costs) 
* Proactive nudges to capture important moments and decisions 
* Visual capture for hardware configurations; future AR wire detection 
* HTML export compatible with existing tools 

---

## 2) Problem Statement

Hardware teams lose critical context because documentation competes with “building mode.” When engineers are debugging a circuit, prototyping in a lab, or working in the field, they rarely stop to write structured notes. As a result:

* decisions, wiring changes, and test results become tribal knowledge
* handoffs are slow and error-prone
* post-mortems and replication are difficult

FlowDoc solves this by making documentation passive (always-on transcription), opportunistic (proactive nudges), and lightweight (quick visual capture + easy exports).

---

## 3) Goals and Non-Goals

### 3.1 Goals (MVP)

1. **Capture sessions reliably** even when the phone is locked or app is backgrounded via iOS background audio mode. 
2. **Generate usable transcripts** on-device with near-real-time behavior and timestamps. 
3. **Provide a privacy kill switch** that pauses recording without saving/transcribing paused audio. 
4. **Enable in-session photo/video capture** tied to session timestamps. 
5. **Export a clean, structured HTML document** usable in Notion/Obsidian/markdown workflows. 
6. **Deliver “boring, fast, predictable” UX** optimized for lab/field use (gloves-friendly, glanceable). 

### 3.2 Non-Goals (MVP)

* Cloud sync, team accounts, or collaborative real-time editing (local-first only). 
* Full AR wire detection / schematic reconstruction (planned Phase 3). 
* Complex document editing inside FlowDoc (read-focused with export). 

---

## 4) Target Users and Personas

**Primary segments** 

* Hardware startup teams (IoT, robotics, electronics)
* University engineering labs
* Maker spaces / hardware hackers
* Field engineers / technicians

**Key persona needs (derived from UX specs)**

* Gloves-friendly touch targets and minimal actions during work 
* Glanceable recording status and time 
* Easy interruption (pause/resume) without losing context 
* Low cognitive load: clear hierarchy and consistent patterns 

---

## 5) Use Cases and User Stories

### 5.1 Primary use cases

1. **Lab build session**: Two engineers iterate on a prototype; FlowDoc captures transcript and quick photos of wiring changes, then exports a session report. 
2. **Field troubleshooting**: Technician records a diagnostic session, pauses for sensitive customer info, and exports a clean report for internal review. 
3. **Team handoff**: A new teammate opens prior sessions to understand decisions, specs, and action items.

### 5.2 User stories (MVP)

* As a user, I can **start a session** and know it’s recording via an obvious visual indicator.
* As a user, I can **lock my phone** and continue recording. 
* As a user, I can **pause instantly** (kill switch) and be confident nothing is saved during the pause. 
* As a user, I can **capture a photo/video** mid-session and have it appear linked to the transcript time. 
* As a user, I can **export HTML** that includes summary metadata, transcript, and media. 

---

## 6) Product Scope and Requirements

## 6.1 MVP Functional Requirements (Phase 1: Weeks 1–3)

### FR-1 Always-On Audio Recording

* App records audio in background using iOS background audio mode. 
* Audio format: Linear PCM, 16kHz, mono. 
* Rolling buffer (e.g., 30s) for transcription chunking. 
* Persistent recording status indicator (in-app + system surface as applicable).

**Acceptance criteria**

* Start session → lock phone → unlock later → recording continues and session timeline is intact. 

### FR-2 On-Device Transcription (Real-Time / Streaming)

* Use WhisperKit / whisper.cpp wrapper for on-device transcription. 
* MVP model: `base.en` (speed/accuracy tradeoff). 
* Transcript includes timestamped segments and confidence metadata (at least internally). 

**Acceptance criteria**

* Session produces readable transcript with timestamps; new transcript text appears continuously (or in frequent chunk updates).

### FR-3 Privacy Kill Switch

* User can pause recording via:

  * voice phrase trigger (default phrase provided; customizable) 
  * hardware button gesture (volume down 3x) 
  * in-app pause button
  * auto-pause on phone call detection (default ON) 
* Paused audio is not saved/transcribed; transcript displays a gap marker. 

**Acceptance criteria**

* During pause window, no audio files exist for that interval and transcript shows a clear pause gap indicator. 

### FR-4 Manual Photo/Video Capture (In-App Camera)

* Capture: photo, short video (up to 30 seconds), and optional burst. 
* Saved locally and linked to session ID + transcript offset timestamp. 
* Optional caption and tags per media item. 

**Acceptance criteria**

* Captured media appears on session detail page, with timestamp label matching transcript timeline.

### FR-5 Session Storage and Retrieval

* Session metadata stored locally (SQLite) with transcript segments and media references. 
* Users can view a session list and open session detail. 
* Audio chunks can auto-clean after transcription (configurable). 

### FR-6 HTML Export

* Generate structured HTML including:

  * summary metadata (duration, location optional, participants if present) 
  * key points + action items (MVP may be placeholder until Phase 2, but template supports it) 
  * media grid and transcript with timestamps 
* Sharing: copy to clipboard, save as file, iOS share sheet. 
* Image bundling: Base64 for small counts; zip for larger sets (default rule: <5 base64, 5+ zip). 

**Acceptance criteria**

* Exported HTML renders correctly on desktop and can be imported into Notion/Obsidian workflows without manual cleanup. 

---

## 6.2 Phase 2 Functional Requirements (Weeks 4–6): Intelligence

### FR-7 AI Summaries, Key Points, Action Items (On-Device LLM)

* On-device LLM generates:

  * 3–5 key points
  * action items (with assignees when possible)
  * technical specs/decisions mentioned 
* Model target: Qwen2.5-0.6B Instruct quantized; alternative Phi-3-mini on stronger devices. 

### FR-8 Proactive AI Nudges

* Keyword/context-based nudges during recording (capture visual, decision, action item, technical spec). 
* UI: bottom banner, light haptic, swipe to act/dismiss, auto-dismiss.
* User controls: enable/disable nudges, sensitivity, quiet hours. 

---

## 6.3 Phase 3 Functional Requirements (Weeks 7–10+): Visual Intelligence

### FR-9 AR Wire Detection & Highlighting

* Detect wires in breadboard/circuit setups; track endpoints and connection mapping. 
* Pipeline includes detection (YOLOv8), segmentation (MobileSAM), tracking, graph mapping. 

---

## 7) UX Requirements and Design System

### 7.1 Design principles (must-haves)

* Clarity, speed, consistency, low cognitive load. 
* Glove-friendly touch targets (min 44×44pt; recommended 48pt buttons). 
* Glanceable recording status and time across key screens. 

### 7.2 Core screens (MVP)

1. **Home / Session List**: active session card + recent sessions + “New Session” FAB. 
2. **Recording Screen**: timer + live transcript + controls (pause/stop/camera). 
3. **Session Detail**: metadata, summary section (Phase 2), media strip, transcript, export.

### 7.3 Visual language

* Color tokens for states: recording (red), paused (orange), processing (teal), completed (gray). 
* Recording indicator: pulsing dot. 
* Dark mode supported with defined tokens and automatic switching. 

### 7.4 Interaction patterns

* Gestures: pull-to-refresh, swipe actions, long press menus. 
* Animations: fast/normal/slow timings; nudge banner slide. 
* Haptics: light/medium/heavy for action importance. 

---

## 8) Non-Functional Requirements

### 8.1 Privacy and Security (MVP hard requirements)

* Local-first processing; no required cloud sync. 
* Explicit permissions: microphone, camera, optional location. 
* Data retention controls (7 days / 30 days / forever) and export-only data egress. 

### 8.2 Performance Targets

**Transcription**

* Real-time factor <0.5× (process faster than realtime) and segment latency 1–3s target. 

**Battery**

* 4-hour session uses <40% battery; background recording <5% drain per hour target. 

**Storage**

* ~100–200MB per hour session data; models require ~600MB one-time download. 

### 8.3 Compatibility

* iPhone 11 Pro baseline for transcription; better experiences on newer devices; iPhone 17 Pro Max “optimal.” 

---

## 9) Data Model and Architecture (High-Level)

* Local SQLite for sessions and segments; audio stored as chunk files and optionally cleaned post-transcription. 
* Session entity includes transcript, media, optional summary, tags, and archive state. 

---

## 10) Success Metrics

### MVP success metrics (launch readiness)

* **Activation rate:** % users who complete first session recording (Start → Stop).
* **Retention proxy:** % users who export at least one session within 7 days.
* **Documentation value:** average exported sessions per active user per week.
* **Reliability:** crash-free sessions; % sessions with complete transcript + media links.
* **Battery satisfaction:** user-reported “acceptable drain” for 2+ hour sessions aligned to targets. 

### Phase 2 success metrics

* **Summary usefulness:** % sessions where users view or export summaries. 
* **Nudge acceptance rate:** % nudges acted on vs dismissed.

---

## 11) Roadmap and Milestones

### Phase 1 (Weeks 1–3): MVP Core 

* Always-on audio recording
* WhisperKit transcription
* Kill switch
* Manual photo capture
* SQLite storage
* HTML export
* Basic UI aligned to design system (Home, Recording, Detail)

### Phase 2 (Weeks 4–6): Intelligence 

* On-device LLM summaries + action items
* Proactive nudges
* Speaker diarization (enhancement)
* Enhanced export template

### Phase 3 (Weeks 7–10+): Visual Intelligence 

* Wire detection and AR overlay
* Connection mapping and schematic generation (iterative)

---

## 12) Risks and Mitigations

1. **Background recording constraints on iOS** (OS policies, interruptions)

   * Mitigation: strict compliance with background audio mode + clear UX for interruptions. 

2. **Battery drain / thermal throttling** during long sessions

   * Mitigation: VAD to skip silence, adaptive sampling during silence, efficient buffering. 

3. **Model download size & onboarding friction**

   * Mitigation: “download on first run,” progress UI, allow user to start recording with delayed transcription if needed. 

4. **Transcript quality in noisy labs**

   * Mitigation: encourage phone placement best practices; future: noise suppression; optional vocabulary injection for technical terms. 

5. **Trust and privacy concerns** (always-on recording)

   * Mitigation: prominent recording state, clear pause indicator, robust kill switch, local-only messaging.

---

## 13) Open Questions (Stakeholder Alignment)

* What is the **MVP definition of “participants”**: manual entry, inferred speaker labels, or both? 
* Should location be **off by default** (privacy posture) with opt-in per session? 
* Export destinations: is HTML alone sufficient for MVP, or do stakeholders want **Markdown export** in parallel? (HTML is spec’d.) 
* Do we need an explicit “**quiet hours**” default for nudges in Phase 2? 

---

## 14) Appendix — Design & Technical References

* Technical architecture, models, performance targets, privacy principles, and roadmap are specified in the Technical Specifications doc. 
* Design system tokens, components, core screens, interaction patterns, accessibility, and dark mode behaviors are specified in the UI/UX Specifications doc. 

---

If you want, I can also format this into a **stakeholder-ready Google Doc / Word (.docx)** style layout (cover page, revision history, and sign-off section) and generate it as a file you can share.
