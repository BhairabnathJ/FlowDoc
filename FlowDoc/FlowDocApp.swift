import SwiftUI

@main
struct FlowDocApp: App {
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(audioRecorder)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                audioRecorder.saveCurrentSessionState()
            }
        }
    }
}
