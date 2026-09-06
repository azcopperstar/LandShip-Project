import Foundation

enum OnboardingCopy {

	enum Overview {
		static var title: String { "\(AppInfo.displayName) Overview" }
		static let systemImage = "binoculars.circle"

		static var header1: String { "What is \(AppInfo.displayName)" }
		static var message1: String {
			"Works on iPhone, iPad, and Mac. Your data lives in iCloud, so every device stays in sync automatically — enter preferences once and they carry across all your devices."
		}

		static let header2 = "Application Structure"
		static var message2: String {
			let fleetWord = Vertical.current.id == .land ? "fleet" : Vertical.current.assetPlural.lowercased()
			return "All your data lives in a single SQLite (SwiftData) database, synced to iCloud, with backup/restore to a folder on device, in Files, or iCloud Drive.\nThe sidebar opens on a Dashboard summarizing your \(fleetWord), then groups the rest into: a Full Version section (trial only), \(Vertical.current.garageSectionTitle) (\(Vertical.current.assetPlural), Parts), Data Tracking (Fuel Log, \(Vertical.current.travelLogLabel)), \(Vertical.current.assetSingular) Service (Records, Items), \(Vertical.current.assetSingular) Financials (Improvements, Expenditures), Projects/Checklists, Setup (Systems, Vendors/Shops, Settings), and Data Management (Backup…, Restore…), plus a Resources section (Help, Getting Started, What's New, Send Feedback).\nTables link together — e.g. Parts feeds pickers in Service Items, which feeds Service Records."
		}

		static let header3 = "How it's used throughout the application"
		static var message3: String {
			let fleetWord = Vertical.current.id == .land ? "fleet" : Vertical.current.assetPlural.lowercased()
			let recordMention = Vertical.current.id == .land ? ", and each can also hold CAT Scale tickets and warranty records" : ", and each can also hold warranty records"
			return "• Start at the Dashboard for an at‑a‑glance \(Vertical.current.id == .land ? "fleet" : Vertical.current.assetSingular.lowercased()) summary, filterable to one \(Vertical.current.assetSingular.lowercased()) or all.\n\n• \(Vertical.current.assetPlural) are the anchor — nearly every other table references one\(recordMention).\n\n• Systems and Parts are your shared catalogs: Systems defines the vocabularies used in pickers; Parts feeds Service Items and Service Records so names and costs stay consistent.\n\n• Log Fuel and \(Vertical.current.travelLogLabel) entries as you go; group related trips with a shared Trip Group name.\n\n• Plan with Service Items, then record the actual work as a Service Record — completed work (or a Project punch‑list item) can be transferred into Improvements when it's also an upgrade.\n\n• Reports, backups, and iCloud sync tie it together: PDF reports per \(Vertical.current.assetSingular.lowercased()) or \(fleetWord)‑wide, manual or automatic backups, and continuous sync across your devices."
		}

		static let header4 = "Quick start and typical workflow"
		static var message4: String {
			"1) Set units and Launch Screen in Setup → Settings.\n2) Add your \(Vertical.current.assetPlural.lowercased()) in \(Vertical.current.garageSectionTitle) → \(Vertical.current.assetPlural).\n3) Define vocabularies in Setup → Systems.\n4) Build your Parts catalog.\n5) Create Service Items for recurring jobs.\n6) Log Fuel and \(Vertical.current.travelLogLabel) entries as you go.\n7) Record completed work as Service Records.\n8) Check the Dashboard regularly for what's due.\n9) Generate PDF reports as needed.\n10) Back up periodically, especially before big changes.\n\nThis configure → catalog → plan → log → service → report loop keeps your data consistent and ready for decisions."
		}
	}

	enum SettingsIntro {
		static let icon = "gearshape.fill"
		static let title = "Set Up Shared Preferences"
		static let message =
		"Choose your units of measure and other preferences — you can change them anytime from Setup → Settings.\n\nTap 'Open Settings' below, then 'Save' when you're done to return here."
		static let buttonLabel = "Open Settings"
		static let buttonIcon = "slider.horizontal.3"
	}

