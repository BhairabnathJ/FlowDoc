# debugger-flowdoc Memory

## Common Bug Patterns

### AVCaptureSession - "No active and enabled video connection" Crash
**Location**: CameraController.capturePhoto()
**Root Cause**: AVCapturePhotoOutput.capturePhoto(with:delegate:) requires an active video connection between the video input and photoOutput. Even if session.isRunning is true, the connection may not be fully established yet.
**Fix**: Always guard on `photoOutput.connection(with: .video)` before calling capturePhoto, checking both `isEnabled` and `isActive`.
**Pattern**: Race condition between session.startRunning() completing and internal connections becoming active.
**Date**: 2026-02-06

### "Publishing changes from within view updates" Error
**Location**: CameraController.configure() and CameraController.savePhoto()
**Root Cause**: @Published properties (`isReady`, `lastCaptureOffset`) were being updated synchronously on the main thread during SwiftUI view rendering cycles. Even though code was running on @MainActor, the updates happened at the wrong phase of the rendering cycle.
**Fix**: Wrap @Published property updates in `Task { @MainActor in }` to defer them to the next run loop iteration, breaking out of the view update cycle.
**CRITICAL**: Use `Task { @MainActor in }` NOT `await MainActor.run {}` - the latter executes SYNCHRONOUSLY and will still trigger the error.
**Pattern**: Direct assignment to @Published vars from async context triggers immediate objectWillChange notification, which conflicts if it happens during SwiftUI's view body evaluation.
**Date**: 2026-02-06

### "Publishing changes from within view updates" - TIMER VARIANT
**Location**: AudioRecorder.startTimer() + tick() - THE REAL CULPRIT for persistent errors
**Root Cause**: Timer.scheduledTimer fires every second during active view rendering. Even with DispatchQueue.main.async in timer callback, if the property update inside tick() is DIRECT assignment, it can still trigger during SwiftUI's rendering cycle.
**Fix Strategy 1 (Timer callback)**: Use manual Timer init + RunLoop.main.add(_:forMode: .common) + DispatchQueue.main.async wrapper:
```swift
timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
    DispatchQueue.main.async { self?.tick() }
}
RunLoop.main.add(timer!, forMode: .common)
```
**Fix Strategy 2 (Inside tick() - THE CRITICAL LAYER)**: Wrap @Published updates in `Task { @MainActor in }` to defer to NEXT run loop iteration:
```swift
private func tick() {
    guard let start = segmentStart else { return }
    Task { @MainActor [weak self] in
        guard let self else { return }
        self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(start)
    }
}
```
**Why both layers matter**: DispatchQueue.main.async defers the tick() CALL, but direct assignment inside tick() still fires objectWillChange synchronously. The Task wrapper inside tick() defers the actual property mutation to the next run loop cycle.
**Pattern**: For recurring timers updating @Published properties, use BOTH deferal strategies: DispatchQueue.main.async in timer callback AND Task { @MainActor in } around property updates.
**Date**: 2026-02-06

## iOS 26 AVFoundation Gotchas
- AVCaptureSession connections are auto-created when adding inputs/outputs, but may not be immediately active
- Checking `session.isRunning` alone is insufficient for capture operations
- Always validate connection state before capture: `connection.isEnabled && connection.isActive`
- @Published property updates must be deferred with Task { @MainActor in } to avoid "Publishing changes from within view updates"

### AVCaptureSession Priority Inversion - QoS MISMATCH
**Issue**: "Thread running at User-interactive quality-of-service class waiting on a lower QoS thread" warning in CameraView.updateUIView
**Root Cause**: session.startRunning() dispatched to DispatchQueue.global(qos: .userInitiated), but SwiftUI's updateUIView runs at User-interactive QoS and accesses the session property
**Fix**: Use `.userInteractive` QoS for session.startRunning() background dispatch to match SwiftUI's main thread priority:
```swift
DispatchQueue.global(qos: .userInteractive).async {
    session.startRunning()
}
```
**Pattern**: When AVCaptureSession is accessed from SwiftUI UIViewRepresentable methods (makeUIView, updateUIView), always use .userInteractive QoS for background operations to avoid priority inversions.
**Date**: 2026-02-06

### AVCaptureSession Simulator Limitations - CAMERA WON'T ACTIVATE
**Issue**: Camera never activates on simulator, Mac camera light doesn't turn on, "no active video connection" errors
**Root Cause**: `AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)` returns nil on iOS simulator (Mac doesn't have a "back camera")
**Console Errors**: `FigCaptureSourceSimulator err=-12784`, `FigCaptureSessionSimulator err=-12782`
**Fix**: Add explicit guard statements for each step of session configuration (device, input creation, adding input/output) with detailed error logging
**Testing**: ALWAYS test camera features on physical iOS device. Simulator camera support is unreliable for AVCaptureSession.
**Date**: 2026-02-06

### AVCaptureSession Connection Warmup Delay - RACE CONDITION
**Issue**: Even after `session.startRunning()` returns, `photoOutput.connection(with: .video)?.isActive` is still false
**Root Cause**: Internal AVFoundation connection setup completes asynchronously AFTER startRunning() returns to caller
**Fix**: Add `try? await Task.sleep(for: .milliseconds(500))` after startRunning() to allow internal connections to fully activate
**Pattern**: Never assume capture connections are immediately active just because startRunning() completed. Always verify connection.isActive or add warmup delay.
**Date**: 2026-02-06

## SwiftUI State Management
- Even when running on @MainActor, direct assignment to @Published during async completion can trigger "Publishing changes from within view updates"
- Solution: Always wrap @Published updates in `Task { @MainActor in }` to defer to next run loop
- This is especially critical for properties updated in response to async events (AVCaptureSession startup, photo callbacks)

### SwiftUI @StateObject Custom Init - DOUBLE INITIALIZATION
**Issue**: CameraView showed "session ready" twice in console, camera controller was being created multiple times
**Root Cause**: Custom `init(sessionID:)` that creates @StateObject inline causes SwiftUI to reinitialize the StateObject during view updates or parent re-renders
**Fix**: Store sessionID as a separate property, then initialize @StateObject with it. This ensures SwiftUI recognizes the StateObject's identity is tied to the sessionID.
**Pattern**: For @StateObject with dependencies, store the dependencies as separate properties:
```swift
let sessionID: UUID
@StateObject private var camera: CameraController
init(sessionID: UUID) {
    self.sessionID = sessionID
    _camera = StateObject(wrappedValue: CameraController(sessionID: sessionID))
}
```
**Date**: 2026-02-06

### UIViewRepresentable Preview Layer - BLANK SCREEN ON MAC CATALYST
**Issue**: AVCaptureSession running (camera light on), but CameraPreviewView showing blank screen
**Root Cause**: Empty `updateUIView(_:context:)` method means SwiftUI never syncs the AVCaptureSession to the preview layer after async configuration completes
**Fix**: In `updateUIView`, check if the preview layer's session differs from the current session and update it:
```swift
func updateUIView(_ uiView: PreviewView, context: Context) {
    if uiView.previewLayer.session != session {
        uiView.previewLayer.session = session
    }
}
```
**Pattern**: When UIViewRepresentable wraps async-initialized resources (like AVCaptureSession), ALWAYS implement updateUIView to sync state changes, even if makeUIView does initial setup.
**Date**: 2026-02-06
