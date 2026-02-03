import SwiftUI
import UIKit

struct LegacySplitView<Primary: View, Secondary: View>: UIViewControllerRepresentable {
    let primary: Primary
    let secondary: Secondary

    func makeUIViewController(context: Context) -> UISplitViewController {
        let split = UISplitViewController(style: .doubleColumn)
        split.preferredDisplayMode = .oneBesideSecondary
        split.presentsWithGesture = true
        split.setViewController(UIHostingController(rootView: primary), for: .primary)
        split.setViewController(UIHostingController(rootView: secondary), for: .secondary)
        return split
    }

    func updateUIViewController(_ split: UISplitViewController, context: Context) {
        if let primaryHost = split.viewController(for: .primary) as? UIHostingController<Primary> {
            primaryHost.rootView = primary
        } else {
            split.setViewController(UIHostingController(rootView: primary), for: .primary)
        }

        if let secondaryHost = split.viewController(for: .secondary) as? UIHostingController<Secondary> {
            secondaryHost.rootView = secondary
        } else {
            split.setViewController(UIHostingController(rootView: secondary), for: .secondary)
        }
    }
}
