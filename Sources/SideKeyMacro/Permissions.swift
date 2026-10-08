import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionStatus: String {
    case granted
    case denied
}

enum Permissions {
    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    static func requestAccessibilityPrompt() {
        let opts: CFDictionary = [
            "AXTrustedCheckOptionPrompt" as CFString: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func inputMonitoringStatus() -> PermissionStatus {
        CGPreflightListenEventAccess() ? .granted : .denied
    }

    static func requestInputMonitoringPrompt() {
        CGRequestListenEventAccess()
    }

    static func screenCaptureStatus() -> PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    static func requestScreenCapturePrompt() {
        _ = CGRequestScreenCaptureAccess()
    }
}
