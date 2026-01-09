import Foundation
import Network
import Combine

final class WebhookServer: ObservableObject {
    @Published var isRunning = false
    @Published var port: UInt16 = 8080
    @Published var lastError: String?

    private var listener: NWListener?
    var onNotificationReceived: ((WebhookPayload) -> Void)?

    func start() {
        stop()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                    case .failed(let err):
                        self?.isRunning = false
                        self?.lastError = err.localizedDescription
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }
            listener?.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            defer { connection.cancel() }
            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                self?.sendResponse(connection, status: 400, body: "{\"error\":\"Invalid request\"}")
                return
            }
            self?.parseAndHandle(request, connection: connection)
        }
    }

    private func parseAndHandle(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection, status: 400, body: "{\"error\":\"Empty request\"}")
            return
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(connection, status: 400, body: "{\"error\":\"Malformed request\"}")
            return
        }
        let method = String(parts[0])
        let path = String(parts[1])

        if method == "POST" && path == "/notify" {
            if let bodyStart = request.range(of: "\r\n\r\n") {
                let bodyStr = String(request[bodyStart.upperBound...])
                if let bodyData = bodyStr.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(WebhookPayload.self, from: bodyData) {
                    DispatchQueue.main.async {
                        self.onNotificationReceived?(payload)
                    }
                    sendResponse(connection, status: 200, body: "{\"success\":true}")
                } else {
                    sendResponse(connection, status: 400, body: "{\"error\":\"Invalid JSON\"}")
                }
            } else {
                sendResponse(connection, status: 400, body: "{\"error\":\"No body\"}")
            }
        } else if method == "GET" && path == "/health" {
            sendResponse(connection, status: 200, body: "{\"status\":\"ok\"}")
        } else {
            sendResponse(connection, status: 404, body: "{\"error\":\"Not found\"}")
        }
    }

    private func sendResponse(_ connection: NWConnection, status: Int, body: String) {
        let statusText = status == 200 ? "OK" : (status == 400 ? "Bad Request" : "Not Found")
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
