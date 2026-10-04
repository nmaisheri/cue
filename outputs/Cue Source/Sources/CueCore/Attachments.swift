import Foundation
import AppKit
import PDFKit

public enum ResumeReader {
    public static func read(_ url: URL) throws -> String {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 10_000_000 else { throw CueError.message("Choose a resume smaller than 10 MB.") }
        let text: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = PDFDocument(url: url), !document.isLocked else {
                throw CueError.message("This PDF could not be opened. Use an unlocked PDF or text file.")
            }
            text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        case "rtf", "docx":
            let type: NSAttributedString.DocumentType = url.pathExtension.lowercased() == "docx" ? .officeOpenXML : .rtf
            text = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil).string
        case "txt": text = try String(contentsOf: url, encoding: .utf8)
        default: throw CueError.message("Choose a PDF, DOCX, RTF, or TXT document.")
        }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw CueError.message("No readable text found. Export a text-based PDF, DOCX, or TXT file; scanned PDFs need OCR first.") }
        guard cleaned.count <= 40000 else { throw CueError.message("This file is too long. Please use a resume under 40,000 characters.") }
        return cleaned
    }
}

public struct SavedAttachment: Codable, Equatable {
    public let name: String
    public let text: String
    public init(name: String, text: String) { self.name = name; self.text = text }
}

public struct AttachmentStore {
    public let url: URL
    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cue/attachment.json")
    }
    public func load() throws -> SavedAttachment? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(SavedAttachment.self, from: Data(contentsOf: url))
        guard !value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.text.count <= 40000 else { throw CueError.message("The saved attachment is unreadable. Please attach it again.") }
        return value
    }
    public func save(_ attachment: SavedAttachment) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(attachment).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public func remove() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
