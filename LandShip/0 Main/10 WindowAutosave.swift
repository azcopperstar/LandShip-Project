//
//  WindowAutosave.swift
//  LandShip
//
//  Created by JP on 10/10/25.
//

import SwiftUI

#if os(macOS)
import AppKit

private struct WindowAutosaveModifier: ViewModifier {
    let autosaveName: String

    func body(content: Content) -> some View {
        content.background(WindowAccessor { window in
            window.isRestorable = true
            window.setFrameAutosaveName(autosaveName)
        })
    }

    private struct WindowAccessor: NSViewRepresentable {
        let configure: (NSWindow) -> Void

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                applyIfPossible(view)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                applyIfPossible(nsView)
            }
        }

        private func applyIfPossible(_ view: NSView) {
            if let window = view.window {
                configure(window)
            } else {
                // Try again on the next run loop if not yet attached
                DispatchQueue.main.async {
                    if let window = view.window {
                        configure(window)
                    }
                }
            }
        }
    }
}

public extension View {
    /// Persist window size and position across launches using NSWindow autosave.
    func windowFrameAutosave(_ name: String) -> some View {
        modifier(WindowAutosaveModifier(autosaveName: name))
    }
}
#endif
