//
//  OnboardingView.swift
//  LandShip
//
//  Created by JP on 10/2/25.
//
//  Overview:
//  A multi-page, SwiftUI-based onboarding flow that introduces users to the app,
//  provides a quick overview of the app's structure and navigation, and prompts
//  users to configure shared preferences via a Settings editor.
//
//  Platforms:
//  - iOS / iPadOS: Uses a paged TabView with dots (page control).
//  - macOS: Uses the default TabView style (no page dots).
//
//  Data/Sync Notes:
//  The text in the onboarding explains that most data and preferences are stored
//  locally in a SQLite database and synced via iCloud, allowing a consistent
//  experience across devices that share the same Apple ID.
//
//  How to use:
//  - Present OnboardingView when the app launches for the first time or whenever
//    you want to re-introduce the app.
//  - Provide a didFinish closure to dismiss the onboarding when the user skips
//    or completes the flow.
//  - The "Open Settings" button presents a SettingsEditorView in a sheet so
//    users can configure global preferences early.
//
//  Dependencies (defined elsewhere in the project):
//  - AppInfo.displayName: String used to present the app's name.
//  - SettingsEditorView: View for editing user preferences.
//  - View modifiers onboardingHeaderModifier() and onboardingMessageModifier() for
//    styling onboarding text content.
//

import SwiftUI

/// A multi-page onboarding experience that introduces the app, explains navigation,
/// and prompts the user to configure key settings before proceeding.
///
/// Provide a `didFinish` closure to handle dismissal when the user taps "Skip",
/// completes all pages, or chooses to begin setting up data.
struct OnboardingView: View {
	// MARK: - Callbacks
	
	/// Called when the user completes or skips onboarding.
	var didFinish: () -> Void
	
	// MARK: - State
	
	/// The currently selected onboarding page index used by the TabView.
	/// Page indices (tags) are:
	/// 0: App overview
	/// 1: Settings intro (with button to open settings sheet)
	/// 2: Navigation overview
	/// 3: Garage group
	/// 4: Tracking
	/// 5: Service
	/// 6: Setup
	@State private var selectedPage: Int = 0
	
	/// Controls presentation of the Settings sheet (SettingsEditorView).
	@State private var showingSettingsSheet: Bool = false
	
