import Foundation
import KM16ControlCore

enum AppConfiguration {
    static let profilesPathArgument = "--profiles-path"

    static func profilesURL(arguments: [String] = CommandLine.arguments, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let index = arguments.firstIndex(of: profilesPathArgument), arguments.indices.contains(index + 1) {
            return URL(filePath: arguments[index + 1])
        }
        if let path = environment["KM16_PROFILES_PATH"], !path.isEmpty {
            return URL(filePath: path)
        }
        return ProfilePersistence.defaultURL()
    }

    static var requestsSmokeTest: Bool { CommandLine.arguments.contains("--smoke-test") }
    static var requestsStoreSelfTest: Bool { CommandLine.arguments.contains("--store-self-test") }
}
