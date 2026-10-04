import AppKit
import Foundation
import PDFKit
import Security
import LocalAuthentication
import CueCore

enum KeyStore {
    private static let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "local.cue.interview", kSecAttrAccount as String: "openai"]
    static func read(allowPrompt: Bool = false) -> String {
        var q = query; q[kSecReturnData as String] = true
        if !allowPrompt {
            let context = LAContext()
            context.interactionNotAllowed = true
            q[kSecUseAuthenticationContext as String] = context
        }
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String) throws {
        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw CueError.message("Keychain could not remove the key (\(status)).")
            }
            return
        }
        let attributes = [kSecValueData as String: Data(value.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(value.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CueError.message("Keychain could not save the key (\(status)).") }
    }
}


struct AnswerClient {
    var session: URLSession = .shared
    func stream(key: String, model: AnswerModel, fast: Bool, messages: [[String: String]], screenshot: BrowserImage? = nil, onText: @escaping @MainActor (String) -> Void) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try GenerationSettings.payload(model: model, fast: fast, messages: messages, screenshot: screenshot)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw CueError.message("No response from the answer service.") }
        guard (200...299).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte); if body.count > 16000 { break } }
            let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
            let detail = (object?["error"] as? [String: Any])?["message"] as? String
            throw CueError.message(detail ?? "Answer request failed (HTTP \(http.statusCode)). Check your key, billing, and connection.")
        }
        var receivedText = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            switch try StreamEvent.parse(line) {
            case .text(let text): receivedText = true; await onText(text)
            case .done:
                guard receivedText else { throw CueError.message("The service returned an empty answer. Try again.") }
                return
            case .ignored: break
            }
        }
        throw CueError.message("The connection ended before the answer finished. Try again.")
    }
}