	enum TrialIntro {
		static let icon = "gift.fill"
		static let title = "Free Trial"
		static var message: String {
			"\(AppInfo.displayName) is free to try: up to 2 \(Vertical.current.assetPlural.lowercased()) and 10 records in every table — Parts, Fuel Log, \(Vertical.current.travelLogLabel), Service Records, and more.\n\nWhen you're ready for unlimited \(Vertical.current.assetPlural.lowercased()) and records, PDF export and printing, and automatic backups, unlock the full version with a single one-time purchase. No subscription, and Restore Purchases is always available from Settings."
		}
		static let buttonLabel = "See Full Version Options"
		static let buttonIcon = "lock.open"
	}

	enum Navigation {
		static let title = "Application Navigation"
		static let systemImage = "inset.filled.leftthird.middlethird.rightthird.rectangle"

		static let header1 = "Overview"
		static var message1: String {
			"\(AppInfo.displayName) uses a three‑column layout on Mac and iPad (sidebar, list, detail); iPhone shows the same flow as swipeable pages. The Dashboard is a special case on iPad — it fills the whole detail area instead of sitting beside a list column."
		}

		static let header2 = "First Column (home screen on iPhone)"
		static var message2: String {
			"Contains the sidebar, arranged top to bottom as: a Full Version section (only shown while on the free trial, with an Unlock Full Version row and a reminder of the trial limits—this disappears once you unlock), Dashboard (a standalone summary screen, not part of a group), \(Vertical.current.garageSectionTitle) (\(Vertical.current.assetPlural), Parts), Data Tracking (Fuel Log, \(Vertical.current.travelLogLabel)), \(Vertical.current.assetSingular) Service (Records, Items), \(Vertical.current.assetSingular) Financials (Improvements, Expenditures), Projects/Checklists (Projects, Checklists), Setup (Systems, Vendors/Shops, and a Settings button), and Data Management (Backup…, Restore…, with the date of your last backup shown underneath). A Resources section at the bottom adds Help, Getting Started (re‑opens this walkthrough), What's New, and Send Feedback; on macOS, Help also lives in the system Help menu."
		}

		static let header3 = "Second Column"
		static var message3: String {
			"Shows the list for whatever's selected in the first column (e.g. selecting \(Vertical.current.assetPlural) shows your \(Vertical.current.assetPlural.lowercased()) here). A \(Vertical.current.assetSingular.lowercased()) filter at the top lets you narrow most lists to one \(Vertical.current.assetSingular.lowercased()) or '\(FleetScope.allDisplayLabel)'."
		}

		static let header4 = "Third Column"
		static let message4 =
		"Shows details for whatever's selected in the second column."
	}

	enum Dashboard {
		static let title = "Dashboard"
		static let systemImage = "rectangle.grid.2x2"

		static let header1 = "Overview"
		static var message1: String {
			let fleetWord = Vertical.current.id == .land ? "fleet" : Vertical.current.assetPlural.lowercased()
			return "The Dashboard is the app's home screen (configurable in Setup → Settings) — a scrolling set of cards summarizing your \(fleetWord). A \(Vertical.current.assetSingular) filter at the top scopes every card to one \(Vertical.current.assetSingular.lowercased()) or '\(FleetScope.allDisplayLabel)'."
		}

		static let header2 = "Dashboard cards"
		static var message2: String {
			let fleetWord = Vertical.current.id == .land ? "Fleet" : Vertical.current.assetPlural
			let fleetWordLower = fleetWord.lowercased()
			return "• \(fleetWord) Maintenance Status: Status dot per \(Vertical.current.assetSingular.lowercased()), overdue/due‑soon counts, and recent service. Tap for a System Hotlist chart.\n• Next Service Due: Most urgent upcoming items \(fleetWordLower)‑wide or per \(Vertical.current.assetSingular.lowercased()).\n• Trip Groups: Trip count, distance, fuel, and date range for grouped trips.\n• \(fleetWord) Snapshot: Active/inactive counts, \(Vertical.current.primaryMeterLabel.lowercased()), and a maintenance cost breakdown.\n• Recurring Costs & Insurance Expirations: Monthly/annual recurring spend plus insurance expiring within 90 days.\n• Warranties: Color‑coded by whichever is closer to running out — date or usage.\n• Quick Actions: Shortcuts for common tasks."
		}

