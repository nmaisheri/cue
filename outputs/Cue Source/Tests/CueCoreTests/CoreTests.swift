import Foundation
import CueCore
import AppKit

func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { precondition(a == b, "Expected \(b), got \(a)", file: file, line: line) }
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, file: file, line: line) }
func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(!value, file: file, line: line) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { _ = try expression() } catch { return }; preconditionFailure("Expected an error", file: file, line: line) }

@main
struct CoreTests {
    static func main() throws {
        let checks = CoreTests()
        checks.testRecognitionRevisionsAndRotationDoNotDuplicateWords()
        try checks.testStreamHandlesMetadataUnicodeAndCompletion()
        checks.testFollowUpIncludesResumeAndPreviousAnswer()
        checks.testContextBoundsAndFailedAnswersAreExcluded()
        try checks.testModelAndSpeedReachRequest()
        try checks.testAttachmentImportPersistenceAndPayload()
        try checks.testScreenshotRequests()
        print("PASS: screenshot payloads, browser filtering, image bounds, DOCX extraction, attachment persistence/removal, document facts in request, model selection, reasoning disabled, speed settings, transcript revisions, stream parsing/errors, follow-up context, bounded history")
    }
    func testRecognitionRevisionsAndRotationDoNotDuplicateWords() {
        var ledger = TranscriptLedger()
        ledger.update("Tell me a boat")
        ledger.update("Tell me about yourself")
        XCTAssertEqual(ledger.text, "Tell me about yourself")
        ledger.commit()
        ledger.update("and your last role")
        XCTAssertEqual(ledger.text, "Tell me about yourself and your last role")
        ledger.reset()
        XCTAssertEqual(ledger.text, "")
    }
    func testStreamHandlesMetadataUnicodeAndCompletion() throws {
        XCTAssertEqual(try StreamEvent.parse(": keepalive"), .ignored)
        XCTAssertEqual(try StreamEvent.parse("data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}"), .ignored)
        XCTAssertEqual(try StreamEvent.parse("data: {\"choices\":[{\"delta\":{\"content\":\"I’ve led teams.\"}}]}"), .text("I’ve led teams."))
        XCTAssertEqual(try StreamEvent.parse("data: [DONE]"), .done)
        XCTAssertThrowsError(try StreamEvent.parse("data: {\"error\":{\"message\":\"quota exceeded\"}}"))
        XCTAssertThrowsError(try StreamEvent.parse("data: not json"))
    }
    func testFollowUpIncludesResumeAndPreviousAnswer() {
        let messages = AnswerContext.messages(prompt: "Keep it short", resume: "Engineer at Example", turns: [Turn(question: "Tell me about a project", answer: "I built an importer")], question: "What was the hardest part?")
        XCTAssertTrue(messages[0]["content"]!.contains("Engineer at Example"))
        XCTAssertTrue(messages[0]["content"]!.contains("Keep it short"))
        XCTAssertEqual(messages[1]["content"], "Tell me about a project")
        XCTAssertEqual(messages[2]["content"], "I built an importer")
        XCTAssertEqual(messages.last?["content"], "What was the hardest part?")
    }
    func testContextBoundsAndFailedAnswersAreExcluded() {
        var turns = (0..<30).map { Turn(question: "Q\($0)", answer: "A\($0)") }
        turns.append(Turn(question: "Failed"))
        let messages = AnswerContext.messages(prompt: "", resume: "", turns: turns, question: "Next")
        XCTAssertEqual(messages.count, 24)
        XCTAssertFalse(messages.contains { $0["content"] == "Failed" })
        XCTAssertFalse(messages.contains { $0["content"] == "Q0" })
    }
    func testModelAndSpeedReachRequest() throws {
        let messages = AnswerContext.messages(prompt: "", resume: "Resume", turns: [], question: "Question", fast: true)
        let quick = try JSONSerialization.jsonObject(with: GenerationSettings.payload(model: .sol, fast: true, messages: messages)) as! [String: Any]
        XCTAssertEqual(quick["model"] as? String, "gpt-6-sol")
        XCTAssertEqual(quick["reasoning_effort"] as? String, "none")
        XCTAssertEqual(quick["max_completion_tokens"] as? Int, 320)
        XCTAssertEqual(quick["stream"] as? Bool, true)
        XCTAssertEqual(quick["store"] as? Bool, false)
        XCTAssertTrue(messages[0]["content"]!.contains("50–90 words"))
        let light = try JSONSerialization.jsonObject(with: GenerationSettings.payload(model: .light, fast: true, messages: messages)) as! [String: Any]
        XCTAssertEqual(light["model"] as? String, "gpt-5.6-luna")
        XCTAssertEqual(light["reasoning_effort"] as? String, "none")
        let full = try JSONSerialization.jsonObject(with: GenerationSettings.payload(model: .balanced, fast: false, messages: messages)) as! [String: Any]
        XCTAssertEqual(full["model"] as? String, "gpt-4.1-mini")
        XCTAssertTrue(full["reasoning_effort"] == nil)
        XCTAssertEqual(full["max_completion_tokens"] as? Int, 650)
        XCTAssertEqual(GenerationSettings.pauseNanoseconds(fast: true), 900_000_000)
        XCTAssertEqual(GenerationSettings.pauseNanoseconds(fast: false), 2_200_000_000)
    }

