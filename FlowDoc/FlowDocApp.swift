import SwiftUI

@main
struct FlowDocApp: App {
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Sessions", systemImage: "waveform.circle")
                    }

                CircuitCameraView()
                    .tabItem {
                        Label("Circuit Camera", systemImage: "camera.viewfinder")
                    }
            }
            .environmentObject(audioRecorder)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                audioRecorder.saveCurrentSessionState()
            }
        }
    }
}
