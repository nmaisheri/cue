import Foundation
import ScreenCaptureKit
import Speech
import CoreMedia
import CueCore

@MainActor
final class AudioListener: NSObject, SCStreamOutput, SCStreamDelegate {
    var onText: ((String, Bool) -> Void)?
    var onError: ((String) -> Void)?
    var onMode: ((String) -> Void)?
    private var stream: SCStream?
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var rotation: Task<Void, Never>?
    private var generation = UUID()
    private var lastText = ""
    private var running = false

    func start() async throws {
        onMode?("Waiting for Speech Recognition permission…")
        let status: SFSpeechRecognizerAuthorizationStatus = try await withCheckedThrowingContinuation { continuation in
            let gate = SpeechPermissionGate(continuation)
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in gate.complete(.success(status)) }
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                gate.complete(.failure(CueError.message("macOS has not answered the Speech Recognition permission request. This is separate from Screen & System Audio Recording. Open System Settings → Privacy & Security → Speech Recognition, allow Cue, then try again.")))
            }
        }
        guard status == .authorized else {
            throw CueError.message("Enable Cue in System Settings → Privacy & Security → Speech Recognition, then try again.")
        }
        let speech = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let speech, speech.isAvailable else { throw CueError.message("English speech recognition is unavailable. Check your connection and macOS Dictation settings.") }
        recognizer = speech
        onMode?("Checking system audio permission…")
        let content: SCShareableContent
        do { content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        catch { throw CueError.message("Allow Cue in System Settings → Privacy & Security → Screen & System Audio Recording. Quit and reopen Cue if macOS asks. \(error.localizedDescription)") }
        guard let display = content.displays.first else { throw CueError.message("No active display found for system-audio capture.") }
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        // No video output is registered or retained. Keep the required video configuration tiny.
        config.width = 2; config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 3
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
        running = true
        beginRecognition()
        stream = newStream
        do { try await newStream.startCapture() }
        catch { await stop(); throw error }
        onMode?(speech.supportsOnDeviceRecognition ? "On-device transcription" : "Apple speech transcription")
    }

    private func beginRecognition() {
        guard running, let recognizer else { return }
        generation = UUID()
        let token = generation
        recognition?.cancel()
        rotation?.cancel()
        let next = SFSpeechAudioBufferRecognitionRequest()
        next.shouldReportPartialResults = true
        next.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        next.taskHint = .dictation
        request = next
        lastText = ""
        recognition = recognizer.recognitionTask(with: next) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.running, self.generation == token else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text != self.lastText { self.lastText = text; self.onText?(text, false) }
                    if result.isFinal { self.checkpoint(); return }
                }
                if let error {
                    let ns = error as NSError
                    if ns.code == 1110 { self.checkpoint(); return } // No speech in this recognition segment.
                    self.onError?("Transcription stopped: \(error.localizedDescription). Stop and start listening to retry.")
                    await self.stop()
                }
            }
        }
        // Renew before the speech service's per-request duration limit.
        rotation = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000_000)
            guard !Task.isCancelled else { return }
            self?.checkpoint()
        }
    }

    /// Preserve the last partial result before starting a fresh recognition segment.
    func checkpoint() {
        guard running else { return }
        if !lastText.isEmpty { onText?(lastText, true) }
        request?.endAudio()
        beginRecognition()
    }

    func stop() async {
        running = false
        generation = UUID()
        rotation?.cancel(); rotation = nil
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
        if let stream { try? await stream.stopCapture() }
        stream = nil
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid else { return }
        // Output was registered on the main queue, serializing recognition lifecycle and appends.
        MainActor.assumeIsolated {
            guard running else { return }
            request?.appendAudioSampleBuffer(sampleBuffer)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.running else { return }
            self.onError?("Audio capture stopped: \(error.localizedDescription)")
            await self.stop()
        }
    }
}


@MainActor
private final class SpeechPermissionGate {
    private var continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Error>?
    init(_ continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Error>) { self.continuation = continuation }
    func complete(_ result: Result<SFSpeechRecognizerAuthorizationStatus, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
