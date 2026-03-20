import SwiftUI
import Foundation
import AppKit

@MainActor
final class BackendController: ObservableObject {
    @Published var isRunning = false
    @Published var backendPath: String = resolveBackendPath(
        executablePath: ProcessInfo.processInfo.arguments[0]
    )

    private var process: Process?
    private var outputPipe: Pipe?

    func start() {
        guard !isRunning else { return }

        let url = URL(fileURLWithPath: backendPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("[MagicTap] backend binary not found: \(url.path)")
            return
        }

        let proc = Process()
        let pipe = Pipe()

        proc.executableURL = url
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            NSLog("[MagicTap] \(text.trimmingCharacters(in: .newlines))")
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.outputPipe = nil
                self?.process = nil
                NSLog("[MagicTap] backend terminated")
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = pipe
            isRunning = true
            NSLog("[MagicTap] backend started")
        } catch {
            NSLog("[MagicTap] failed to start backend: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let proc = process, isRunning else { return }
        proc.terminate()
        NSLog("[MagicTap] stop requested")
    }
}

@main
struct MagicTapClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = BackendController()

    var body: some Scene {
        MenuBarExtra("MagicTap", systemImage: controller.isRunning ? "hand.tap.fill" : "hand.tap") {
            Button(controller.isRunning ? "끄기" : "켜기") {
                if controller.isRunning { controller.stop() } else { controller.start() }
            }

            Divider()

            Button("종료") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
