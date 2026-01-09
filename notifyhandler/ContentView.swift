import SwiftUI
import SwiftData
import ServiceManagement

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotificationRecord.timestamp, order: .reverse) private var records: [NotificationRecord]
    @ObservedObject var server: WebhookServer
    @State private var showSettings = false
    @AppStorage("serverPort") private var serverPort: Int = 19527

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                serverStatusBar
                notificationList
            }
            .navigationSplitViewColumnWidth(min: 280, ideal: 320)
            .toolbar {
                ToolbarItem {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem {
                    Button(action: clearAll) {
                        Image(systemName: "trash")
                    }
                    .disabled(records.isEmpty)
                }
            }
        } detail: {
            Text("选择一条通知查看详情")
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(server: server, port: $serverPort)
        }
        .onAppear {
            setupServer()
        }
    }

    private var serverStatusBar: some View {
        HStack {
            Circle()
                .fill(server.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(server.isRunning ? "监听中: \(serverPort)" : "已停止")
                .font(.caption)
            Spacer()
            Button(server.isRunning ? "停止" : "启动") {
                if server.isRunning {
                    server.stop()
                } else {
                    server.port = UInt16(serverPort)
                    server.start()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var notificationList: some View {
        List {
            ForEach(records) { record in
                NavigationLink {
                    NotificationDetailView(record: record)
                } label: {
                    NotificationRow(record: record)
                }
            }
            .onDelete(perform: deleteRecords)
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView("暂无通知", systemImage: "bell.slash", description: Text("收到的Webhook通知将显示在这里"))
            }
        }
    }

    private func setupServer() {
        NotificationManager.shared.requestPermission()
        server.port = UInt16(serverPort)
        server.onNotificationReceived = { payload in
            let cat = NotificationCategory(rawValue: payload.category ?? "info") ?? .info
            let ts = payload.timestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
            let extra = payload.extra?.reduce(into: [String: Any]()) { $0[$1.key] = $1.value.value } ?? [:]
            let record = NotificationRecord(title: payload.title, body: payload.body, category: cat, timestamp: ts, extra: extra)
            modelContext.insert(record)
            NotificationManager.shared.showNotification(title: payload.title, body: payload.body, category: cat.rawValue)
        }
        server.start()
    }

    private func clearAll() {
        for record in records {
            modelContext.delete(record)
        }
    }

    private func deleteRecords(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

struct NotificationRow: View {
    let record: NotificationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                categoryIcon
                Text(record.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            Text(record.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(record.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: some View {
        let (icon, color): (String, Color) = {
            switch record.category {
            case "warning": return ("exclamationmark.triangle.fill", .orange)
            case "error": return ("xmark.circle.fill", .red)
            case "success": return ("checkmark.circle.fill", .green)
            default: return ("info.circle.fill", .blue)
            }
        }()
        return Image(systemName: icon).foregroundStyle(color)
    }
}

struct NotificationDetailView: View {
    let record: NotificationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(record.title)
                    .font(.title)
                Text(record.body)
                    .font(.body)
                Divider()
                LabeledContent("类型", value: record.category)
                LabeledContent("时间", value: record.timestamp.formatted())
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var server: WebhookServer
    @Binding var port: Int
    @Environment(\.dismiss) private var dismiss
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 20) {
            Text("设置").font(.headline)
            Form {
                TextField("端口", value: $port, format: .number)
                    .frame(width: 100)
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("设置开机自启动失败: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            .formStyle(.grouped)
            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    server.stop()
                    server.port = UInt16(port)
                    server.start()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    ContentView(server: WebhookServer())
        .modelContainer(for: NotificationRecord.self, inMemory: true)
}
