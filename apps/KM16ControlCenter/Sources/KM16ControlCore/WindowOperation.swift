import Foundation
import CoreGraphics

public enum WindowOperation: String, CaseIterable, Sendable {
    case leftHalf = "windowLeftHalf", rightHalf = "windowRightHalf"
    case topHalf = "windowTopHalf", bottomHalf = "windowBottomHalf"
    case topLeft = "windowTopLeft", topRight = "windowTopRight"
    case bottomLeft = "windowBottomLeft", bottomRight = "windowBottomRight"
    case maximize = "windowMaximize", center = "windowCenter", restore = "windowRestore"
    case previousDisplay = "windowPreviousDisplay", nextDisplay = "windowNextDisplay"
    case minimize = "windowMinimize", previous = "windowPrevious", next = "windowNext"

    public var title: String {
        switch self {
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .topHalf: "Top half"
        case .bottomHalf: "Bottom half"
        case .topLeft: "Top left quarter"
        case .topRight: "Top right quarter"
        case .bottomLeft: "Bottom left quarter"
        case .bottomRight: "Bottom right quarter"
        case .maximize: "Maximize window"
        case .center: "Center window"
        case .restore: "Restore window size"
        case .previousDisplay: "Previous display"
        case .nextDisplay: "Next display"
        case .minimize: "Minimize window"
        case .previous: "Previous app window"
        case .next: "Next app window"
        }
    }
}

/// Rectangles use Accessibility's global top-left coordinate system, in points.
public enum WindowGeometry {
    public static func placement(_ operation: WindowOperation, current: CGRect, visible: CGRect) -> CGRect? {
        let halfWidth = visible.width / 2, halfHeight = visible.height / 2
        switch operation {
        case .leftHalf: return CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: visible.height)
        case .rightHalf: return CGRect(x: visible.minX + halfWidth, y: visible.minY, width: halfWidth, height: visible.height)
        case .topHalf: return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: halfHeight)
        case .bottomHalf: return CGRect(x: visible.minX, y: visible.minY + halfHeight, width: visible.width, height: halfHeight)
        case .topLeft: return CGRect(x: visible.minX, y: visible.minY, width: halfWidth, height: halfHeight)
        case .topRight: return CGRect(x: visible.minX + halfWidth, y: visible.minY, width: halfWidth, height: halfHeight)
        case .bottomLeft: return CGRect(x: visible.minX, y: visible.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .bottomRight: return CGRect(x: visible.minX + halfWidth, y: visible.minY + halfHeight, width: halfWidth, height: halfHeight)
        case .maximize: return visible
        case .center: return centered(current.size, in: visible)
        default: return nil
        }
    }
    public static func centered(_ size: CGSize, in visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width), height = min(size.height, visible.height)
        return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
    }
    public static func accessibilityFrame(_ frame: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryTop - frame.maxY, width: frame.width, height: frame.height)
    }
    public static func displayIndex(for window: CGRect, displays: [CGRect]) -> Int? {
        displays.indices.max { lhs, rhs in
            let a = window.intersection(displays[lhs]), b = window.intersection(displays[rhs])
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }
    }
}
