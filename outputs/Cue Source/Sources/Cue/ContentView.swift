import SwiftUI
import CueCore

struct ContentView: View {
    @ObservedObject var model: Session
    var hide: () -> Void
    @State private var showAttachment = false
    @State private var showHistory = false
    @State private var confirmClear = false
    @AppStorage("backdropOpacity") private var backdropOpacity = 0.62
    private let accent = Color(red: 0.72, green: 0.89, blue: 0.65)
    private let muted = Color(white: 0.68)
    private let card = Color.white.opacity(0.055)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            if let error = model.error {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text(error).font(.system(size: 12)).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { model.error = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss error")
                }.padding(10).background(Color.black.opacity(0.25))
            }
            GeometryReader { geometry in
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        heard.padding(20)
                    }.frame(width: max(230, geometry.size.width * 0.30))
                    Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            answer
                            if model.turns.count > 1 {
                                DisclosureGroup("Earlier questions (\(model.turns.count - 1))", isExpanded: $showHistory) {
                                    VStack(alignment: .leading, spacing: 18) {
                                        ForEach(model.turns.dropLast().reversed()) { turn in
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(turn.question).font(.system(size: 12, weight: .semibold)).foregroundStyle(muted)
                                                Text(turn.answer).font(.system(size: 14)).textSelection(.enabled)
                                            }
                                            Divider()
                                        }
                                    }.padding(.top, 12)
                                }.font(.system(size: 12)).foregroundStyle(muted)
                            }
                        }.padding(20)
                    }.frame(maxWidth: .infinity)
                }
            }
            footer
        }
        // Only the backdrop fades: text and controls remain fully legible.
        .background(Color(red: 0.035, green: 0.045, blue: 0.038).opacity(backdropOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.20), lineWidth: 1).allowsHitTesting(false))
        .foregroundStyle(Color(white: 0.96))
        .tint(accent)
        .preferredColorScheme(.dark)
        .cueFirstClick()
        .frame(minWidth: 780, minHeight: 300)
        .onChange(of: model.autoAnswer) { _, _ in model.scheduleAnswer() }
        .sheet(isPresented: $model.setup) {
            ScrollView { setup.padding(24) }
                .frame(width: 460, height: 560)
                .background(Color(red: 0.063, green: 0.071, blue: 0.065))
                .preferredColorScheme(.dark)
                .cueFirstClick()
        }
        .confirmationDialog("Clear this conversation?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear conversation", role: .destructive) { model.clearSession() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your prompt, resume, and API key will stay available.") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform").font(.system(size: 18, weight: .medium)).foregroundStyle(accent)
            Text("cue").font(.system(size: 24, weight: .semibold, design: .rounded))
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                Text("Backdrop").font(.system(size: 11))
                Slider(value: $backdropOpacity, in: 0.30...0.95)
                    .frame(width: 110)
                    .accessibilityLabel("Backdrop opacity")
                    .help("Lower to see the speaker through Cue. Text stays solid.")
                Text("\(Int(backdropOpacity * 100))%")
                    .font(.system(size: 11, design: .monospaced)).frame(width: 32)
            }.foregroundStyle(muted)
            Divider().frame(height: 16).padding(.horizontal, 6)
            HStack(spacing: 6) {
                Circle().fill(model.listening ? accent : muted).frame(width: 6, height: 6)
                Text(model.starting ? "Connecting" : model.listening ? "Listening" : "Ready")
                    .font(.system(size: 11, weight: .medium))
            }.foregroundStyle(muted)
            Button { model.setup.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28) }
                .buttonStyle(.plain).help("Show setup").accessibilityLabel("Show setup")
            Button(action: hide) { Image(systemName: "eye.slash").frame(width: 28, height: 28) }
                .buttonStyle(.plain).help("Hide Cue · ⌘⇧Space").accessibilityLabel("Hide Cue")
        }.padding(.horizontal, 20).padding(.vertical, 10)
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("A little context. Better answers.").font(.system(size: 19, weight: .medium))
                Text("Add your background and what this interview is looking for.")
                    .font(.system(size: 12)).foregroundStyle(muted)
            }
            VStack(alignment: .leading, spacing: 8) {
                caption("ANSWER MODEL")
                Picker("Answer model", selection: $model.selectedModel) {
                    ForEach(AnswerModel.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(model.generating)
                Text(model.selectedModel.rawValue).font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
                Text("Your key grants access; this selection chooses the model. Changes apply to the next answer. Sol and Luna run with reasoning off for speed.")
                    .font(.system(size: 11)).foregroundStyle(muted)
                Toggle("Fast answers", isOn: $model.fastAnswers).toggleStyle(.switch).controlSize(.small)
                Text(model.fastAnswers ? "0.9-second pause · Short answers · Streams immediately" : "2.2-second pause · Fuller answers · Streams immediately")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            VStack(alignment: .leading, spacing: 7) {
                caption("YOUR INSTRUCTIONS")
                TextEditor(text: $model.prompt)
                    .font(.system(size: 13)).scrollContentBackground(.hidden)
                    .padding(8).frame(height: 100)
                    .background(card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15)).allowsHitTesting(false))
                    .accessibilityLabel("Your instructions")
            }
            HStack {
                Button { model.attachResume() } label: {
                    Label(model.importing ? "Reading…" : model.resumeName.isEmpty ? "Attach resume" : model.resumeName, systemImage: "paperclip")
                        .lineLimit(1).truncationMode(.middle)
                }.disabled(model.importing).controlSize(.large)
                if !model.resumeName.isEmpty {
                    Button { model.removeResume() } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(muted).accessibilityLabel("Remove resume")
                }
                Spacer()
                Text(model.resumeName.isEmpty ? "PDF · DOCX · TXT" : "\(model.resume.count) characters")
                    .font(.system(size: 10)).foregroundStyle(muted)
            }
            if !model.resume.isEmpty {
                Label("Read successfully · Saved on this Mac · Included with every answer", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(accent)
                DisclosureGroup("View extracted document text", isExpanded: $showAttachment) {
                    ScrollView {
                        Text(model.resume).font(.system(size: 12)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                    }.frame(height: 180).background(card, in: RoundedRectangle(cornerRadius: 8))
                }.font(.system(size: 12))
            } else {
                Text("No document attached. Answers use your instructions and conversation only.")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }
            if let error = model.error {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange).textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    caption("OPENAI API KEY")
                    Spacer()
                    if model.hasKey {
                        Label("Saved in Keychain", systemImage: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(accent)
                        Button("Remove") { model.removeKey() }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(muted)
                    }
                }
                HStack {
                    SecureField(model.hasKey ? "Replace your saved key" : "Paste your API key", text: $model.key)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("OpenAI API key")
                        .onSubmit { model.saveKey() }
                    Button("Save") { model.saveKey() }.disabled(model.keyBusy || model.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if model.keyBusy {
                    Text("Waiting for Keychain… Listening is still available.").font(.system(size: 11)).foregroundStyle(muted)
                } else if !model.hasKey {
                    Button("Unlock saved key") { Task { await model.loadSavedKey() } }
                        .font(.system(size: 11))
                }
                Text("Your attachment stays saved on this Mac until removed. Your prompt, resume text, and recent questions are sent to OpenAI for answers. API billing is separate. Audio uses Apple Speech, on-device when available. No recordings are saved.")
                    .font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.slash").foregroundStyle(muted)
                Text("To keep Cue out of a call’s shared view, share a specific window or use a separate display. Full-screen invisibility is not guaranteed.")
                    .font(.system(size: 11)).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            }
            Button { model.setup = false } label: {
                HStack { Text("Done with setup"); Spacer(); Image(systemName: "arrow.right") }
                    .font(.system(size: 12, weight: .semibold)).padding(10)
            }.buttonStyle(.plain).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(accent)
        }
    }

    private var heard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { caption("INCOMING QUESTION"); Spacer(); if model.listening { Image(systemName: "waveform").foregroundStyle(accent) } }
            Text(model.pending.isEmpty ? (model.listening ? "Listening for the next question…" : "Start listening, or type a question below.") : model.pending)
                .font(.system(size: 14)).foregroundStyle(model.pending.isEmpty ? muted : Color(white: 0.92))
                .lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                .padding(14).background(card, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var answer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                caption("SUGGESTED ANSWER")
                Spacer()
                if model.generating { ProgressView().controlSize(.small); Text("Writing").font(.system(size: 11)).foregroundStyle(muted) }
                if !(model.turns.last?.answer ?? "").isEmpty {
                    Button { model.copyAnswer() } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).foregroundStyle(muted).help("Copy answer").accessibilityLabel("Copy answer")
                }
            }
            if let turn = model.turns.last {
                HStack {
                    Text(turn.modelID)
                    Spacer()
                    if let seconds = turn.firstTextSeconds {
                        Text(String(format: "First text: %.1fs", seconds))
                            .help("Time from sending the API request to receiving the first text; excludes transcription and the pause before sending.")
                    }
                }.font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
                Text(turn.question).font(.system(size: 12)).foregroundStyle(muted).lineLimit(3)
                Text(turn.answer.isEmpty ? (model.generating ? "Thinking through your question…" : "No completed answer. Send the question again to retry.") : turn.answer)
                    .font(.system(size: 18)).lineSpacing(6).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stay in the conversation.").font(.system(size: 22, weight: .medium))
                    Text("Your answer will appear here, with your background and follow-up context in mind.")
                        .font(.system(size: 14)).foregroundStyle(muted).lineSpacing(4)
                }.padding(.vertical, 12)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 14) {
                HStack(spacing: 10) {
                    TextField("Type or correct a question…", text: $model.typedQuestion, axis: .vertical)
                        .lineLimit(1...2).textFieldStyle(.plain).font(.system(size: 13))
                        .accessibilityLabel("Type or correct a question")
                    if model.generating {
                        Button("Stop") { model.cancelAnswer() }.controlSize(.small)
                    } else {
                        Button { model.answer() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 23)) }
                            .buttonStyle(.plain).foregroundStyle(accent)
                            .disabled(model.pending.isEmpty && model.typedQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command)
                            .help("Generate answer · ⌘Return").accessibilityLabel("Generate answer")
                    }
                }.padding(10).background(card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.18)).allowsHitTesting(false))
                Button { model.toggleListening() } label: {
                    Label(model.starting ? "Connecting…" : model.listening ? "Stop listening" : "Start listening", systemImage: model.listening ? "stop.fill" : "waveform")
                        .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 11)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.black)
                    .disabled(model.starting).keyboardShortcut("l", modifiers: .command)
                    .fixedSize()
                Toggle("Auto-answer", isOn: $model.autoAnswer).toggleStyle(.switch).controlSize(.mini).font(.system(size: 11))
                    .fixedSize()
                Button { confirmClear = true } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.plain).foregroundStyle(muted).help("Clear conversation").accessibilityLabel("Clear conversation")
            }
            HStack {
                Text(model.starting ? model.speechMode : "\(model.selectedModel.rawValue) · \(model.fastAnswers ? "Fast answers" : "Fuller answers")")
                Spacer()
                Text("Drag the header to move · ⌘⇧Space to hide / show")
            }.font(.system(size: 10)).foregroundStyle(muted)
        }.padding(.horizontal, 20).padding(.vertical, 12).background(Color.black.opacity(0.12))
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(muted)
    }
}

private extension View {
    @ViewBuilder func cueFirstClick() -> some View {
        if #available(macOS 15.0, *) { self.allowsWindowActivationEvents(true) }
        else { self }
    }
}
