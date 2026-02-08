import SwiftUI

@main
struct FlowDocApp: App {
    @StateObject private var transcriptionEngine = TranscriptionEngine.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Sessions", systemImage: "doc.text.fill")
                    }

                CircuitCameraView()
                    .tabItem {
                        Label("Camera", systemImage: "camera.viewfinder")
                    }
            }
            .environmentObject(transcriptionEngine)
        }
    }
}
