// HelpView.swift
import SwiftUI

struct HelpView: View {
	// Presents the feedback form. Lives here as well as in the iOS sidebar's Resources
	// section, since on macOS the Help window is the only route to it.
	@State private var showingFeedbackSheet = false

	// Stable identifiers for each section we want to link to
	private enum SectionID: String, CaseIterable, Hashable {
		case overview
		case navigation
		case dashboard
		case garageVehicles
		case garageParts
		case dataTrackingFuel
		case dataTrackingTravel
		case vehicleServiceRecords
		case vehicleServiceItems
		case additions
		case subscriptions
		case projects
		case checkLists
		case setupSystems
		case setupVendors
		case setupSettings
		case dataManagementBackupRestore
		case releaseNotes
		case support

		var title: String {
			switch self {
			case .overview: return OnboardingCopy.Overview.title
			case .navigation: return OnboardingCopy.Navigation.title
			case .dashboard: return OnboardingCopy.Dashboard.title
			case .garageVehicles: return OnboardingCopy.GarageVehicles.title
			case .garageParts: return OnboardingCopy.GarageParts.title
			case .dataTrackingFuel: return OnboardingCopy.DataTracking_Fuel.title
			case .dataTrackingTravel: return OnboardingCopy.DataTracking_Travel.title
			case .vehicleServiceRecords: return OnboardingCopy.VehicleService_Records.title
			case .vehicleServiceItems: return OnboardingCopy.VehicleService_Items.title
			case .additions: return OnboardingCopy.Additions.title
			case .subscriptions: return OnboardingCopy.Subscriptions.title
			case .projects: return OnboardingCopy.Projects.title
			case .checkLists: return OnboardingCopy.CheckLists.title
			case .setupSystems: return OnboardingCopy.Setup_Systems.title
			case .setupVendors: return OnboardingCopy.Setup_Vendors.title
			case .setupSettings: return OnboardingCopy.Setup_Settings.title
			case .dataManagementBackupRestore: return OnboardingCopy.DataManagement_BackupRestore.title
			case .releaseNotes: return "What's New"
			case .support: return "Support"
			}
		}
	}

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					// App header
					VStack(alignment: .leading, spacing: 4) {
						Text(AppInfo.displayName)
							.font(.title).bold()
						Text("Version \(AppInfo.version)")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}

					// Table of Contents
					VStack(alignment: .leading, spacing: 8) {
						Text("Jump to a section")
							.font(.headline)
						ForEach(SectionID.allCases, id: \.self) { id in
							Button {
								withAnimation {
									proxy.scrollTo(id, anchor: .top)
								}
							} label: {
								Text(id.title)
									.underline()
									.foregroundStyle(.tint)
							}
							#if os(macOS)
							.buttonStyle(.link)
							#else
							.buttonStyle(.plain)
							#endif
							.accessibilityHint("Scrolls to the \(id.title) section")
						}
					}
					.padding(.bottom, 8)

					Divider()

					// Overview
					HelpSectionView(
						title: OnboardingCopy.Overview.title,
						systemImage: OnboardingCopy.Overview.systemImage,
						sections: [
							(OnboardingCopy.Overview.header1, OnboardingCopy.Overview.message1),
							(OnboardingCopy.Overview.header2, OnboardingCopy.Overview.message2),
							(OnboardingCopy.Overview.header3, OnboardingCopy.Overview.message3),
							(OnboardingCopy.Overview.header4, OnboardingCopy.Overview.message4)
						]
					)
					.id(SectionID.overview)

					// Navigation
					HelpSectionView(
						title: OnboardingCopy.Navigation.title,
						systemImage: OnboardingCopy.Navigation.systemImage,
						sections: [
							(OnboardingCopy.Navigation.header1, OnboardingCopy.Navigation.message1),
							(OnboardingCopy.Navigation.header2, OnboardingCopy.Navigation.message2),
							(OnboardingCopy.Navigation.header3, OnboardingCopy.Navigation.message3),
							(OnboardingCopy.Navigation.header4, OnboardingCopy.Navigation.message4)
						]
					)
					.id(SectionID.navigation)

