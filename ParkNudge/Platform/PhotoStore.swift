import Foundation
import UIKit

enum PhotoStoreError: LocalizedError {
    case invalidImage
    case encodingFailed
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "That image could not be opened."
        case .encodingFailed: "That image could not be prepared for storage."
        case .storageFailed: "The parking photo could not be saved."
        }
    }
}

@MainActor
final class ApplicationSupportPhotoStore: PhotoStoring {
    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default, rootURL: URL? = nil) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else { throw PhotoStoreError.storageFailed }
            self.rootURL = applicationSupport.appending(path: "ParkNudge", directoryHint: .isDirectory)
        }
        try fileManager.createDirectory(
            at: self.rootURL.appending(path: "Photos", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    func storeJPEG(data: Data, sessionID: UUID) throws -> String {
        guard let image = UIImage(data: data) else { throw PhotoStoreError.invalidImage }
        let maximumDimension: CGFloat = 1_600
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maximumDimension / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.78) else {
            throw PhotoStoreError.encodingFailed
        }

        let relativePath = "Photos/\(sessionID.uuidString.lowercased()).jpg"
        do {
            try jpeg.write(to: rootURL.appending(path: relativePath), options: .atomic)
            return relativePath
        } catch {
            throw PhotoStoreError.storageFailed
        }
    }

    func load(relativePath: String) -> Data? {
        try? Data(contentsOf: rootURL.appending(path: relativePath))
    }

    func delete(relativePath: String) throws {
        let url = rootURL.appending(path: relativePath)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func removeOrphans(keeping relativePaths: Set<String>) throws {
        let photosURL = rootURL.appending(path: "Photos", directoryHint: .isDirectory)
        let files = try fileManager.contentsOfDirectory(
            at: photosURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for file in files where !relativePaths.contains("Photos/\(file.lastPathComponent)") {
            try fileManager.removeItem(at: file)
        }
    }
}
