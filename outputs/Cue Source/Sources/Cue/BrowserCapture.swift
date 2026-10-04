import AppKit
import ScreenCaptureKit
import SwiftUI
import CueCore

struct BrowserWindow: Identifiable {
    let window: SCWindow
    var id: UInt32 { window.windowID }
    var title: String {
        let app = window.owningApplication?.applicationName ?? "Browser"
        let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "\(app) · Window \(id)" : "\(app) · \(title)"
    }
}

@MainActor
final class BrowserCaptureModel: ObservableObject {
    @Published var windows: [BrowserWindow] = []
    @Published var selectedID: UInt32 = 0 { didSet { draft = nil } }
    @Published var draft: BrowserImage?
    @Published var busy = false
    @Published var error: String?

    func refresh() async {
        guard !busy else { return }
        busy = true; error = nil; draft = nil; windows = []; selectedID = 0
        defer { busy = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            try Task.checkCancellation()
            windows = content.windows.filter {
                BrowserApps.includes($0.owningApplication?.bundleIdentifier ?? "") &&
                $0.windowLayer == 0 && $0.frame.width > 100 && $0.frame.height > 100
            }.map { BrowserWindow(window: $0) }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if windows.isEmpty { error = "No browser windows found. Open or restore a browser window on this desktop, then refresh." }
        } catch is CancellationError { }
        catch { self.error = "Cue needs Screen & System Audio Recording permission to read browser windows. Enable it in System Settings → Privacy & Security, then reopen Cue if asked. \(error.localizedDescription)" }
    }

    func capture() async {
        guard !busy, let chosen = windows.first(where: { $0.id == selectedID }) else { return }
        busy = true; error = nil; draft = nil
        defer { busy = false }
        do {
            // A window-only filter excludes overlapping Cue and other app windows.
            let filter = SCContentFilter(desktopIndependentWindow: chosen.window)
            let config = SCStreamConfiguration()
            let (width, height) = try BrowserImage.dimensions(
                width: filter.contentRect.width * Double(filter.pointPixelScale),
                height: filter.contentRect.height * Double(filter.pointPixelScale))
            config.width = width; config.height = height
            config.showsCursor = false; config.capturesAudio = false
            config.ignoreShadowsSingleWindow = true; config.shouldBeOpaque = true
            config.scalesToFit = true
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            try Task.checkCancellation()
            draft = BrowserImage(jpeg: try BrowserImage.encode(image), title: chosen.title)
        } catch is CancellationError { }
        catch { self.error = "Could not capture that window. Restore it, refresh the list, and try again. \(error.localizedDescription)" }
    }
}

struct BrowserCaptureView: View {
    @ObservedObject var session: Session
    @StateObject private var capture = BrowserCaptureModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Read a browser question").font(.title3.bold())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Choose a browser window, then capture the visible question. Scroll or zoom the page first if needed.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Picker("Browser window", selection: $capture.selectedID) {
                    Text("Choose a window…").tag(UInt32(0))
                    ForEach(capture.windows) { window in Text(window.title).tag(window.id) }
                }.disabled(capture.busy)
                Button("Refresh") { Task { await capture.refresh() } }.disabled(capture.busy)
            }
            if let error = capture.error {
                Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            if let draft = capture.draft, let image = NSImage(data: draft.jpeg) {
                Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Screenshot preview of \(draft.title)")
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05))
                    if capture.busy { ProgressView("Preparing preview…") }
                    else { Label("Your screenshot preview will appear here", systemImage: "macwindow").foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text("Answer screenshot sends this image, your instructions, résumé, and recent conversation to OpenAI. The image stays in memory for follow-ups until removed or replaced. Nothing is captured continuously or saved to disk.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(capture.draft == nil ? "Capture preview" : "Retake screenshot") { Task { await capture.capture() } }
                    .disabled(capture.busy || capture.selectedID == 0)
                Spacer()
                Button("Answer screenshot") {
                    guard let draft = capture.draft else { return }
                    session.answerBrowser(draft)
                }.buttonStyle(.borderedProminent)
                    .disabled(capture.busy || capture.draft == nil || session.generating)
            }
        }.padding(22).frame(width: 680, height: 560)
            .preferredColorScheme(.dark)
            .task { await capture.refresh() }
    }
}
