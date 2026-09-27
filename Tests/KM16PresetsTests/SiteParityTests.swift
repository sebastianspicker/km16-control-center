import Foundation
import Testing
import KM16ControlCore

@Suite struct SiteParityTests {
    @Test func siteGroupsMatchProfileGroupTitlesAndPresetIDsInOrder() throws {
        let repositoryRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appJS = try String(contentsOf: repositoryRoot.appending(path: "site/app.js"), encoding: .utf8)

        let blockPattern = #/const groups = \[(?<body>[\s\S]*?)\n\];/#
        let body = try #require(try blockPattern.firstMatch(in: appJS)?.body)

        let rowPattern = #/\['(?<title>[^']+)', \[(?<ids>[^\]]*)\]\]/#
        let siteGroups: [(title: String, presetIDs: [String])] = body.matches(of: rowPattern).map { match in
            let ids = match.ids.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            }
            return (String(match.title), ids)
        }

        let expected = ProfileGroup.allCases.filter { $0 != .custom }.map { (title: $0.title, presetIDs: $0.presetIDs) }
        #expect(siteGroups.map(\.title) == expected.map(\.title))
        #expect(siteGroups.map(\.presetIDs) == expected.map(\.presetIDs))
    }
}