    func testAttachmentImportPersistenceAndPayload() throws {
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Resume.docx")
        let text = try ResumeReader.read(fixture)
        XCTAssertTrue(text.contains("Zoë Example"))
        XCTAssertTrue(text.contains("solar telemetry dashboard"))
        XCTAssertTrue(text.contains("37 sensors"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("attachment.json")
        let store = AttachmentStore(url: url)
        try store.save(SavedAttachment(name: "Resume.docx", text: text))
        let restored = try AttachmentStore(url: url).load()!
        XCTAssertEqual(restored.text, text)
        XCTAssertEqual(restored.name, "Resume.docx")
        let messages = AnswerContext.messages(prompt: "Answer in one paragraph.", resume: restored.text, turns: [], question: "What did I build?")
        let payload = try GenerationSettings.payload(model: .sol, fast: true, messages: messages)
        let body = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        let sent = body["messages"] as! [[String: String]]
        XCTAssertTrue(sent[0]["content"]!.contains("37 sensors"))
        XCTAssertTrue(sent[0]["content"]!.contains("solar telemetry dashboard"))
        try store.remove()
        XCTAssertTrue(try store.load() == nil)
        let blank = directory.appendingPathComponent("blank.txt")
        try "  \n ".write(to: blank, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ResumeReader.read(blank))
        let broken = directory.appendingPathComponent("broken.docx")
        try Data("not a word document".utf8).write(to: broken)
        XCTAssertThrowsError(try ResumeReader.read(broken))
    }

    func testScreenshotRequests() throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 16,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let image = BrowserImage(jpeg: try BrowserImage.encode(bitmap.cgImage!), title: "Synthetic browser question")
        XCTAssertTrue(NSImage(data: image.jpeg) != nil)
        let messages = AnswerContext.messages(prompt: "Keep it concise", resume: "Built a solar dashboard",
            turns: [Turn(question: "Previous question", answer: "Previous answer")], question: "Read the visible question")
        let data = try GenerationSettings.payload(model: .sol, fast: true, messages: messages, screenshot: image)
        let body = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let sent = body["messages"] as! [[String: Any]]
        XCTAssertEqual(body["model"] as? String, "gpt-6-sol")
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertTrue((sent[0]["content"] as! String).contains("Built a solar dashboard"))
        XCTAssertEqual(sent[1]["content"] as? String, "Previous question")
        let parts = sent.last!["content"] as! [[String: Any]]
        XCTAssertEqual(parts[0]["text"] as? String, "Read the visible question")
        XCTAssertEqual(parts[1]["type"] as? String, "image_url")
        let url = parts[1]["image_url"] as! [String: String]
        XCTAssertEqual(url["detail"], "high")
        XCTAssertEqual(url["url"], "data:image/jpeg;base64," + image.jpeg.base64EncodedString())
        let plain = try GenerationSettings.payload(model: .sol, fast: true, messages: messages)
        let plainBody = try JSONSerialization.jsonObject(with: plain) as! [String: Any]
        XCTAssertEqual(plainBody["messages"] as? [[String: String]], messages)
        let followup = AnswerContext.messages(prompt: "", resume: "", turns: [], question: "Explain option B")
        let followData = try GenerationSettings.payload(model: .sol, fast: false, messages: followup, screenshot: image)
        XCTAssertTrue(String(data: followData, encoding: .utf8)!.contains("image_url"))
        XCTAssertThrowsError(try GenerationSettings.payload(model: .sol, fast: true, messages: [], screenshot: image))
        XCTAssertThrowsError(try GenerationSettings.payload(model: .sol, fast: true, messages: messages,
            screenshot: BrowserImage(jpeg: Data(), title: "Empty")))
        XCTAssertThrowsError(try BrowserImage.dimensions(width: 0, height: 100))
        XCTAssertThrowsError(try BrowserImage.dimensions(width: .infinity, height: 100))
        let (w, h) = try BrowserImage.dimensions(width: 4000, height: 2000)
        XCTAssertEqual(w, 2048); XCTAssertEqual(h, 1024)
        XCTAssertTrue(BrowserApps.includes("com.apple.Safari"))
        XCTAssertTrue(BrowserApps.includes("com.google.Chrome"))
        XCTAssertTrue(BrowserApps.includes("org.mozilla.firefox"))
        XCTAssertFalse(BrowserApps.includes("local.cue.interview"))
        XCTAssertFalse(BrowserApps.includes("com.apple.finder"))
        XCTAssertFalse(BrowserApps.includes("com.google.Chrome.helper"))
    }

}
