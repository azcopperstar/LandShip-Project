//
//  Classes.swift
//  LandShip
//
//  Created by JP on 9/14/25.
//

import Foundation
import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
import PDFKit

/// PDFView subclass that intercepts the system print: action (right-click context menu,
/// Cmd+P, or File > Print) and handles it directly via PDFDocument.printOperation.
/// Without this, those actions bubble up to NSApplication which shows
/// "this application does not support printing".
final class PrintablePDFView: PDFView {
	override func printView(_ sender: Any?) {
		guard let doc = self.document else { return }
		let printInfo = NSPrintInfo.shared
		if let op = doc.printOperation(for: printInfo, scalingMode: .pageScaleDownToFit, autoRotate: true) {
			op.showsPrintPanel = true
			op.showsProgressPanel = true
			op.run()
		}
	}

}
#endif