		static let header3 = "Filtering and context"
		static var message3: String {
			let fleetWord = Vertical.current.id == .land ? "fleet" : Vertical.current.assetPlural.lowercased()
			return "Use the \(Vertical.current.assetSingular) picker at the top to narrow every card to one \(Vertical.current.assetSingular.lowercased()), or '\(FleetScope.allDisplayLabel)' for \(fleetWord)‑wide totals — the same filter concept used throughout the app."
		}

		static let header4 = "Tips"
		static var message4: String {
			"• Check it first when you open the app to catch overdue maintenance or expiring coverage.\n• It's the default Launch Screen — change it in Setup → Settings if you prefer another table.\n• Most cards are tappable for more detail.\n• It's only as useful as the data feeding it — keep \(Vertical.current.assetPlural), Records, \(Vertical.current.travelLogLabel), and Warranties current."
		}
	}

	enum GarageVehicles {
		static var title: String { "\(Vertical.current.garageSectionTitle) Group: \(Vertical.current.assetPlural) Table" }
		static let systemImage = "car.2.fill"

		static let header1 = "Overview"
		static var message1: String {
			"Each row in \(Vertical.current.assetPlural) is one \(Vertical.current.assetSingular.lowercased()) you track — the foundation the rest of the app references. Define \(Vertical.current.assetPlural.lowercased()) first to unlock \(Vertical.current.assetSingular.lowercased())‑specific filtering, reporting, and relationships everywhere else."
		}

		static let header2 = "Best practices"
		static var message2: String {
			let recordTip = Vertical.current.id == .land
				? "Add a Warranty record when coverage starts, and a Scale Ticket after weighing in, so the Dashboard can track both."
				: "Add a Warranty record when coverage starts, so the Dashboard can track it."
			return "• Create \(Vertical.current.assetPlural.lowercased()) first, before logging trips, fuel, or service.\n• Keep the \(Vertical.current.primaryMeterLabel.lowercased()) current — it updates automatically from trip and fuel logs.\n• Attach photos of receipts, registration, and key events.\n• \(recordTip)"
		}

		static var header3: String { "What the \(Vertical.current.assetPlural) table stores" }
		static var message3: String {
			let meterLine = Vertical.current.id == .land
				? "• \(Vertical.current.primaryMeterLabel): current reading, unit, and an optional Virtual Odometer for towed vehicles/trailers.\n"
				: "• \(Vertical.current.primaryMeterLabel): current reading and unit.\n"
			let optionalLine = Vertical.current.id == .land
				? "• Optional: tire/fluid specs, wheel/fastener specs, weight readings, photos, notes, active status."
				: "• Optional: photos, notes, active status."
			return "• Identity: name, year, make, model, trim, \(Vertical.current.registrationLabel), \(Vertical.current.plateLabel).\n" + meterLine + "• Fuel settings: type, tank size, and economy unit.\n" + optionalLine
		}

		static var header4: String { "How it's used throughout the application" }
		static var message4: String {
			let fleetWord = Vertical.current.id == .land ? "fleet" : Vertical.current.assetPlural.lowercased()
			return "• Global filter: Most lists and the Dashboard can be scoped to one \(Vertical.current.assetSingular.lowercased()) or '\(FleetScope.allDisplayLabel)'.\n• Anchors Service Records, Service Items, Parts usage, Fuel, and \(Vertical.current.travelLogLabel) entries — each \(Vertical.current.assetSingular.lowercased())'s units drive its own calculations.\n• Reports: PDF exports per \(Vertical.current.assetSingular.lowercased()) or \(fleetWord)‑wide use the \(Vertical.current.assetSingular.lowercased())'s identity and settings.\n• Lifecycle: Mark a sold/retired \(Vertical.current.assetSingular.lowercased()) inactive — its history stays intact for reporting, just hidden from quick‑pick lists."
		}

