import AppKit
import ApplicationServices
import KM16ControlCore

/// Changes only windows belonging to the explicitly focused target application.
@MainActor final class WindowController {
    private struct SavedFrame { let pid: pid_t; let window: AXUIElement; let frame: CGRect }
    private var saved: [SavedFrame] = []
    private var cyclePID: pid_t?
    private var cycleOrder: [AXUIElement] = []

    func perform(_ operation: WindowOperation, application: NSRunningApplication) throws {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 2)
        guard let window = element(app, kAXFocusedWindowAttribute) else {
            throw IntegrationError.message("The target application has no accessible focused window.")
        }
        if operation == .previous || operation == .next {
            let available = (value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []).filter {
                value($0, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
            }
            // AX window arrays may reorder when raised. Preserve a stable cycle across presses.
            if cyclePID != application.processIdentifier { cycleOrder = []; cyclePID = application.processIdentifier }
            cycleOrder = cycleOrder.filter { remembered in available.contains { CFEqual($0, remembered) } }
            cycleOrder += available.filter { candidate in !cycleOrder.contains { CFEqual($0, candidate) } }
            let windows = cycleOrder
            guard !windows.isEmpty, let index = windows.firstIndex(where: { CFEqual($0, window) }) else {
                throw IntegrationError.message("The target application's windows cannot be enumerated.")
            }
            let offset = operation == .next ? 1 : -1
            let destination = windows[(index + offset + windows.count) % windows.count]
            if (value(destination, kAXMinimizedAttribute) as? Bool) == true {
                try set(destination, kAXMinimizedAttribute, kCFBooleanFalse)
            }
            try check(AXUIElementPerformAction(destination, kAXRaiseAction as CFString))
            return
        }
        if operation == .minimize { try set(window, kAXMinimizedAttribute, kCFBooleanTrue); return }
        guard (value(window, "AXFullScreen") as? Bool) != true else {
            throw IntegrationError.message("Leave full screen before arranging this window.")
        }
        let current = try frame(window)
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let screens = NSScreen.screens.map { WindowGeometry.accessibilityFrame($0.visibleFrame, primaryTop: primaryTop) }
        guard let index = WindowGeometry.displayIndex(for: current, displays: screens) else {
            throw IntegrationError.message("No display work area is available.")
        }
        let original = saved.firstIndex { $0.pid == application.processIdentifier && CFEqual($0.window, window) }
        let destination: CGRect
        switch operation {
        case .restore:
            guard let original else { throw IntegrationError.message("No earlier size is stored for this window in this app session.") }
            let remembered = saved[original].frame
            destination = screens.contains(where: { $0.contains(remembered) }) ? remembered : WindowGeometry.centered(remembered.size, in: screens[index])
        case .previousDisplay, .nextDisplay:
            guard screens.count > 1 else { throw IntegrationError.message("Connect another display to move this window between displays.") }
            let offset = operation == .nextDisplay ? 1 : -1
            destination = WindowGeometry.centered(current.size, in: screens[(index + offset + screens.count) % screens.count])
        default:
            guard let placed = WindowGeometry.placement(operation, current: current, visible: screens[index]) else {
                throw IntegrationError.message("Unsupported window placement.")
            }
            destination = placed
        }
        // Check both capabilities before attempting a partial move.
        for attribute in [kAXPositionAttribute, kAXSizeAttribute] {
            var writable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(window, attribute as CFString, &writable) == .success, writable.boolValue else {
                throw IntegrationError.message("The target window does not support moving and resizing.")
            }
        }
        if original == nil {
            saved.append(SavedFrame(pid: application.processIdentifier, window: window, frame: current))
            if saved.count > 64 { saved.removeFirst(saved.count - 64) }
        }
        var size = destination.size, point = destination.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size), let pointValue = AXValueCreate(.cgPoint, &point) else {
            throw IntegrationError.message("Could not represent the destination window frame.")
        }
        try set(window, kAXSizeAttribute, sizeValue)
        try set(window, kAXPositionAttribute, pointValue)
        // Apps can clamp to their own minimum size; do not report exact tiling then.
        let actual = try frame(window)
        guard abs(actual.minX - destination.minX) < 3, abs(actual.minY - destination.minY) < 3,
              abs(actual.width - destination.width) < 3, abs(actual.height - destination.height) < 3 else {
            throw IntegrationError.message("The application constrained its window size; the requested placement was only partially applied.")
        }
        if operation == .restore, let original { saved.remove(at: original) }
    }

    private func frame(_ element: AXUIElement) throws -> CGRect {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else {
            throw IntegrationError.message("The target window does not expose its frame.")
        }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else {
            throw IntegrationError.message("The target window frame could not be read.")
        }
        return CGRect(origin: point, size: dimensions)
    }
    private func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    private func element(_ parent: AXUIElement, _ name: String) -> AXUIElement? {
        guard let item = value(parent, name), CFGetTypeID(item) == AXUIElementGetTypeID() else { return nil }
        return (item as! AXUIElement)
    }
    private func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) throws {
        try check(AXUIElementSetAttributeValue(element, name as CFString, value))
    }
    private func check(_ error: AXError) throws {
        guard error == .success else { throw IntegrationError.message("macOS rejected the window operation (Accessibility error \(error.rawValue)).") }
    }
}