					// Dashboard
					HelpSectionView(
						title: OnboardingCopy.Dashboard.title,
						systemImage: OnboardingCopy.Dashboard.systemImage,
						sections: [
							(OnboardingCopy.Dashboard.header1, OnboardingCopy.Dashboard.message1),
							(OnboardingCopy.Dashboard.header2, OnboardingCopy.Dashboard.message2),
							(OnboardingCopy.Dashboard.header3, OnboardingCopy.Dashboard.message3),
							(OnboardingCopy.Dashboard.header4, OnboardingCopy.Dashboard.message4)
						]
					)
					.id(SectionID.dashboard)

					// Garage - Vehicles
					HelpSectionView(
						title: OnboardingCopy.GarageVehicles.title,
						systemImage: OnboardingCopy.GarageVehicles.systemImage,
						sections: [
							(OnboardingCopy.GarageVehicles.header1, OnboardingCopy.GarageVehicles.message1),
							(OnboardingCopy.GarageVehicles.header2, OnboardingCopy.GarageVehicles.message2),
							(OnboardingCopy.GarageVehicles.header3, OnboardingCopy.GarageVehicles.message3),
							(OnboardingCopy.GarageVehicles.header4, OnboardingCopy.GarageVehicles.message4),
							(OnboardingCopy.GarageVehicles.header5, OnboardingCopy.GarageVehicles.message5),
							(OnboardingCopy.GarageVehicles.header6, OnboardingCopy.GarageVehicles.message6)
						]
					)
					.id(SectionID.garageVehicles)

					// Garage - Parts
					HelpSectionView(
						title: OnboardingCopy.GarageParts.title,
						systemImage: OnboardingCopy.GarageParts.systemImage,
						sections: [
							(OnboardingCopy.GarageParts.header1, OnboardingCopy.GarageParts.message1),
							(OnboardingCopy.GarageParts.header2, OnboardingCopy.GarageParts.message2),
							(OnboardingCopy.GarageParts.header3, OnboardingCopy.GarageParts.message3),
							(OnboardingCopy.GarageParts.header4, OnboardingCopy.GarageParts.message4)
						]
					)
					.id(SectionID.garageParts)

					// Data Tracking - Fuel
					HelpSectionView(
						title: OnboardingCopy.DataTracking_Fuel.title,
						systemImage: OnboardingCopy.DataTracking_Fuel.systemImage,
						sections: [
							(OnboardingCopy.DataTracking_Fuel.header1, OnboardingCopy.DataTracking_Fuel.message1),
							(OnboardingCopy.DataTracking_Fuel.header2, OnboardingCopy.DataTracking_Fuel.message2),
							(OnboardingCopy.DataTracking_Fuel.header3, OnboardingCopy.DataTracking_Fuel.message3),
							(OnboardingCopy.DataTracking_Fuel.header4, OnboardingCopy.DataTracking_Fuel.message4)
						]
					)
					.id(SectionID.dataTrackingFuel)

					// Data Tracking - Travel
					HelpSectionView(
						title: OnboardingCopy.DataTracking_Travel.title,
						systemImage: OnboardingCopy.DataTracking_Travel.systemImage,
						sections: [
							(OnboardingCopy.DataTracking_Travel.header1, OnboardingCopy.DataTracking_Travel.message1),
							(OnboardingCopy.DataTracking_Travel.header2, OnboardingCopy.DataTracking_Travel.message2),
							(OnboardingCopy.DataTracking_Travel.header3, OnboardingCopy.DataTracking_Travel.message3),
							(OnboardingCopy.DataTracking_Travel.header4, OnboardingCopy.DataTracking_Travel.message4)
						]
					)
					.id(SectionID.dataTrackingTravel)

					// Vehicle Service - Records
					HelpSectionView(
						title: OnboardingCopy.VehicleService_Records.title,
						systemImage: OnboardingCopy.VehicleService_Records.systemImage,
						sections: [
							(OnboardingCopy.VehicleService_Records.header1, OnboardingCopy.VehicleService_Records.message1),
							(OnboardingCopy.VehicleService_Records.header2, OnboardingCopy.VehicleService_Records.message2),
							(OnboardingCopy.VehicleService_Records.header3, OnboardingCopy.VehicleService_Records.message3),
							(OnboardingCopy.VehicleService_Records.header4, OnboardingCopy.VehicleService_Records.message4)
						]
					)
					.id(SectionID.vehicleServiceRecords)