		// Land: CAT Scale weigh-station tickets. Aviation/marine: their own regulatory-adjacent
		// records instead, surfaced the same way (a Logbook report button on the detail screen).
		static var header5: String {
			switch Vertical.current.id {
				case .land: return "CAT Scale Tickets"
				case .aviation: return "Airworthiness Directives & Inspections"
				case .marine: return "Haul-Out & Survey Records"
			}
		}
		static var message5: String {
			switch Vertical.current.id {
				case .land:
					return "Each vehicle can store unlimited weigh‑station (CAT Scale) tickets — date, location, cost, and axle weights, with gross weight calculated automatically. Use “Transfer Weights to Vehicle Record” to copy steer/drive readings straight into the vehicle's stored weights."
				case .aviation:
					return "Each aircraft can track Airworthiness Directives, Inspection Cycles (annual, 100‑hour, and more), and Component Times (airframe, engine, prop). Tap the Logbook button on the aircraft's detail screen for a combined PDF covering all three."
				case .marine:
					return "Each vessel can track Haul-Out records (bottom paint, zincs, running gear) and Survey records (insurance, pre‑purchase, damage, condition & value). Tap the Logbook button on the vessel's detail screen for a combined PDF covering both."
			}
		}

		static let header6 = "Warranty Tracking"
		static var message6: String {
			let limitWord = Vertical.current.id == .land ? "mileage" : "usage"
			return "Track unlimited warranties per \(Vertical.current.assetSingular.lowercased()) — factory, extended, or component‑specific — each with a start date and length (which calculates the expiration) plus an optional \(limitWord) limit. The Dashboard's Warranties card flags each in green/yellow/red based on whichever is closer to running out."
		}
	}

	enum GarageParts {
		static let title = "Garage: Parts Table"
		static let systemImage = "gearshape.2.fill"
		static let header1 = "Overview"
		static let message1 =
		"Parts is your catalog of components and consumables. Define each part once, then reuse it in Service Items and Service Records for consistent naming, pricing, and cost reporting."
		static let header2 = "Best practices"
		static var message2: String {
			"• Define common parts once and reuse them across \(Vertical.current.assetPlural.lowercased()).\n• Use clear, searchable names (brand, series, size).\n• Track unit cost and package quantity for accurate cost rollups.\n• Link a preferred vendor and SKU to speed reordering."
		}
		static let header3 = "What the Parts table stores"
		static let message3 =
		"• Identity: name, brand, model/series, part numbers.\n• Pricing: unit cost, package size/quantity.\n• Vendor: preferred vendor and SKU.\n• Optional: photos, notes, category/tags, active status."
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Service Items and Records reference Parts for consistent names and costs.\n• Usage rolls up into cost‑per‑service and cost‑per‑mile metrics, and into PDF reports.\n• Editing a part updates future entries; past records keep their original values."
	}

	enum DataTracking_Fuel {
		static let title = "Data Tracking: Fuel Log"
		static let systemImage = "fuelpump.arrowtriangle.left"

		static let header1 = "Overview"
		static var message1: String {
			let secondary = Vertical.current.secondaryMeterLabel.isEmpty ? "" : " and \(Vertical.current.secondaryMeterLabel.lowercased())"
			return "Fuel Log records every fill‑up — date, location, \(Vertical.current.primaryMeterLabel.lowercased()), volume, price, and notes. It powers fuel economy, cost‑per‑distance, and long‑term cost analysis, and automatically updates the \(Vertical.current.assetSingular.lowercased())'s \(Vertical.current.primaryMeterLabel.lowercased())\(secondary)."
		}

		static let header2 = "Best practices"
		static var message2: String {
			"• Log every fill‑up, even partial ones.\n• Enter volume in the units on your receipt — the app converts for display.\n• Record the \(Vertical.current.primaryMeterLabel.lowercased()) at the pump for accurate economy metrics.\n• Attach receipts, and use the Fluid Checks popup (customize which checks appear in Settings)."
		}

		static let header3 = "What the Fuel Log stores"
		static var message3: String {
			"• \(Vertical.current.assetSingular), date/time, and location.\n• \(Vertical.current.primaryMeterLabel) reading and computed distance since the last fill.\n• Volume, price, and total cost; optional DEF price/level for diesel.\n• Optional fluid‑check results, receipt photos, and notes."
		}

