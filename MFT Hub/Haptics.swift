import UIKit

/// Retained, prepared feedback generators — far more reliable than creating
/// a throwaway generator at the call site (which can deallocate before firing).
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let notify = UINotificationFeedbackGenerator()

    static func tap() {
        impact.prepare()
        impact.impactOccurred()
    }

    static func success() {
        notify.prepare()
        notify.notificationOccurred(.success)
    }
}
