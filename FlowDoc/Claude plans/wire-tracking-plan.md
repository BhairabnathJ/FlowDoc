# Wire Tracking Implementation Plan (Agent 2)

**Created by:** Planner-FlowDoc
**Date:** 2026-02-08
**Depends on:** Agent 1 (WireContour, WireDetectionEngine — complete)

---

## Context

Agent 1 outputs `[WireContour]` with new UUIDs every frame. This means the same physical wire gets a different ID each frame, causing visual flicker. Agent 2 assigns **stable IDs** across frames using IOU (Intersection Over Union) bounding-box matching, producing `[TrackedWire]` for downstream agents.

---

## Files to Create (in order)

1. `Models/CircuitCamera/TrackedWire.swift` — stable-ID wire model
2. `Models/CircuitCamera/WireTrackingConfig.swift` — tracking parameters
3. `Services/CircuitCamera/WireTrackingEngine.swift` — protocol
4. `Services/CircuitCamera/WireTracker.swift` — IOU matching implementation
5. `Views/CircuitCamera/CircuitCameraView.swift` — integration (modify existing)

See `.claude/features/camera-module/AGENT2_PLAN.md` for full algorithm details.
