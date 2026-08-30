//
//  FeedbackView.swift
//  LandShip
//
//  A fillable form for sending suggestions, improvements and issue reports to the
//  developer. The form composes the message and hands it to the user's own mail
//  client through a `mailto:` URL — the app never transmits anything itself, so the
//  user always sees the message and presses Send from their own account.
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Feedback kind

/// The kind of feedback being sent. Raw values appear in the email subject line, so
/// mail can be filtered on them.
enum FeedbackKind: String, CaseIterable, Identifiable {
	case suggestion = "Suggestion"
	case improvement = "Improvement"
	case issue = "Issue"
	case question = "Question"

	var id: String { rawValue }

	var systemImage: String {
		switch self {
		case .suggestion:  return "lightbulb"
		case .improvement: return "wand.and.stars"
		case .issue:       return "exclamationmark.triangle"
		case .question:    return "questionmark.circle"
		}
	}

	/// Placeholder for the Details field, written to draw out the information that
	/// actually makes a report actionable.
	var detailsPrompt: String {
		switch self {
		case .suggestion:
			return "Describe the feature you'd like to see, and what you'd use it for."
		case .improvement:
			return "Describe how this part of the app works today, and how it could work better."
		case .issue:
			return "What did you do, what did you expect to happen, and what happened instead?"
		case .question:
			return "What would you like to know?"
		}
	}
}

// MARK: - Form

/// The feedback form itself, without navigation chrome — see `FeedbackSheet` for the
/// presentable version.
struct FeedbackView: View {
	/// Where feedback is sent. Matches the address published in changelog.md and Help.
	static let supportAddress = "info@aeronauticaltrax.com"

	/// mailto: URLs are truncated by some mail clients once they get long. Past this
	/// many characters of body text the form suggests copying instead of composing.
	private static let longBodyThreshold = 1800

	@Environment(\.dismiss) private var dismiss

	@State private var kind: FeedbackKind = .suggestion
	@State private var subject: String = ""
	@State private var details: String = ""
	@State private var senderName: String = ""
	@State private var replyEmail: String = ""
	@State private var includeAppDetails: Bool = true

	@State private var showMailFailure = false
	@State private var didCopy = false

	/// Both a subject and a description are needed for a report to be worth sending.
	private var canSend: Bool {
		!subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			&& !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var bodyIsLong: Bool { messageBody.count > Self.longBodyThreshold }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				introCard
				kindCard
				messageCard
				replyCard
				appDetailsCard
				sendCard
			}
			.padding()
		}
		.alert("Couldn't Open Mail", isPresented: $showMailFailure) {
			Button("Copy Message") { copyToClipboard() }
			Button("OK", role: .cancel) { }
		} message: {
			Text("No mail app is set up to send from this device. Copy the message and paste it into an email to \(Self.supportAddress).")
		}
	}

	// MARK: Cards

	private var introCard: some View {
		VStack(alignment: .leading, spacing: 6) {
			Label("Send Feedback", systemImage: "paperplane")
				.font(.headline)
			Text("Suggestions, improvements and problem reports all go straight to the developer. Filling this in opens your mail app with the message ready — nothing is sent until you press Send there.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.cardStyle(backgroundColor: .blue.opacity(0.6))
	}

	private var kindCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: "WHAT'S THIS ABOUT?")
			// Menu rather than segmented: "Improvement" and "Suggestion" are too wide
			// to sit side by side on an iPhone.
			Picker("Type", selection: $kind) {
				ForEach(FeedbackKind.allCases) { kind in
					Label(kind.rawValue, systemImage: kind.systemImage).tag(kind)
				}
			}
			.pickerStyle(.menu)
			.labelsHidden()
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.cardStyle()
	}

	private var messageCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: "YOUR MESSAGE")
			LabelDataTextview(label: "Subject:",
							  data: $subject,
							  prompt: "Short summary — e.g. \"Fuel log needs a filter by month\"")
			Text("Details:")
				.textLabelModified()
			TextField("", text: $details, prompt: Text(kind.detailsPrompt), axis: .vertical)
				.textFieldStyle(.roundedBorder)
				.lineLimit(6...)
				.frame(maxWidth: .infinity, alignment: .leading)
			if kind == .issue {
				Text("If the problem involves a particular record, naming the vehicle and date helps track it down.")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
		.cardStyle()
	}

	private var replyCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			SectionText(label: "HOW TO REACH YOU (OPTIONAL)")
			LabelDataTextview(label: "Name:", data: $senderName, prompt: "Optional")
			LabelDataTextview(label: "Reply Email:", data: $replyEmail, prompt: "Only if different from the account you send from")
#if os(iOS)
				.keyboardType(.emailAddress)
				.textContentType(.emailAddress)
				.autocorrectionDisabled()
				.textInputAutocapitalization(.never)
