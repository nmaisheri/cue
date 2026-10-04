import Foundation
import AppKit

/// The one screenshot explicitly selected by the user. Never persisted to disk.
public struct BrowserImage {
    public let jpeg: Data
    public let title: String
    public let capturedAt: Date
    public init(jpeg: Data, title: String, capturedAt: Date = Date()) {
        self.jpeg = jpeg; self.title = title; self.capturedAt = capturedAt
    }
    public static func dimensions(width: Double, height: Double) throws -> (Int, Int) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw CueError.message("This browser window has no visible content. Restore it and try again.")
        }
        let scale = min(1, 2048 / max(width, height))
        return (max(1, Int(width * scale)), max(1, Int(height * scale)))
    }
    public static func encode(_ image: CGImage) throws -> Data {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]),
              !data.isEmpty, data.count <= 8_000_000 else {
            throw CueError.message("This screenshot could not be prepared. Try a smaller browser window.")
        }
        return data
    }
}

public enum BrowserApps {
    public static func includes(_ bundleID: String) -> Bool {
        let ids = ["com.apple.Safari", "com.apple.SafariTechnologyPreview", "com.google.Chrome",
                   "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
                   "org.chromium.Chromium", "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
                   "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
                   "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
                   "company.thebrowser.Browser", "company.thebrowser.dia", "com.operasoftware.Opera",
                   "com.vivaldi.Vivaldi", "com.kagi.kagimacOS", "app.zen-browser.zen"]
        return ids.contains(bundleID)
    }
}
