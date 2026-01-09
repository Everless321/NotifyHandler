import SwiftUI
import SwiftData
import AppKit

@main
struct notifyhandlerApp: App {
    @StateObject private var server = WebhookServer()
    @AppStorage("serverPort") private var serverPort: Int = 19527

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([NotificationRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        Window("NotifyHandler", id: "main") {
            ContentView(server: server)
        }
        .modelContainer(sharedModelContainer)

        MenuBarExtra {
            MenuBarView(server: server, port: $serverPort)
                .modelContainer(sharedModelContainer)
        } label: {
            Image(systemName: server.isRunning ? "bell.fill" : "bell.slash")
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var server: WebhookServer
    @Binding var port: Int
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(server.isRunning ? "监听中: \(port)" : "已停止")
            }
            Divider()
            Button("显示窗口") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o")
            Button(server.isRunning ? "停止服务" : "启动服务") {
                if server.isRunning {
                    server.stop()
                } else {
                    server.port = UInt16(port)
                    server.start()
                }
            }
            .keyboardShortcut("s")
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(8)
    }
}