		static let header4 = "How it's used throughout the application"
		static var message4: String {
			"• Drives per‑\(Vertical.current.assetSingular.lowercased()) fuel economy and cost‑per‑mile on the Dashboard and in PDF reports.\n• Appears alongside \(Vertical.current.travelLogLabel) and Service Records in each \(Vertical.current.assetSingular.lowercased())'s timeline.\n• Calculations respect each \(Vertical.current.assetSingular.lowercased())'s configured units."
		}
	}

	enum DataTracking_Travel {
		static var title: String { "Data Tracking: \(Vertical.current.travelLogLabel)" }
		static let systemImage = "map"

		static let header1 = "Overview"
		static var message1: String {
			"\(Vertical.current.travelLogLabel) captures trips — start/end \(Vertical.current.primaryMeterLabel.lowercased()), distance, purpose, en‑route stops, and attachments. It supports mileage reimbursement, tax reporting, and utilization analysis."
		}

		static let header2 = "Best practices"
		static let message2 =
		"• Log both business and personal trips; tag them to separate for reporting.\n• Capture accurate start/end readings.\n• Note purpose, cargo, or conditions that affect the trip.\n• Give multi‑leg trips a shared Trip Group name to see combined totals."

		static var header3: String { "What the \(Vertical.current.travelLogLabel) stores" }
		static var message3: String {
			"• \(Vertical.current.assetSingular), start/end date/time, and computed distance.\n• Time stats: elapsed, underway, and engine time.\n• En‑route stops with photos, time, and a Stop Reason.\n• Trip Group name, purpose/classification, and notes."
		}

		static let header4 = "How it's used throughout the application"
		static var message4: String {
			"• Generates mileage reports for reimbursement, tax, or client billing.\n• Trips sharing a Trip Group name roll up on the Dashboard's Trip Groups card.\n• Appears alongside Fuel Log and Service Records for a full per‑\(Vertical.current.assetSingular.lowercased()) timeline."
		}
	}

	enum VehicleService_Records {
		static var title: String { "\(Vertical.current.assetSingular) Service: Records" }
		static let systemImage = "wrench.and.screwdriver.fill"

		static let header1 = "Overview"
		static var message1: String {
			"Service Records document maintenance and repairs — the \(Vertical.current.assetSingular.lowercased()), work performed, vendor, parts, labor, and cost. This is your true maintenance history and total cost of ownership."
		}

		static let header2 = "Best practices"
		static var message2: String {
			"• Log work right after it's done, with \(Vertical.current.primaryMeterLabel.lowercased()) and a clear description.\n• Link a Service Item when applicable to close out the plan and track due dates.\n• Itemize parts and labor for accurate cost totals.\n• Attach receipts/invoices, and transfer upgrade work to Improvements."
		}

		static var header3: String { "What the Service Records table stores" }
		static var message3: String {
			let meters = Vertical.current.secondaryMeterLabel.isEmpty ? Vertical.current.primaryMeterLabel : "\(Vertical.current.primaryMeterLabel)/\(Vertical.current.secondaryMeterLabel)"
			return "• \(Vertical.current.assetSingular), date, \(meters.lowercased()), and description.\n• Optional link to a Service Item.\n• Parts and labor line items with costs.\n• Vendor, photos, notes, and system/category tags."
		}

		static let header4 = "How it's used throughout the application"
		static var message4: String {
			"• Forms each \(Vertical.current.assetSingular.lowercased())'s maintenance history, shown on the Dashboard's Maintenance Status card.\n• Rolls up parts/labor into cost and total‑cost‑of‑ownership tracking.\n• Completing a linked Service Item resets its due counters.\n• Transfer parts or labor into Improvements when the work is also an upgrade."
		}
	}

	enum VehicleService_Items {
		static var title: String { "\(Vertical.current.assetSingular) Service: Items" }
		static let systemImage = "folder.badge.gearshape"

		static let header1 = "Overview"
		static let message1 =
		"Service Items are reusable maintenance templates (e.g. 'Engine Oil & Filter') with a default vendor, labor estimate, interval, and parts bundle. Selecting one on a new Service Record pre‑fills all of it."