	// MARK: - Body
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				// The main paged content of the onboarding. Each page is tagged to enable
				// programmatic navigation via `selectedPage`.
				TabView(selection: $selectedPage) {
					
					// Page 0: App overview and data model/sync description.
					OnboardingPage(
						title: OnboardingCopy.Overview.title,
						systemImage: OnboardingCopy.Overview.systemImage,
						header1: OnboardingCopy.Overview.header1,
						message1: OnboardingCopy.Overview.message1,
						header2: OnboardingCopy.Overview.header2,
						message2: OnboardingCopy.Overview.message2
					)
					.tag(0)
 
					// Page 1: Settings intro with button to open the settings sheet.
					settingsIntro
						.tag(1)

					// Page 2: App navigation overview for multi-column vs. phone layouts.
					OnboardingPage(
						title: OnboardingCopy.Navigation.title,
						systemImage: OnboardingCopy.Navigation.systemImage,
						header1: OnboardingCopy.Navigation.header1,
						message1: OnboardingCopy.Navigation.message1,
						header2: OnboardingCopy.Navigation.header2,
						message2: OnboardingCopy.Navigation.message2,
						header3: OnboardingCopy.Navigation.header3,
						message3: OnboardingCopy.Navigation.message3,
						header4: OnboardingCopy.Navigation.header4,
						message4: OnboardingCopy.Navigation.message4
					)
					.tag(2)

					// Page 3: Garage: Vehicles.
					OnboardingPage(
						title: OnboardingCopy.GarageVehicles.title,
						systemImage: OnboardingCopy.GarageVehicles.systemImage,
						header1: OnboardingCopy.GarageVehicles.header1,
						message1: OnboardingCopy.GarageVehicles.message1,
						header2: OnboardingCopy.GarageVehicles.header2,
						message2: OnboardingCopy.GarageVehicles.message2,
						header3: OnboardingCopy.GarageVehicles.header3,
						message3: OnboardingCopy.GarageVehicles.message3,
						header4: OnboardingCopy.GarageVehicles.header4,
						message4: OnboardingCopy.GarageVehicles.message4
					)
					.tag(3)

					// Page 4: Garage: Parts.
					OnboardingPage(
						title: OnboardingCopy.GarageParts.title,
						systemImage: OnboardingCopy.GarageParts.systemImage,
						header1: OnboardingCopy.GarageParts.header1,
						message1: OnboardingCopy.GarageParts.message1,
						header2: OnboardingCopy.GarageParts.header2,
						message2: OnboardingCopy.GarageParts.message2,
						header3: OnboardingCopy.GarageParts.header3,
						message3: OnboardingCopy.GarageParts.message3,
						header4: OnboardingCopy.GarageParts.header4,
						message4: OnboardingCopy.GarageParts.message4
					)
					.tag(4)

					// Page 4: Data Tracking: Fuel.
					OnboardingPage(
						title: OnboardingCopy.DataTracking_Fuel.title,
						systemImage: OnboardingCopy.DataTracking_Fuel.systemImage,
						header1: OnboardingCopy.DataTracking_Fuel.header1,
						message1: OnboardingCopy.DataTracking_Fuel.message1,
						header2: OnboardingCopy.DataTracking_Fuel.header2,
						message2: OnboardingCopy.DataTracking_Fuel.message2,
						header3: OnboardingCopy.DataTracking_Fuel.header3,
						message3: OnboardingCopy.DataTracking_Fuel.message3,
						header4: OnboardingCopy.DataTracking_Fuel.header4,
						message4: OnboardingCopy.DataTracking_Fuel.message4
					)
					.tag(5)
					
					// Page 5: Data Tracking: Travel.
					OnboardingPage(
						title: OnboardingCopy.DataTracking_Travel.title,
						systemImage: OnboardingCopy.DataTracking_Travel.systemImage,
						header1: OnboardingCopy.DataTracking_Travel.header1,
						message1: OnboardingCopy.DataTracking_Travel.message1,
						header2: OnboardingCopy.DataTracking_Travel.header2,
						message2: OnboardingCopy.DataTracking_Travel.message2,
						header3: OnboardingCopy.DataTracking_Travel.header3,
						message3: OnboardingCopy.DataTracking_Travel.message3,
						header4: OnboardingCopy.DataTracking_Travel.header4,
						message4: OnboardingCopy.DataTracking_Travel.message4
					)
					.tag(6)

					// Page 5: Vehicle Service: Records.
					OnboardingPage(
						title: OnboardingCopy.VehicleService_Records.title,
						systemImage: OnboardingCopy.VehicleService_Records.systemImage,
						header1: OnboardingCopy.VehicleService_Records.header1,
						message1: OnboardingCopy.VehicleService_Records.message1,
						header2: OnboardingCopy.VehicleService_Records.header2,
						message2: OnboardingCopy.VehicleService_Records.message2,
						header3: OnboardingCopy.VehicleService_Records.header3,
						message3: OnboardingCopy.VehicleService_Records.message3,
						header4: OnboardingCopy.VehicleService_Records.header4,
						message4: OnboardingCopy.VehicleService_Records.message4
					)
					.tag(7)
					
					// Page 5: Vehicle Service: Items.
					OnboardingPage(
						title: OnboardingCopy.VehicleService_Items.title,
						systemImage: OnboardingCopy.VehicleService_Items.systemImage,
						header1: OnboardingCopy.VehicleService_Items.header1,
						message1: OnboardingCopy.VehicleService_Items.message1,
						header2: OnboardingCopy.VehicleService_Items.header2,
						message2: OnboardingCopy.VehicleService_Items.message2,
						header3: OnboardingCopy.VehicleService_Items.header3,
						message3: OnboardingCopy.VehicleService_Items.message3,
						header4: OnboardingCopy.VehicleService_Items.header4,
						message4: OnboardingCopy.VehicleService_Items.message4
					)
					.tag(8)

					// Page 6: Setup: Systems.
					OnboardingPage(
						title: OnboardingCopy.Setup_Systems.title,
						systemImage: OnboardingCopy.Setup_Systems.systemImage,
						header1: OnboardingCopy.Setup_Systems.header1,
						message1: OnboardingCopy.Setup_Systems.message1,
						header2: OnboardingCopy.Setup_Systems.header2,
						message2: OnboardingCopy.Setup_Systems.message2,
						header3: OnboardingCopy.Setup_Systems.header3,
						message3: OnboardingCopy.Setup_Systems.message3,
						header4: OnboardingCopy.Setup_Systems.header4,
						message4: OnboardingCopy.Setup_Systems.message4
					)
					.tag(9)

					// Page 6: Setup: Vendors/Shops.
					OnboardingPage(
						title: OnboardingCopy.Setup_Vendors.title,
						systemImage: OnboardingCopy.Setup_Vendors.systemImage,
						header1: OnboardingCopy.Setup_Vendors.header1,
						message1: OnboardingCopy.Setup_Vendors.message1,
						header2: OnboardingCopy.Setup_Vendors.header2,
						message2: OnboardingCopy.Setup_Vendors.message2,
						header3: OnboardingCopy.Setup_Vendors.header3,
						message3: OnboardingCopy.Setup_Vendors.message3,
						header4: OnboardingCopy.Setup_Vendors.header4,
						message4: OnboardingCopy.Setup_Vendors.message4
					)
					.tag(10)

					// Page 6: Setup: Settings.
					OnboardingPage(
						title: OnboardingCopy.Setup_Settings.title,
						systemImage: OnboardingCopy.Setup_Settings.systemImage,
						header1: OnboardingCopy.Setup_Settings.header1,
						message1: OnboardingCopy.Setup_Settings.message1,
						header2: OnboardingCopy.Setup_Settings.header2,
						message2: OnboardingCopy.Setup_Settings.message2,
						header3: OnboardingCopy.Setup_Settings.header3,
						message3: OnboardingCopy.Setup_Settings.message3,
						header4: OnboardingCopy.Setup_Settings.header4,
						message4: OnboardingCopy.Setup_Settings.message4
					)
					.tag(11)

					// Page 6: Data Management: Backup/Restore.
					OnboardingPage(
						title: OnboardingCopy.DataManagement_BackupRestore.title,
						systemImage: OnboardingCopy.DataManagement_BackupRestore.systemImage,
						header1: OnboardingCopy.DataManagement_BackupRestore.header1,
						message1: OnboardingCopy.DataManagement_BackupRestore.message1,
						header2: OnboardingCopy.DataManagement_BackupRestore.header2,
						message2: OnboardingCopy.DataManagement_BackupRestore.message2,
						header3: OnboardingCopy.DataManagement_BackupRestore.header3,
						message3: OnboardingCopy.DataManagement_BackupRestore.message3,
						header4: OnboardingCopy.DataManagement_BackupRestore.header4,
						message4: OnboardingCopy.DataManagement_BackupRestore.message4
					)
					.tag(12)

					
				}
				#if os(macOS)
				// macOS uses the default TabView style (no dots).
				.tabViewStyle(.automatic)
				#else
				// iOS/iPadOS uses a page-style TabView with page control dots.
				.tabViewStyle(.page(indexDisplayMode: .always))
				#endif
				
