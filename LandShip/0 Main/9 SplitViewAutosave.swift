//
//  SplitViewAutosave.swift
//  LandShip
//
//  Created by JP on 10/10/25.
//

import SwiftUI

#if os(macOS)
import AppKit

private struct SplitViewAutosaveModifier: ViewModifier {
    let autosaveName: String

    func body(content: Content) -> some View {
        content.background(SplitFinder(autosaveName: autosaveName))
    }

    private struct SplitFinder: NSViewRepresentable {
        let autosaveName: String

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                configureIfPossible(from: view)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                configureIfPossible(from: nsView)
            }
        }

        private func configureIfPossible(from anchorView: NSView) {
            guard let window = anchorView.window,
                  let root = window.contentView else { return }

            if let split = findSplitView(in: root) {
                // Assign autosave name once; avoids resetting on every update
                if split.autosaveName != autosaveName {
                    split.autosaveName = autosaveName
                }
            }
        }

        private func findSplitView(in root: NSView) -> NSSplitView? {
            if let split = root as? NSSplitView {
                return split
            }
            for sub in root.subviews {
                if let found = findSplitView(in: sub) {
                    return found
                }
            }
            return nil
        }
    }
}

public extension View {
    /// Persists NSSplitView divider positions for SwiftUI split views (NavigationSplitView) on macOS.
    /// Has no effect on other platforms.
    func splitViewAutosave(_ name: String) -> some View {
        modifier(SplitViewAutosaveModifier(autosaveName: name))
    }
}
#endif