		static let header2 = "Best practices"
		static let message2 =
		"• One template per recurring job, named specifically enough to be unambiguous.\n• Set realistic defaults — vendor, labor cost, and typical parts — for near one‑tap entry.\n• Use intervals (miles/months/hours) as planning hints; they feed the Dashboard's Next Service Due card.\n• Update the template as pricing changes — past records keep their original values."

		static var header3: String { "What the Service Items table stores" }
		static var message3: String {
			"• \(Vertical.current.assetSingular)/system scope and item name.\n• Default vendor, labor estimate, and interval fields.\n• Up to five parts (name, quantity, unit, cost) and up to three reference images."
		}

		static let header4 = "How it's used throughout the application"
		static var message4: String {
			"• Prefills new Service Records — description, vendor, labor, parts — which you can still edit.\n• Keeps parts and costs consistent across \(Vertical.current.assetPlural.lowercased()) and reports.\n• Interval fields drive the Dashboard's Maintenance Status and Next Service Due cards."
		}
	}

	enum Setup_Systems {
		static let title = "Setup: Systems"
		static let systemImage = "glowplug"
		static let header1 = "Overview"
		static var message1: String {
			"Systems centralizes the controlled vocabularies used in pickers across the app — \(Vertical.current.assetSingular.lowercased()) systems, service categories, parts categories, and more. Keeping these consistent prevents typos and duplicate entries."
		}
		static let header2 = "Best practices"
		static let message2 =
		"• Keep names short and specific (e.g. 'Engine,' 'Brakes').\n• Rename instead of deleting terms already in use; inactivate unused ones.\n• Decide on a stable set before heavy data entry.\n• Set sort order so common terms appear first in pickers."
		static let header3 = "What the Systems table stores"
		static var message3: String {
			"• Type (\(Vertical.current.assetSingular.lowercased()) system, service category, parts category, etc.) and name.\n• Optional description, icon/color, and sort order.\n• Active flag — inactive terms stay available on existing records."
		}
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Drives the picker options in Service Items, Service Records, Parts, and Travel Log.\n• Powers grouping in reports and the Dashboard's System Hotlist chart.\n• Inactivating a term hides it from new entries without touching history; renaming updates future labels only."
	}

	enum Setup_Vendors {
		static let title = "Setup: Vendors / Shops"
		static let systemImage = "person.2.badge.gearshape"
		static let header1 = "Overview"
		static let message1 =
		"Vendors/Shops is your directory of businesses and people who sell parts or perform service. Centralizing them keeps entry consistent and enables spend analysis by vendor."
		static let header2 = "Best practices"
		static let message2 =
		"• Capture full contact info — phone, website, address.\n• Use categories/tags by specialty (Tires, Brakes, Dealer).\n• Track your account number and preferred technician.\n• Inactivate rather than delete vendors you no longer use."
		static let header3 = "What the Vendors/Shops table stores"
		static let message3 =
		"• Name, contact details, and category/specialty.\n• Account number, labor rate, and payment terms.\n• Documents, notes, active status, and sort order."
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Parts, Service Items, and Service Records all reference vendors for consistent selection and spend reporting.\n• Tap a vendor to call, email, or get directions.\n• Inactive vendors are hidden from new entries but existing records stay linked."
	}