				// Bottom control bar with Skip, Next, and Finish actions.
				HStack {
					// Skip: Immediately finishes onboarding (hidden on the last page).
					Button("Skip") {
						didFinish()
					}
					// Hide Skip on the last page to reduce clutter.
					.opacity(selectedPage == 12 ? 0 : 1)

					Spacer()

					// Next: Advances to the next page until the last page is reached.
					if selectedPage < 12 {
						Button("Next >") {
							withAnimation { selectedPage += 1 }
						}
						.buttonStyle(.borderedProminent)
					} else {
						// Finish: Final call-to-action when onboarding is complete.
						Button("Start setting up vehicle data...") {
							didFinish()
						}
						.buttonStyle(.borderedProminent)
					}
				}
				.padding(10)
				.background(.ultraThinMaterial)
			}
			// Navigation title for platforms that display it (inline on iOS).
			.navigationTitle("Get Started With \(AppInfo.displayName)")
			#if !os(macOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
		}
		// Settings sheet presentation, triggered via the Settings intro page.
		.sheet(isPresented: $showingSettingsSheet) {
			SettingsEditorView()
		}
	}
	
	// MARK: - Subviews
	
	/// The onboarding page that introduces Settings and provides a button to open
	/// the Settings editor sheet for configuring shared preferences.
	private var settingsIntro: some View {
		VStack(spacing: 1) {
			Image(systemName: OnboardingCopy.SettingsIntro.icon)
				.font(.system(size: 50, weight: .semibold))
				.foregroundStyle(.blue)
				.padding(.top, 10)

			Text(OnboardingCopy.SettingsIntro.title)
				.font(.title2).bold()
			
			Text(OnboardingCopy.SettingsIntro.message)
				.multilineTextAlignment(.leading)
				.foregroundStyle(.secondary)
				.padding(.horizontal)
			
			// Opens the Settings editor as a sheet.
			Button {
				showingSettingsSheet = true
			} label: {
				Label(OnboardingCopy.SettingsIntro.buttonLabel, systemImage: OnboardingCopy.SettingsIntro.buttonIcon)
			}
			.buttonStyle(.borderedProminent)
			.padding(.top, 8)
			
			Spacer()
		}
//		.padding()
	}
}

