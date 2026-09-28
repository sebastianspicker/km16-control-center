import Foundation
import Testing
@testable import KM16Integrations
import KM16ControlCore
import KM16Presets

@Suite struct KeyboardLayoutTests {
    @MainActor
    @Test func everyFactoryShortcutResolvesInThisKeyboardLayout() throws {
        for profile in Presets.all {
            for binding in profile.bindings where binding.action.kind == .shortcut {
                let spec = try ShortcutSpec.parse(binding.action.parameter)
                #expect(DesktopShortcutResolver.canResolve(spec), "Preset shortcut cannot resolve in this keyboard layout: \(profile.name) / \(binding.action.label) / \(binding.action.parameter)")
            }
        }
    }
}