#endif
		}
		.cardStyle()
	}

	private var appDetailsCard: some View {
		VStack(alignment: .leading, spacing: 8) {
			Toggle(isOn: $includeAppDetails) {
				Text("Include app & device details")
					.font(.system(size: 15, weight: .semibold))
			}
			Text("Attaches the version, platform and model below. These make a problem far easier to reproduce, and no personal data or vehicle records are included.")
				.font(.caption2)
				.foregroundStyle(.secondary)
			if includeAppDetails {
				Text(Self.appDetails)
					.font(.caption2.monospaced())
					.foregroundStyle(.secondary)
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(8)
					.background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
			}
		}
		.cardStyle()
	}

	private var sendCard: some View {
		VStack(alignment: .leading, spacing: 10) {
			if bodyIsLong {
				Label("This message is long enough that some mail apps may cut it short. If the draft looks truncated, come back and use Copy Message instead.",
					  systemImage: "exclamationmark.triangle")
					.font(.caption2)
					.foregroundStyle(.orange)
			}

			Button {
				sendViaMail()
			} label: {
				Label("Compose in Mail", systemImage: "envelope")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.disabled(!canSend)

			Button {
				copyToClipboard()
			} label: {
				Label(didCopy ? "Copied" : "Copy Message", systemImage: didCopy ? "checkmark" : "doc.on.doc")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.bordered)
			.disabled(!canSend)

			if !canSend {
				Text("Add a subject and some details to send.")
					.font(.caption2)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .center)
			}

			HStack(spacing: 4) {
				Text("Or email directly:")
					.font(.caption2)
					.foregroundStyle(.secondary)
				Link(Self.supportAddress, destination: URL(string: "mailto:\(Self.supportAddress)")!)
					.font(.caption2)
			}
			.frame(maxWidth: .infinity, alignment: .center)
		}
		.cardStyle()
	}

	// MARK: Message composition

	private var subjectLine: String {
		let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
		return "\(VersionStrings.appName) \(kind.rawValue): \(trimmed)"
	}

	private var messageBody: String {
		var lines: [String] = []
		lines.append("Type: \(kind.rawValue)")
		lines.append("")
		lines.append(details.trimmingCharacters(in: .whitespacesAndNewlines))

		let name = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
		let email = replyEmail.trimmingCharacters(in: .whitespacesAndNewlines)
		if !name.isEmpty || !email.isEmpty {
			lines.append("")
			lines.append("From: \([name, email].filter { !$0.isEmpty }.joined(separator: " — "))")
		}

		if includeAppDetails {
			lines.append("")
			lines.append("---- App details ----")
			lines.append(Self.appDetails)
		}

		return lines.joined(separator: "\n")
	}

	/// The diagnostic block shown in the form and appended to the message. Kept to
	/// build and hardware facts — nothing identifying, nothing from the user's data.
	static var appDetails: String {
		var lines: [String] = []
		lines.append("App:      \(VersionStrings.fullVersionStringWithAppName)")
		let os = ProcessInfo.processInfo.operatingSystemVersion
		let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
#if os(macOS)
		lines.append("Platform: macOS \(osVersion)")
#else
		lines.append("Platform: \(UIDevice.current.systemName) \(osVersion)")
#endif
		lines.append("Device:   \(hardwareModel)")
		lines.append("Locale:   \(Locale.current.identifier)")
		return lines.joined(separator: "\n")
	}

	/// The hardware identifier ("iPhone15,2", "Mac14,7"), which pins the model down
	/// exactly without needing a marketing-name lookup table kept up to date.
	private static var hardwareModel: String {
#if os(macOS)
		var size = 0
		guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "Mac" }
		var chars = [CChar](repeating: 0, count: size)
		guard sysctlbyname("hw.model", &chars, &size, nil, 0) == 0 else { return "Mac" }
		return String(cString: chars)
#else
		var info = utsname()
		guard uname(&info) == 0 else { return UIDevice.current.model }
		let identifier = withUnsafeBytes(of: &info.machine) { raw in
			String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
		}
		return identifier.isEmpty ? UIDevice.current.model : identifier
#endif
	}

	/// Percent-encodes a mailto query value. Everything outside the unreserved set is
	/// escaped, so newlines and any "&", "?" or "+" the user typed can't break the URL
	/// or be misread as a space by the receiving mail client.
	private static func percentEncoded(_ value: String) -> String {
		var allowed = CharacterSet.alphanumerics
		allowed.insert(charactersIn: "-._~")
		return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
	}

	private var mailURL: URL? {
		let subject = Self.percentEncoded(subjectLine)
		let body = Self.percentEncoded(messageBody)
		return URL(string: "mailto:\(Self.supportAddress)?subject=\(subject)&body=\(body)")
	}

	// MARK: Actions

	private func sendViaMail() {
		guard let url = mailURL else {
			showMailFailure = true
			return
		}
#if os(macOS)
		if NSWorkspace.shared.open(url) {
			dismiss()
		} else {
			showMailFailure = true
		}
#else
		UIApplication.shared.open(url) { success in
			if success {
				dismiss()
			} else {
				showMailFailure = true
			}
		}
#endif
	}

	private func copyToClipboard() {
		let text = "To: \(Self.supportAddress)\nSubject: \(subjectLine)\n\n\(messageBody)"
#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(text, forType: .string)
#else
		UIPasteboard.general.string = text
#endif
		didCopy = true
	}
}

// MARK: - Presentable sheet

/// Sheet presentation of `FeedbackView`, mirroring `ChangelogSheet` so the sidebar,
/// the Help document and the macOS Help window can all present the same form.
struct FeedbackSheet: View {
	var onDismiss: () -> Void

	var body: some View {
		NavigationStack {
			FeedbackView()
				.navigationTitle("Send Feedback")
				.toolbar {
#if os(macOS)
					ToolbarItem(placement: .cancellationAction) {
						Button("Close") { onDismiss() }
							.keyboardShortcut(.cancelAction)
					}
#else
					ToolbarItem(placement: .cancellationAction) {
						Button("Close") { onDismiss() }
					}
#endif
				}
		}
	}
}

#if DEBUG
#Preview("Feedback Form") {
	FeedbackSheet(onDismiss: {})
}
#endif