// MARK: - OnboardingPage

/// A flexible, reusable page for the onboarding flow. Each page displays an icon,
/// a title, and up to four header/message sections. Empty headers/messages are
/// ignored at runtime, allowing for concise per-page configuration.
private struct OnboardingPage: View {
	// MARK: Content Model
	let title: String
	let systemImage: String
	let header1: String?
	let message1: String?
	let header2: String?
	let message2: String?
	let header3: String?
	let message3: String?
	let header4: String?
	let message4: String?

	/// Initialize a new onboarding page with optional headers and messages.
	/// Any nil or empty header/message will be omitted from rendering.
	init(
		title: String,
		systemImage: String,
		header1: String? = nil,
		message1: String? = nil,
		header2: String? = nil,
		message2: String? = nil,
		header3: String? = nil,
		message3: String? = nil,
		header4: String? = nil,
		message4: String? = nil
	) {
		self.title = title
		self.systemImage = systemImage
		self.header1 = header1
		self.message1 = message1
		self.header2 = header2
		self.message2 = message2
		self.header3 = header3
		self.message3 = message3
		self.header4 = header4
		self.message4 = message4
	}

	// MARK: - Body
	
	var body: some View {
		VStack(spacing: 1) {
			// Leading icon for quick visual context per page.
			Image(systemName: systemImage)
				.font(.system(size: 50, weight: .semibold))
				.foregroundStyle(.blue)
				.padding(.top, 10)
			
			// Page title.
			Text(title)
				.font(.title2).bold()
			
			// Scrollable content area for multi-section text.
			ScrollView {

				// 1st header & message
				if let header1, !header1.isEmpty {
					Text(header1)
						.onboardingHeaderModifier()
				}
				if let message1, !message1.isEmpty {
					Text(message1)
						.onboardingMessageModifier()
				}
				// 2nd header & message
				if let header2, !header2.isEmpty {
					Text(header2)
						.onboardingHeaderModifier()
				}
				if let message2, !message2.isEmpty {
					Text(message2)
						.onboardingMessageModifier()
				}
				// 3rd header & message
				if let header3, !header3.isEmpty {
					Text(header3)
						.onboardingHeaderModifier()
				}
				if let message3, !message3.isEmpty {
					Text(message3)
						.onboardingMessageModifier()
				}
				// 4th header & message
				if let header4, !header4.isEmpty {
					Text(header4)
						.onboardingHeaderModifier()
				}
				if let message4, !message4.isEmpty {
					Text(message4)
						.onboardingMessageModifier()
				}
			}
			Spacer()
		}
	}
}

// MARK: - Preview

#Preview("Onboarding") {
	OnboardingView(didFinish: {})
}
