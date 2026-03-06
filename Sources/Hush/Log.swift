import Foundation

/// Logger that writes to both stdout and a log file for monitoring.
enum Log {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let logFileURL: URL = {
        let url = URL(fileURLWithPath: "/tmp/hush.log")
        // Clear log on startup
        try? "".write(to: url, atomically: true, encoding: .utf8)
        return url
    }()

    private static func timestamp() -> String {
        dateFormatter.string(from: Date())
    }

    private static func write(_ level: String, _ message: String) {
        let line = "[\(timestamp())] [Hush] \(level) \(message)"
        print(line)
        fflush(stdout)

        // Also write to file
        if let data = (line + "\n").data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }

    static func info(_ message: String)    { write("ℹ️ ", message) }
    static func step(_ message: String)    { write("▶️ ", message) }
    static func detect(_ message: String)  { write("🔍", message) }
    static func success(_ message: String) { write("✅", message) }
    static func skip(_ message: String)    { write("⏭️ ", message) }
    static func warn(_ message: String)    { write("⚠️ ", message) }
    static func error(_ message: String)   { write("❌", message) }
}
