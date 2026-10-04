import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CueCore

@MainActor
final class Session: ObservableObject {
    @Published var prompt = "" {
        didSet { UserDefaults.standard.set(prompt, forKey: "candidatePrompt") }
    }
    @Published var selectedModel: AnswerModel = .sol {
        didSet { UserDefaults.standard.set(selectedModel.rawValue, forKey: "answerModel") }
    }
    @Published var fastAnswers = true {
        didSet {
            UserDefaults.standard.set(fastAnswers, forKey: "fastAnswers")
            scheduleAnswer()
        }
    }
    @Published var resume = ""
    @Published var resumeName = ""
    @Published var key = ""
    @Published var hasKey = false
    @Published var keySaved = false
    @Published var keyBusy = false
    @Published var listening = false
    @Published var starting = false
    @Published var generating = false
    @Published var autoAnswer = true
    @Published var pending = ""
    @Published var typedQuestion = ""
    @Published var turns: [Turn] = []
    @Published var error: String?
    @Published var speechMode = "Incoming computer audio"
    @Published var setup = true
    @Published var importing = false
    private let attachmentStore = AttachmentStore()
    private var savedKey = ""
    private let audio = AudioListener()
    private var ledger = TranscriptLedger()
    private var debounce: Task<Void, Never>?
    private var answerTask: Task<Void, Never>?
    private var answerID = UUID()

    init() {
        let preferences = UserDefaults.standard
        if !preferences.bool(forKey: "solDefaultApplied") {
            // Apply the requested upgrade once; preserve future manual model changes.
            selectedModel = .sol
            fastAnswers = true
            preferences.set(AnswerModel.sol.rawValue, forKey: "answerModel")
            preferences.set(true, forKey: "fastAnswers")
            preferences.set(true, forKey: "solDefaultApplied")
        } else {
            selectedModel = AnswerModel(rawValue: preferences.string(forKey: "answerModel") ?? "") ?? .sol
            fastAnswers = preferences.object(forKey: "fastAnswers") as? Bool ?? true
        }
        prompt = UserDefaults.standard.string(forKey: "candidatePrompt") ?? "Give concise, natural answers in my voice. Use my resume for specific examples. For behavioral questions, use a brief STAR structure. Focus on what the interviewer is evaluating."
        do {
            if let saved = try attachmentStore.load() { resume = saved.text; resumeName = saved.name }
        } catch { self.error = "Could not restore your attachment. Please attach it again. " + error.localizedDescription }
        // A rebuilt local app may need Keychain approval. Read only on explicit Unlock.
        audio.onText = { [weak self] text, final in self?.receive(text, final: final) }
        audio.onError = { [weak self] message in
            self?.error = message; self?.listening = false; self?.debounce?.cancel()
        }
        audio.onMode = { [weak self] mode in self?.speechMode = mode }
    }

    func loadSavedKey(allowPrompt: Bool = true) async {
        guard !keyBusy else { return }
        keyBusy = true
        let value = await Task.detached { KeyStore.read(allowPrompt: allowPrompt) }.value
        savedKey = value; hasKey = !value.isEmpty; keyBusy = false
        if allowPrompt && value.isEmpty { error = "The saved key could not be unlocked. You can paste and save a key again. Listening works without a key." }
    }

    func saveKey() {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !keyBusy else { return }
        keyBusy = true
        Task {
            defer { keyBusy = false }
            do {
                try await Task.detached { try KeyStore.save(value) }.value
                savedKey = value; key = ""; hasKey = true; keySaved = true; error = nil
            } catch { self.error = error.localizedDescription }
        }
    }

    func removeKey() {
        guard !keyBusy else { return }
        keyBusy = true
        Task {
            defer { keyBusy = false }
            do {
                try await Task.detached { try KeyStore.save("") }.value
                savedKey = ""; hasKey = false; keySaved = false; cancelAnswer()
            } catch { self.error = error.localizedDescription }
        }
    }