	enum Setup_Settings {
		static let title = "Setup: Settings"
		static let systemImage = "gearshape"
		static let header1 = "Overview"
		static var message1: String {
			"The Settings screen (Setup → Settings) defines the shared preferences that control how \(AppInfo.displayName) behaves and how information is displayed — units of measure, Launch Screen, which fluid checks appear, and full‑version status. Most preferences sync via iCloud; a few purely device‑local ones (like showing inactive \(Vertical.current.assetPlural.lowercased())) don't."
		}
		static let header2 = "Best practices"
		static var message2: String {
			"• Set your preferred units before entering data — \(Vertical.current.assetSingular.lowercased())‑specific units always drive calculations; this controls display.\n• Choose a Launch Screen if you don't want to start on the Dashboard.\n• Tailor Fluid Checks to only what you actually check.\n• Enter data in real‑world units from receipts/\(Vertical.current.primaryMeterLabel.lowercased())s; let the app convert for display."
		}
		static let header3 = "What Settings stores"
		static var message3: String {
			"• Full Version: Shows whether you're on the free trial or have unlocked the full version, with buttons to unlock or Restore Purchases.\n• \(Vertical.current.assetPlural): A “Show Inactive in Lists” toggle (device‑local).\n• Units of Measure: 13 pickers covering fuel/oil/DEF, temperature, speed, pressure, mass, distance, area, and \(Vertical.current.assetSingular.lowercased()) dimensions.\n• App Behaviour: A Launch Screen picker that determines which screen the app opens to.\n• Automatic Backups: Frequency and retention count, plus a link to manage them. Requires the full version.\n• Fuel Log — Fluid Checks: Which checks appear in the Fluid Checks popup.\n• Onboarding: A “Reset Startup Screens…” action that brings back this walkthrough on next launch."
		}
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Editors and pickers throughout the app use your configured units for display and entry.\n• The Launch Screen setting picks the sidebar item selected automatically at startup.\n• Fluid Checks popups only show what you've left enabled here.\n• Units, Launch Screen, and Fluid Check preferences sync via iCloud across your devices.\n• Restore Purchases here re‑unlocks the full version on a new device — no repurchase needed."
	}

	enum Additions {
		static let title = "Improvements & Add-Ins"
		static let systemImage = "square.grid.3x1.folder.badge.plus"
		static let header1 = "Overview"
		static var message1: String {
			"Improvements (\(Vertical.current.assetSingular) Financials → Improvements) tracks upgrades, modifications, and accessories — cost, vendor, category, photos, and \(Vertical.current.primaryMeterLabel.lowercased()) at install. Useful for warranty, resale, and insurance documentation."
		}
		static let header2 = "Best practices"
		static let message2 =
		"• Use categories/sub‑categories for organized cost rollups.\n• Enter the full installed cost, including labor.\n• Link a vendor and attach before/after photos.\n• Transfer upgrade work from a Service Record or Project item instead of re‑entering it."
		static let header3 = "What the Add-Ins table stores"
		static var message3: String {
			"• Name, category/sub‑category, and description.\n• \(Vertical.current.assetSingular), \(Vertical.current.primaryMeterLabel.lowercased())/hours at install, vendor, and cost.\n• Up to five photos and notes."
		}
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Contributes to fleet‑wide cost totals on the Dashboard.\n• Grouped by category with running subtotals and a grand total.\n• PDF reports by vehicle or fleet‑wide.\n• Items transferred from Service Records or Projects stay in sync if cost or vendor is later edited."
	}

	enum Subscriptions {
		static let title = "Expenses & Subscriptions"
		static let systemImage = "calendar.badge.clock"
		static let header1 = "Overview"
		static var message1: String {
			"Expenditures (\(Vertical.current.assetSingular) Financials → Expenditures) tracks recurring and one‑time costs — insurance, registration, memberships, subscriptions, lease payments — for a complete picture of ownership cost beyond fuel and service."
		}
		static let header2 = "Best practices"
		static let message2 =
		"• Flag recurring charges so the Dashboard totals them correctly.\n• Use categories/sub‑categories for budgeting.\n• Note renewal dates so nothing lapses unexpectedly.\n• Link a vendor and attach policy documents or receipts."
		static let header3 = "What the Expenses & Subscriptions table stores"
		static var message3: String {
			"• Name, category/sub‑category, and description.\n• \(Vertical.current.assetSingular), vendor, cost, and a recurring flag.\n• Up to five photos and notes."
		}
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Category subtotals and a grand total are always visible.\n• Recurring charges roll into the Dashboard's Recurring Costs card alongside insurance expirations.\n• PDF reports by vehicle for budgeting and total cost of ownership."
	}

