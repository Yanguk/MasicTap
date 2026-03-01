import SwiftUI
import Foundation
import AppKit

@MainActor
final class BackendController: ObservableObject {
    @Published var isRunning = false
    @Published var status = "Stopped"
    @Published var backendPath: String = "../zig-out/bin/zig_my_mouse"
    @Published var logs: String = ""

    private var process: Process?
    private var outputPipe: Pipe?

    func start() {
        guard !isRunning else { return }

        let url = URL(fileURLWithPath: backendPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            appendLog("[error] backend binary not found: \(url.path)")
            appendLog("[hint] run `zig build` at repository root first")
            return
        }

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = url
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLog(text.trimmingCharacters(in: .newlines))
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.status = "Stopped"
                self?.appendLog("[info] backend terminated")
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.outputPipe = nil
                self?.process = nil
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = pipe
            isRunning = true
            status = "Running"
            appendLog("[info] backend started")
        } catch {
            appendLog("[error] failed to start backend: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let proc = process, isRunning else { return }
        proc.terminate()
        appendLog("[info] stop requested")
    }

    private func appendLog(_ text: String) {
        guard !text.isEmpty else { return }
        if logs.isEmpty {
            logs = text
        } else {
            logs += "\n\(text)"
        }
    }
}

struct ContentView: View {
    @StateObject private var controller = BackendController()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MagicTap Client")
                .font(.system(size: 24, weight: .bold))

            HStack {
                Text("Status: \(controller.status)")
                    .font(.headline)
                Spacer()
                Button(controller.isRunning ? "Stop" : "Start") {
                    if controller.isRunning {
                        controller.stop()
                    } else {
                        controller.start()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Backend Binary")
                    .font(.subheadline)
                TextField("Path to zig backend", text: $controller.backendPath)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Logs")
                .font(.headline)

            ScrollView {
                Text(controller.logs.isEmpty ? "No logs yet" : controller.logs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 420)
    }
}

@main
struct MagicTapClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