					// Vehicle Service - Items
					HelpSectionView(
						title: OnboardingCopy.VehicleService_Items.title,
						systemImage: OnboardingCopy.VehicleService_Items.systemImage,
						sections: [
							(OnboardingCopy.VehicleService_Items.header1, OnboardingCopy.VehicleService_Items.message1),
							(OnboardingCopy.VehicleService_Items.header2, OnboardingCopy.VehicleService_Items.message2),
							(OnboardingCopy.VehicleService_Items.header3, OnboardingCopy.VehicleService_Items.message3),
							(OnboardingCopy.VehicleService_Items.header4, OnboardingCopy.VehicleService_Items.message4)
						]
					)
					.id(SectionID.vehicleServiceItems)

					// Vehicle Financials - Improvements & Add-Ins
					HelpSectionView(
						title: OnboardingCopy.Additions.title,
						systemImage: OnboardingCopy.Additions.systemImage,
						sections: [
							(OnboardingCopy.Additions.header1, OnboardingCopy.Additions.message1),
							(OnboardingCopy.Additions.header2, OnboardingCopy.Additions.message2),
							(OnboardingCopy.Additions.header3, OnboardingCopy.Additions.message3),
							(OnboardingCopy.Additions.header4, OnboardingCopy.Additions.message4)
						]
					)
					.id(SectionID.additions)

					// Vehicle Financials - Expenses & Subscriptions
					HelpSectionView(
						title: OnboardingCopy.Subscriptions.title,
						systemImage: OnboardingCopy.Subscriptions.systemImage,
						sections: [
							(OnboardingCopy.Subscriptions.header1, OnboardingCopy.Subscriptions.message1),
							(OnboardingCopy.Subscriptions.header2, OnboardingCopy.Subscriptions.message2),
							(OnboardingCopy.Subscriptions.header3, OnboardingCopy.Subscriptions.message3),
							(OnboardingCopy.Subscriptions.header4, OnboardingCopy.Subscriptions.message4)
						]
					)
					.id(SectionID.subscriptions)

					// Projects & Punch Lists
					HelpSectionView(
						title: OnboardingCopy.Projects.title,
						systemImage: OnboardingCopy.Projects.systemImage,
						sections: [
							(OnboardingCopy.Projects.header1, OnboardingCopy.Projects.message1),
							(OnboardingCopy.Projects.header2, OnboardingCopy.Projects.message2),
							(OnboardingCopy.Projects.header3, OnboardingCopy.Projects.message3),
							(OnboardingCopy.Projects.header4, OnboardingCopy.Projects.message4)
						]
					)
					.id(SectionID.projects)

					// CheckLists & Sub-Items
					HelpSectionView(
						title: OnboardingCopy.CheckLists.title,
						systemImage: OnboardingCopy.CheckLists.systemImage,
						sections: [
							(OnboardingCopy.CheckLists.header1, OnboardingCopy.CheckLists.message1),
							(OnboardingCopy.CheckLists.header2, OnboardingCopy.CheckLists.message2),
							(OnboardingCopy.CheckLists.header3, OnboardingCopy.CheckLists.message3),
							(OnboardingCopy.CheckLists.header4, OnboardingCopy.CheckLists.message4)
						]
					)
					.id(SectionID.checkLists)

					// Setup - Systems
					HelpSectionView(
						title: OnboardingCopy.Setup_Systems.title,
						systemImage: OnboardingCopy.Setup_Systems.systemImage,
						sections: [
							(OnboardingCopy.Setup_Systems.header1, OnboardingCopy.Setup_Systems.message1),
							(OnboardingCopy.Setup_Systems.header2, OnboardingCopy.Setup_Systems.message2),
							(OnboardingCopy.Setup_Systems.header3, OnboardingCopy.Setup_Systems.message3),
							(OnboardingCopy.Setup_Systems.header4, OnboardingCopy.Setup_Systems.message4)
						]
					)
					.id(SectionID.setupSystems)

