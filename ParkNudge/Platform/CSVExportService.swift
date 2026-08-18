import Foundation

enum CSVExportError: LocalizedError {
    case couldNotCreateFile

    var errorDescription: String? { "The CSV export file could not be created." }
}

@MainActor
final class LocalCSVExporter: CSVExporting {
    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.temporaryDirectory
            .appending(path: "ParkNudgeExports", directoryHint: .isDirectory)
    }

    func makeExport(sessions: [ParkingSession]) throws -> URL {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let fileURL = rootURL.appending(path: "parknudge-history-\(UUID().uuidString.lowercased()).csv")
            try ParkingCSVEncoder.encode(sessions).write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
            return fileURL
        } catch {
            throw CSVExportError.couldNotCreateFile
        }
    }

    func cleanupTemporaryExports() {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        try? fileManager.removeItem(at: rootURL)
    }
}