    func attachResume() {
        guard !importing else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText, .rtf, UTType(filenameExtension: "docx")!]
        panel.allowsMultipleSelection = false
        panel.message = "Attach a text-based resume. Its text is included when you request an answer."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importing = true
        Task {
            do {
                // NSAttributedString's document importer is kept on the main actor.
                let text = try ResumeReader.read(url)
                try attachmentStore.save(SavedAttachment(name: url.lastPathComponent, text: text))
                resume = text; resumeName = url.lastPathComponent; error = nil
            } catch { self.error = error.localizedDescription }
            importing = false
        }
    }

    func removeResume() {
        do {
            try attachmentStore.remove()
            resume = ""; resumeName = ""; error = nil
        } catch { self.error = "Could not remove the saved attachment: " + error.localizedDescription }
    }

    func toggleListening() {
        guard !starting else { return }
        if listening {
            listening = false; debounce?.cancel()
            starting = true
            Task { await audio.stop(); starting = false }
        } else {
            starting = true; error = nil
            // Preserve already heard text when resuming a paused session.
            ledger.commit()
            Task {
                defer { starting = false }
                do { try await audio.start(); listening = true }
                catch { self.error = error.localizedDescription; listening = false }
            }
        }
    }

    private func receive(_ text: String, final: Bool) {
        ledger.update(text)
        if final { ledger.commit() }
        let newPending = ledger.text
        guard newPending != pending else { return }
        pending = newPending
        scheduleAnswer()
    }

    func scheduleAnswer() {
        debounce?.cancel()
        guard autoAnswer, listening, hasKey, !generating,
              pending.split(whereSeparator: { $0.isWhitespace }).count >= 2 else { return }
        let delay = GenerationSettings.pauseNanoseconds(fast: fastAnswers)
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self, self.listening, self.autoAnswer else { return }
            self.answer()
        }
    }

    func answer() {
        let typed = typedQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = typed.isEmpty ? pending : typed
        guard !question.isEmpty else { return }
        guard hasKey else { error = "Add your OpenAI API key in Setup to generate answers."; setup = true; return }
        guard !generating, !importing else { return }
        debounce?.cancel()
        error = nil
        let messages = AnswerContext.messages(prompt: prompt, resume: resume, turns: turns, question: question, fast: fastAnswers)
        if typed.isEmpty {
            audio.checkpoint()
            ledger.reset(); pending = ""
        } else { typedQuestion = "" }
        let chosenModel = selectedModel
        let fast = fastAnswers
        var turn = Turn(question: question)
        turn.modelID = chosenModel.rawValue
        turns.append(turn)
        if turns.count > 40 { turns.removeFirst(turns.count - 40) }
        generating = true
        answerID = UUID()
        let token = answerID
        let credential = savedKey
        answerTask = Task { [weak self] in
            guard let self else { return }
            let started = ProcessInfo.processInfo.systemUptime
            do {
                try await AnswerClient().stream(key: credential, model: chosenModel, fast: fast, messages: messages) { [weak self] text in
                    guard let self, self.answerID == token,
                          let index = self.turns.firstIndex(where: { $0.id == turn.id }) else { return }
                    if !text.isEmpty && self.turns[index].firstTextSeconds == nil {
                        self.turns[index].firstTextSeconds = ProcessInfo.processInfo.systemUptime - started
                    }
                    self.turns[index].answer += text
                }
                if self.answerID == token { self.generating = false; self.scheduleAnswer() }
            } catch {
                guard self.answerID == token else { return }
                self.generating = false
                if !(error is CancellationError) {
                    self.error = error.localizedDescription
                    // Keep the failed question available for a deliberate retry; avoid retry loops.
                    self.typedQuestion = question
                }
            }
        }
    }

    func cancelAnswer() {
        answerID = UUID(); answerTask?.cancel(); answerTask = nil; generating = false
    }

    func clearSession() {
        debounce?.cancel(); cancelAnswer()
        audio.checkpoint(); ledger.reset(); pending = ""; typedQuestion = ""; turns = []; error = nil
        debounce?.cancel()
    }

    func copyAnswer() {
        guard let text = turns.last?.answer, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