	enum Projects {
		static let title = "Projects & Punch Lists"
		static let systemImage = "list.number.badge.ellipsis"
		static let header1 = "Overview"
		static let message1 =
		"Projects lets you plan and track multi‑step work — restorations, seasonal prep, builds — through an ordered Punch List of items you check off as you go."
		static let header2 = "Best practices"
		static var message2: String {
			"• Break work into small, actionable punch‑list items.\n• Use categories to organize larger builds; drag to reorder.\n• Link each project to a \(Vertical.current.assetSingular.lowercased()).\n• Use the Live Punch List for real‑time, in‑garage checkoff.\n• Transfer completed upgrade items to Improvements."
		}
		static let header3 = "What the Projects table stores"
		static var message3: String {
			"• Name, category/sub‑category, description, and \(Vertical.current.assetSingular.lowercased()).\n• An ordered list of punch‑list items with completion status."
		}
		static let header4 = "How it's used throughout the application"
		static var message4: String {
			"• Browse projects by \(Vertical.current.assetSingular.lowercased()) or fleet‑wide, grouped into reorderable categories.\n• The Live Punch List gives a streamlined in‑garage checklist.\n• Transfer any item to Improvements to roll it into your modification history.\n• Two PDF reports: a Project List summary and a detailed Punch List."
		}
	}

	enum CheckLists {
		static let title = "CheckLists & Sub-Items"
		static let systemImage = "checklist"
		static let header1 = "Overview"
		static let message1 =
		"CheckLists is a reusable checklist system for routine inspections and recurring processes — unlike Projects, checklists are meant to be used again and again. Items can contain sub‑items, with completion synced automatically between parent and child."
		static let header2 = "Sub-Items and Hierarchical Tasks"
		static let message2 =
		"• Add unlimited sub‑items to break a task into steps.\n• Checking a parent completes all its sub‑items, and vice versa.\n• Rename the sub‑items label per item (e.g. 'Steps,' 'Tasks').\n• Deleting a parent removes its sub‑items too."
		static let header3 = "What the CheckLists table stores"
		static var message3: String {
			"• Name, category, description, \(Vertical.current.assetSingular.lowercased()), and ordered items.\n• Items and sub‑items with completion status and notes."
		}
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• The Live CheckList gives a streamlined in‑field checkoff experience.\n• Expand any item inline to manage its sub‑items.\n• Reuse a checklist by clearing completion status for the next cycle.\n• PDF report of items and completion status."
	}

	enum DataManagement_BackupRestore {
		static let title = "Data Management: Backup / Restore"
		static let systemImage = "square.and.arrow.up"
		static var header1: String { "Overview" }
		static var message1: String {
			"Backup exports a real folder — your database, documents, and browsable photos — to a location you choose (device, Files, or iCloud Drive). Restore brings a backup's contents back into the app. Since \(AppInfo.displayName) also syncs continuously via iCloud, think of Backup/Restore as a manual, point‑in‑time snapshot that complements that sync."
		}
		static let header2 = "Best practices"
		static let message2 =
		"• Back up before major changes, and save copies off‑device (Files/iCloud Drive), not just on‑device.\n• Let iCloud finish syncing before backing up or restoring, for a consistent snapshot.\n• Restart when asked after a restore — the app needs a full restart to finish safely.\n• If iCloud sync is on, prefer “Resync from iCloud” (the default) — it re‑downloads your data fresh rather than reviving the backup's exact snapshot. Use “Restore Exact Snapshot” only when moving to a different iCloud account or recovering from bad iCloud data.\n• Turn on Automatic Backups (Settings) so you always have a recent one — requires the full version; manual Backup…/Restore… are always free."
		static let header3 = "What a backup contains"
		static let message3 =
		"• An AppInfo.txt file identifying the app version and backup date.\n• Your full app database (Application Support folder).\n• Your Documents folder, including generated PDF reports.\n• A Media folder — every photo re‑exported as ordinary image files, for browsing outside the app (not needed to restore)."
		static let header4 = "How it's used throughout the application"
		static let message4 =
		"• Backup…: Gathers your data in the background, then the system file picker lets you choose where to save it. A summary sheet lists everything included.\n• Restore…: Pick a source — a manual backup folder, or one of your automatic backups — then confirm. If iCloud sync is active, choose “Resync from iCloud” (recommended) or “Restore Exact Snapshot.” An interrupted restore rolls back safely rather than leaving things half‑done.\n• Cross‑device: A backup from any platform can be restored on another, using the same Apple ID.\n• Automatic Backups: Set a frequency and retention count in Settings (full version only); manage, restore from, or share any of them via “Manage Auto‑Backups…”."
	}
}
