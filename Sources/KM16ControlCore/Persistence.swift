import Foundation
import Darwin

public enum ProfilePersistenceError: Error, LocalizedError, Equatable {
    case invalidPath
    case invalidDocument(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPath: "The profiles path is not a usable file location."
        case .invalidDocument(let message): message
        }
    }
}

public struct ProfilePersistence: Sendable {
    public static let maximumDocumentBytes = 8 * 1_024 * 1_024
    public static let maximumProfileCount = 128

    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }

    public init(url: URL) { self.url = url }

    public static func defaultURL(fileManager: FileManager = .default) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appending(path: "Library", directoryHint: .isDirectory)
                .appending(path: "Application Support", directoryHint: .isDirectory)
        return support.appending(path: "KM16ControlCenter", directoryHint: .isDirectory).appending(path: "profiles.json")
    }

    /// Loads and validates a document without modifying the source file.
    /// Schema 1 documents are returned in schema 2 form and are persisted only by an explicit save.
    public func load() throws -> ProfileDocument {
        let data = try Self.readBoundedData(from: url)
        return try Self.decodeAndMigrate(data)
    }

    /// Validates and atomically writes a document. A valid previous revision rotates to
    /// `backupURL`. An invalid previous file is copied to a unique durable recovery URL.
    public func save(_ document: ProfileDocument) throws {
        let data = try Self.encodedDocument(document)
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()

        let existingFile = try Self.regularFileExists(at: url, fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if existingFile {
            let validOriginal: Data?
            do {
                let original = try Self.readBoundedData(from: url)
                _ = try Self.decodeAndMigrate(original)
                validOriginal = original
            } catch {
                try preserveRecoveryCopy(fileManager: fileManager)
                validOriginal = nil
            }
            if let validOriginal {
                _ = try Self.regularFileExists(at: backupURL, fileManager: fileManager)
                try validOriginal.write(to: backupURL, options: [.atomic])
            }
        }
        try data.write(to: url, options: [.atomic])
    }

    public func exportDocument(_ document: ProfileDocument, to exportURL: URL) throws {
        let data = try Self.encodedDocument(document)
        let directory = exportURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        _ = try Self.regularFileExists(at: exportURL, fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: exportURL, options: [.atomic])
    }

    public func importDocument(from importURL: URL) throws -> ProfileDocument {
        let data = try Self.readBoundedData(from: importURL)
        return try Self.decodeAndMigrate(data)
    }

    /// Returns durable invalid-file snapshots from oldest to newest.
    public func recoveryURLs(fileManager: FileManager = .default) throws -> [URL] {
        let directory = url.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let prefix = url.lastPathComponent + ".recovery-"
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { candidate in
            guard candidate.lastPathComponent.hasPrefix(prefix),
                  let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
                return false
            }
            return values.isRegularFile == true && values.isSymbolicLink != true
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func latestRecoveryURL(fileManager: FileManager = .default) throws -> URL? {
        try recoveryURLs(fileManager: fileManager).last
    }

    private static func decodeAndMigrate(_ data: Data) throws -> ProfileDocument {
        do {
            var document = try JSONDecoder.km16.decode(ProfileDocument.self, from: data)
            switch document.schemaVersion {
            case 1:
                document.schemaVersion = ProfileDocument.currentSchemaVersion
                try checkProfileCount(document)
                try ProfileValidator.validateStructure(document)
            case ProfileDocument.currentSchemaVersion:
                try checkProfileCount(document)
                try ProfileValidator.validate(document)
            default:
                throw ProfileValidationError.unsupportedSchema(document.schemaVersion)
            }
            return document
        } catch let error as ProfilePersistenceError {
            throw error
        } catch let error as ProfileValidationError {
            throw ProfilePersistenceError.invalidDocument(error.localizedDescription)
        } catch {
            throw ProfilePersistenceError.invalidDocument("Could not decode profiles: \(error.localizedDescription)")
        }
    }

    private func preserveRecoveryCopy(fileManager: FileManager) throws {
        let milliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        let filename = "\(url.lastPathComponent).recovery-\(milliseconds)-\(UUID().uuidString.lowercased()).json"
        let recoveryURL = url.deletingLastPathComponent().appending(path: filename)
        try fileManager.copyItem(at: url, to: recoveryURL)
    }

    private static func checkProfileCount(_ document: ProfileDocument) throws {
        guard document.profiles.count <= maximumProfileCount else {
            throw ProfilePersistenceError.invalidDocument(
                "Profile documents can contain at most \(maximumProfileCount) profiles."
            )
        }
    }

    private static func encodedDocument(_ document: ProfileDocument) throws -> Data {
        try checkProfileCount(document)
        try ProfileValidator.validate(document)
        let data = try JSONEncoder.km16.encode(document)
        try checkByteCount(data.count)
        return data
    }

    private static func readBoundedData(from sourceURL: URL, fileManager: FileManager = .default) throws -> Data {
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ProfilePersistenceError.invalidPath
        }
        if let size = attributes[.size] as? NSNumber {
            try checkByteCount(size.intValue)
        }

        let descriptor: Int32 = sourceURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        }
        guard descriptor >= 0 else {
            if errno == ELOOP { throw ProfilePersistenceError.invalidPath }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var status = stat()
        guard fstat(descriptor, &status) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard status.st_mode & S_IFMT == S_IFREG else {
            throw ProfilePersistenceError.invalidPath
        }
        try checkByteCount(Int(status.st_size))

        var data = Data()
        while data.count <= maximumDocumentBytes {
            let remaining = maximumDocumentBytes + 1 - data.count
            guard let chunk = try handle.read(upToCount: min(64 * 1_024, remaining)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        try checkByteCount(data.count)
        return data
    }

    private static func regularFileExists(at fileURL: URL, fileManager: FileManager) throws -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ProfilePersistenceError.invalidPath
            }
            return true
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return false
        }
    }

    private static func checkByteCount(_ count: Int) throws {
        guard count <= maximumDocumentBytes else {
            throw ProfilePersistenceError.invalidDocument(
                "Profile documents cannot exceed \(maximumDocumentBytes) bytes."
            )
        }
    }
}

private extension JSONEncoder {
    static var km16: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var km16: JSONDecoder { JSONDecoder() }
}