					// Setup - Vendors/Shops
					HelpSectionView(
						title: OnboardingCopy.Setup_Vendors.title,
						systemImage: OnboardingCopy.Setup_Vendors.systemImage,
						sections: [
							(OnboardingCopy.Setup_Vendors.header1, OnboardingCopy.Setup_Vendors.message1),
							(OnboardingCopy.Setup_Vendors.header2, OnboardingCopy.Setup_Vendors.message2),
							(OnboardingCopy.Setup_Vendors.header3, OnboardingCopy.Setup_Vendors.message3),
							(OnboardingCopy.Setup_Vendors.header4, OnboardingCopy.Setup_Vendors.message4)
						]
					)
					.id(SectionID.setupVendors)

					// Setup - Settings
					HelpSectionView(
						title: OnboardingCopy.Setup_Settings.title,
						systemImage: OnboardingCopy.Setup_Settings.systemImage,
						sections: [
							(OnboardingCopy.Setup_Settings.header1, OnboardingCopy.Setup_Settings.message1),
							(OnboardingCopy.Setup_Settings.header2, OnboardingCopy.Setup_Settings.message2),
							(OnboardingCopy.Setup_Settings.header3, OnboardingCopy.Setup_Settings.message3),
							(OnboardingCopy.Setup_Settings.header4, OnboardingCopy.Setup_Settings.message4)
						]
					)
					.id(SectionID.setupSettings)

					// Data Management - Backup / Restore
					HelpSectionView(
						title: OnboardingCopy.DataManagement_BackupRestore.title,
						systemImage: OnboardingCopy.DataManagement_BackupRestore.systemImage,
						sections: [
							(OnboardingCopy.DataManagement_BackupRestore.header1, OnboardingCopy.DataManagement_BackupRestore.message1),
							(OnboardingCopy.DataManagement_BackupRestore.header2, OnboardingCopy.DataManagement_BackupRestore.message2),
							(OnboardingCopy.DataManagement_BackupRestore.header3, OnboardingCopy.DataManagement_BackupRestore.message3),
							(OnboardingCopy.DataManagement_BackupRestore.header4, OnboardingCopy.DataManagement_BackupRestore.message4)
						]
					)
					.id(SectionID.dataManagementBackupRestore)

					Divider()

					// What's New (live from changelog.md — always reflects the current file, no manual updates needed here)
					VStack(alignment: .leading, spacing: 8) {
						Label("What's New", systemImage: "clock.arrow.circlepath")
							.font(.headline)
						Text("This section is generated live from the app's built-in changelog. Whenever that file changes, the version history below updates automatically.")
							.font(.subheadline)
							.foregroundStyle(.secondary)
						ChangelogList()
							.padding(.top, 4)
					}
					.id(SectionID.releaseNotes)

					Divider()

					// Support
					VStack(alignment: .leading, spacing: 8) {
						Text("Support")
							.font(.headline)
						Text("If you need help or have feedback, please reach out. The form below collects a suggestion, improvement or problem report and hands it to your mail app, already filled in.")
						Button {
							showingFeedbackSheet = true
						} label: {
							Label("Send Feedback…", systemImage: "paperplane")
						}
						.buttonStyle(.borderedProminent)
						Link("Email Support: \(FeedbackView.supportAddress)",
							 destination: URL(string: "mailto:\(FeedbackView.supportAddress)")!)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.id(SectionID.support)
				}
				.padding()
			}
			.sheet(isPresented: $showingFeedbackSheet) {
				FeedbackSheet { showingFeedbackSheet = false }
			}
			// Optional: support deep-linking like myapp://help/overview
			.onOpenURL { url in
				guard url.host?.lowercased() == "help" else { return }
				let last = url.lastPathComponent.lowercased()
				if let target = SectionID(rawValue: last) {
					withAnimation {
						proxy.scrollTo(target, anchor: .top)
					}
				}
			}
		}
	}
}

// Small helper view to render a titled section with header/message pairs
private struct HelpSectionView: View {
	let title: String
	let systemImage: String?
	let sections: [(String, String)]

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let systemImage, !systemImage.isEmpty {
				Label(title, systemImage: systemImage)
					.font(.headline)
			} else {
				Text(title)
					.font(.headline)
			}
			ForEach(Array(sections.enumerated()), id: \.offset) { _, pair in
				VStack(alignment: .leading, spacing: 4) {
					Text(pair.0)
						.font(.subheadline).bold()
					Text(pair.1)
				}
				.padding(.top, 4)
			}
		}
	}
}

#Preview {
	HelpView()
}
