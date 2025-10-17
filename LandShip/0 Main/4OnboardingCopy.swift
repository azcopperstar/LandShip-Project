import Foundation

enum OnboardingCopy {
	
	enum Overview {
		static var title: String { "\(AppInfo.displayName) Overview" }
		static let systemImage = "binoculars.circle"
		
		static var header1: String { "What is \(AppInfo.displayName)" }
		static var message1: String {
			"\(AppInfo.displayName) has been designed to work with both iOS (iPhone/iPad) and macOS (Macbook Pro/Air).  Data for the application is hosted on your iCloud account and is synchonized between all of the devices on that specific Apple account.  This means that you can install \(AppInfo.displayName) on multiple devices (Mac, iPad, iPhone) and they will all be in sync.\nMost preferences & settings are also synced between devices.  They only need to be entered once."
		}
		
		static let header2 = "Application Structure"
		static var message2: String {
			"\(AppInfo.displayName) is a database application.  All entered data is stored in a single SQLite database on your device and is synced to your iCloud account.  The ability also exists to backup and restore your data files to device.\nThe sidebar menu (left most column) contains the tables for the four main groups of data: Garage, Data Tracking, Vehicle Service and Setup.  There are eight data tables that interact with relationships between each other (e.g., adding entries to the 'Parts' table will provide dropdown selections for the 'Service Items' table, which will then be used as dropdown selections in the 'Service Records' table)."
		}

		static let header3 = "How \(AppInfo.displayName) is used throughout the application"
		static var message3: String {
			"• Vehicles as the anchor: Begin by defining your vehicles in the Garage → Vehicles table. Nearly every other table references a vehicle so you can filter, report, and analyze per‑vehicle or across your entire garage.\n\n• Consistent dropdowns from shared catalogs: Setup → Systems provides the controlled vocabularies (systems, categories) that appear in pickers across the app. Garage → Parts is your single source of truth for consumables and components; those parts are reused in Vehicle Service → Items (maintenance templates) and Vehicle Service → Records (work performed) so names and costs stay consistent.\n\n• Day‑to‑day logging: Use Data Tracking → Fuel Log to capture each fill‑up (volume, price, odometer, receipts) and Data Tracking → Travel Log to record trips (start/end odometer, time, purpose, attachments). These entries drive fuel economy, utilization, and cost‑per‑distance metrics on a per‑vehicle basis.\n\n• Planning vs. doing: Vehicle Service → Items defines the reusable templates for recurring jobs (e.g., oil & filter). When work is actually performed, create a Vehicle Service → Record. Selecting a Service Item will prefill description, vendor, labor, and the parts bundle so entry is fast and consistent.\n\n• Unified navigation and context: On macOS and iPadOS, navigation uses a three‑column layout—sidebar (tables), list (filtered by vehicle), and details. On iPhone, the same flow is presented as swipeable pages. A vehicle filter at the top of most lists lets you switch context quickly between “All Vehicles” and a specific vehicle.\n\n• Units and formatting: Global Settings define how values are displayed (currency, dates, distance, volume, economy), while each vehicle’s own units drive calculations. This ensures your entries match receipts and odometers while displays remain consistent with your preferences.\n\n• Attachments everywhere: Photos and documents can be attached to vehicles, fuel logs, trips, parts, service items, and service records. Attachments sync via iCloud and can be included in reports or exported with backups.\n\n• Reporting and exports: PDF/CSV reports are available for Trips, Fuel, and Service, scoped to a single vehicle or all vehicles, with grouping by date range, vendor, system, or category. These reports are ideal for reimbursement, audits, tax documentation, and resale records.\n\n• Backup and restore: Data Management → Backup/Restore lets you snapshot your database (and optionally attachments) to Files/iCloud Drive and restore if needed. This complements iCloud sync by providing point‑in‑time archives for safety and portability.\n\n• iCloud sync and multi‑device use: Your database is stored locally and synced via iCloud so your vehicles, logs, service history, parts, systems, vendors, and settings stay aligned across all your devices using the same Apple ID."
		}

		static let header4 = "Quick start and typical workflow"
		static var message4: String {
			"1) Open Settings and choose your preferred units and formatting. These control how values are displayed across the app and in reports.\n\n2) Add vehicles in Garage → Vehicles. Set the odometer and any key specs (fuel type, tank size, economy unit) to enable accurate calculations.\n\n3) Define your controlled vocabularies in Setup → Systems (e.g., Engine, Brakes, Tires) to keep pickers and reports tidy.\n\n4) Build your Parts catalog in Garage → Parts for commonly used items (filters, fluids, pads). Include vendor, cost, and package quantity so costs roll up correctly.\n\n5) Create Service Items (templates) in Vehicle Service → Items for recurring jobs. Link parts, set intervals (miles/months/hours), and choose a default vendor.\n\n6) Log daily usage in Data Tracking → Fuel Log and Travel Log. Attach receipts or notes for context and reimbursements.\n\n7) When work is performed, create a Vehicle Service → Record. Select a Service Item to prefill the entry, add actual parts and labor, attach invoices/photos, and save.\n\n8) Generate reports (PDF/CSV) for a single vehicle or all vehicles. Share or archive them as needed for audits, taxes, or resale.\n\n9) Periodically create a Backup from Data Management → Backup/Restore, especially before big edits or device changes.\n\nFollowing this loop—configure → catalog → plan → log → service → report—keeps your data consistent, searchable, and ready for decision‑making."
		}

	}
	
	enum SettingsIntro {
		static let icon = "gearshape.fill"
		static let title = "Set Up Shared Preferences"
		static let message =
		"Set up your preferences first. Choose the 'units of measure' that will be used throughout the application.\n\nYou can make changes at anytime by selecting 'Settings' on the Setup sidebar.\n\nTo get started, select the 'Open Settings' button below.\n\nAfter saving your settings changes, select the 'Save' button and you will be returned to this screen for the 'Next >' step."
		static let buttonLabel = "Open Settings"
		static let buttonIcon = "slider.horizontal.3"
	}
	
	enum Navigation {
		static let title = "Application Navigation"
		static let systemImage = "inset.filled.leftthird.middlethird.rightthird.rectangle"
		
		static let header1 = "Overview"
		static var message1: String {
			"The \(AppInfo.displayName) application uses a three column split view on MacOS and iPadOS to display information.  iPhoneOS does not support this feature and will present the same information flow as swipeable pages."
		}
		
		static let header2 = "First Column (home screen on iPhone)"
		static let message2 =
		"Contains the sidebar menu items arranged in four groups: 'Garage', 'Data Tracking', 'Vehicle Service' and 'Setup'."
		
		static let header3 = "Second Column"
		static let message3 =
		"Contains the catagories for the selected table (e.g, if Vehicles is selected in the first column, then the second column will display a list of entered vehicles in the 'Vehicles' table).  At the top of second column (unless 'Vehicles' is selected in the first column) is a dropdown that allows you to filter the displayed items by vehicles present in the Vehicles database.  There is also an 'All Vehicles' option to view the records of all vehicles in the database."
		
		static let header4 = "Third Column"
		static let message4 =
		"Used to display the details for the selected item (details of selected vehicle in our example)."
	}
	
	enum GarageVehicles {
		static let title = "Garage Group: Vehicles Table"
		static let systemImage = "truck.pickup.side.front.open"
		
		static let header1 = "Overview"
		static let message1 =
		"The Vehicles table is the foundation of the app’s data model. Each row represents one vehicle you own or track (cars, trucks, motorcycles, etc.) and serves as the primary reference for most other records in the app. By defining your vehicles first, you unlock vehicle-specific filtering, reporting, and relationships across all other tables."
		
		static let header2 = "Best practices"
		static let message2 =
		"• Create vehicles first: Add your vehicles before logging trips, fuel, service items, or parts usage so relationships are established from the start.\n   • Keep odometer current: Update the odometer periodically so service intervals and cost-per-distance metrics remain accurate.  The odometer reading is automatically updated when you log trips or complete fuel refill logs.\n   • Attach documentation: Add photos of receipts, registrations, and key service events directly to the vehicle or related records for a complete history.\n   • Review per-vehicle reports: Use vehicle-specific reports to understand total cost of ownership, fuel economy trends, and maintenance schedules."
		
		static let header3 = "What the Vehicles table stores"
		static let message3 =
		"• Identity and basics: A friendly name, year, make, model, trim, and a unique identifier.\n   • Registration and VIN: VIN, license plate, and other registration details to uniquely identify the vehicle.\n   • Odometer details: Current odometer reading (updated as you log trips and fuel), reading date, and odometer unit (miles or kilometers) used for cost-per-distance and service interval calculations.  There is also a Virtual Odometer feature that estimates the vehicle’s true mileage based on historical trip data.  If the vehicle tracked is a trailor or vehicle towed behind an RV (Toad), this feature will automatically adjust the odometer reading to reflect the true mileage of the towed vehicle.\n   • Fuel/efficiency settings: Fuel type, tank size, and preferred consumption/efficiency unit (MPG, L/100km, etc.).\n   • Tires and fluids (optional): Tire sizes/pressures and fluid specs if you want quick reference for service.\n   • Photos and notes: Attachments and free-form notes for quick context.\n   • Status and organization: Active/inactive flag, ownership status, and optional tags to group or archive."
		
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"• Global filter and context: Most lists in the second column can be filtered by a specific vehicle or “All Vehicles.” Choosing a vehicle limits what you see in Trips, Fuel Logs, Service Items, Service Records, and Parts usage to that vehicle.\n   • Service Records: Each service record links to a vehicle and optionally to Service Items and Parts. Vehicle settings (like odometer units) drive how service intervals and mileage are displayed.\n   • Service Items (maintenance plans): Recurring or scheduled maintenance items can be created per vehicle (or shared patterns applied to multiple vehicles). The vehicle’s odometer and time settings determine when items are due.\n   • Parts: Parts are cataloged once but are referenced by Service Items and Service Records. Vehicle context helps you see which parts were used on which vehicle and the total cost of ownership.\n   • Fuel/Trip Tracking: Fuel logs and trip entries are recorded against a vehicle. The vehicle’s selected units determine how distance, fuel volume, and consumption are calculated and displayed. This powers per-vehicle fuel economy, cost per mile/km, and trip summaries.\n   • Reports and exports: PDF reports (Trips, Fuel, Service) can be generated per vehicle or for all vehicles. The vehicle’s identity and settings are used to format headers, units, and summary metrics.\n   • Vendors/Shops: When you record service for a vehicle, you can associate a vendor or shop. Over time this builds a per-vehicle service history and cost breakdown by vendor.\n   • Systems and setup: System definitions (like categories or custom fields) can apply across vehicles, but the Vehicles table remains the anchor for how those systems are experienced in filters and views.\n   • Attachments and galleries: Photos or documents you add to service work or inspections are linked to the vehicle, creating a consolidated vehicle history.\n   • Defaults and quick entry: You can set a “default” or “most used” vehicle to speed up new entries. The app can pre-fill the vehicle on new fuel logs, trips, or service items based on your last selection.\n   • Lifecycle and archiving: If you sell or retire a vehicle, you can mark it inactive. It won’t appear in quick-pick lists by default, but its historical data (service, fuel, trips) remains intact for reporting.\n   • Validation and unit consistency: The vehicle’s selected units (distance, volume, economy) ensure entries and calculations are consistent across the app, even if your global Settings use different display units.\n   • Sync and portability: Vehicle records live in your local database and sync via iCloud so the same vehicle list and linked data are available across your devices."
	}
	
	enum GarageParts {
		static let title = "Garage: Parts Table"
		static let systemImage = "engine.combustion.badge.exclamationmark"
		static let header1 = "Overview"
		static let message1 =
		"The Parts table is your centralized catalog of components, consumables, and materials used to service or maintain your vehicles. Each part is defined once and then referenced by Service Items (planned maintenance) and Service Records (actual work performed). Centralizing parts enables consistent naming, pricing, inventory awareness, and reporting of total cost of ownership across vehicles."
		static let header2 = "Best practices"
		static let message2 =
		"   • Define common parts once: Create a single entry for frequently used items (oil filter, air filter, brake pads, bulbs, fluids) and reuse them across vehicles.\n  • Use clear, searchable names: Include brand, series, size, and key specs (e.g., “Oil Filter – Toyota 90915‑YZZF2”). Add alternate part numbers in notes for cross-references.\n   • Track unit cost and quantity: Enter the purchase price and package quantity (e.g., 5 qt jug, 1 filter, set of 4 pads) to improve cost calculations and reports.\n   • Capture vendor and SKU: Link a preferred vendor/shop and store their SKU to speed reordering and improve receipts/exports.\n   • Attach documentation: Add photos of labels, spec sheets, or installation guides for quick reference during service.\n   • Tag and categorize: Use categories/tags (e.g., “fluids,” “filters,” “brakes”) to organize your catalog and make filtering easier.\n   • Keep status current: Mark parts active/inactive as they’re superseded or no longer used, without losing history."
		static let header3 = "What the Parts table stores"
		static let message3 =
		"   • Identity: Name, brand/manufacturer, model/series, and optional part numbers/alternate numbers.\n   • Fitment and specs: Descriptions, dimensions, sizes, viscosity/grade, or compatibility notes (vehicle model years, engine types).\n   • Pricing and units: Unit cost, currency, package size/quantity, and an optional default tax rate.\n• Inventory hints (optional): A target/on‑hand quantity field for awareness; actual stock tracking can be done via notes or custom fields if enabled.\n   • Vendor linkage: Preferred vendor/shop reference and vendor SKU to streamline purchasing and reporting.\n   • Media and notes: Photos of packaging or installation, PDFs, and free‑form notes for tips or torque values.\n   • Status and organization: Active/inactive flag, category, and tags to keep the catalog tidy."
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"   • Service Items (maintenance plans): Parts can be associated with a Service Item to define what will be needed when the item is performed (e.g., oil, filter, drain plug washer). This enables consistent parts lists and estimated costs.\n   • Service Records (work performed): When you log a service, you can add the actual parts used, their quantities, unit costs, and vendor. This drives accurate cost-per-service and cost-per-mile/km metrics.\n   • Vehicle context and filtering: While parts are defined globally, they’re shown in context when filtering by a specific vehicle. You can see which parts were used on which vehicle and the total spend per vehicle.\n   • Reports and exports: Parts usage rolls up into service reports and exports (CSV/PDF), including quantities, costs, and vendors. This supports warranty claims, budgeting, and tax/expense tracking.\n   • Vendor integration: Linking parts to vendors streamlines reordering and helps analyze spending by vendor over time.\n   • Consistency across entries: By selecting from the Parts catalog instead of typing free‑form text, you maintain consistent naming and pricing across Service Items and Service Records.\n   • Attachments everywhere: Photos or documents stored on a part can be referenced during service entry, ensuring you have the correct specifications on hand.\n   • Global edits: Updating a part’s name or vendor information improves future entries while preserving historical records and costs already captured."
	}
	
	enum DataTracking_Fuel {
		static let title = "Data Tracking: Fuel Log"
		static let systemImage = "fuelpump.arrowtriangle.left"
		
		static let header1 = "Overview"
		static let message1 =
		"The Fuel Log table records every fill-up for your vehicles. Each entry captures the date/time, location, odometer, fuel volume, price, and optional notes or images. Consistent fuel logging powers accurate fuel economy metrics (MPG, L/100km, km/L), cost-per-distance, and long-term operating cost analysis per vehicle or across your entire fleet.  When a fuel log is created or updated, the odometer and engine hours associated with the vehicle are automatically adjusted to reflect the new fill-up values."
		
		static let header2 = "Best practices"
		static let message2 =
		"   • Log every fill-up: Even partial fills improve trend accuracy over time.\n   • Use the same pump units you purchase in: Enter gallons or liters to match your receipt; the app converts to your preferred display units automatically.\n   • Record the odometer at the pump: Accurate odometer readings produce reliable consumption and cost-per-mile/km metrics and updated the associated odometer automatically.\n• Note conditions: Use notes/tags for highway vs. city, towing, winter fuel, or tire/roof-rack changes that affect economy.\n   • Attach receipts: Photos of receipts help with reimbursement, taxes, and audits.\n   • Keep vehicle settings consistent: Ensure each vehicle’s fuel type and economy units are set correctly so calculations and reports are meaningful."
		
		static let header3 = "What the Fuel Log stores"
		static let message3 =
		"   • Identity and timing: Vehicle reference, log name (optional), date/time of fill-up, and location.\n   • Odometer and distance: Odometer reading at fill-up (miles or kilometers based on the vehicle), with automatic distance calculations between fills for economy metrics.\n   • Fuel details: Volume purchased (gal/L), price per unit, total cost, and optional fuel grade/type.\n   • Vendor and payment (optional): Station/vendor reference and optional payment method in notes for expense tracking.\n   • Media and notes: Receipt photos and free-form notes (e.g., tire pressure change, cargo, weather).\n   • Tags and status: Tags for categorization and an active flag for quick filtering or cleanup."
		
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"   • Vehicle dashboards: Recent fuel economy, average consumption, and cost-per-mile/km are derived from Fuel Log entries per vehicle.\n   • Reports and exports: Generate PDF reports for a single vehicle or all vehicles, including totals, averages, and trends (consumption, spend, and unit price over time).\n   • Trip and service context: Fuel entries appear alongside Trip Logs and Service Records in per-vehicle timelines, giving a complete view of usage vs. maintenance.\n   • Unit consistency: Calculations respect each vehicle’s configured distance and fuel units; display formatting follows your global Settings.\n   • Budgeting and forecasting: Track monthly or annual fuel spend and price-per-unit trends to anticipate costs.\n   • Attachments and audits: Receipt photos and notes support reimbursements, tax reporting, and warranty documentation.\n   • iCloud sync: Fuel logs are stored locally and synced via iCloud so your entries and metrics stay consistent across devices."
	}
	
	enum DataTracking_Travel {
		static let title = "Data Tracking: Travel Log"
		static let systemImage = "map"
		
		static let header1 = "Overview"
		static let message1 =
		"The Travel Log table captures trips taken by your vehicles. Each entry can include start/end date and time, starting/ending odometer (or engine hours if applicable), distance traveled, purpose/category, origin/destination, route notes, and optional attachments. Keeping detailed trip history enables mileage reimbursement, tax reporting, utilization analysis, and a clear picture of how each vehicle is used over time."
		
		static let header2 = "Best practices"
		static let message2 =
		"  • Record trips consistently: Log both business and personal trips; use categories/tags to separate them for reporting.\n  • Capture start and end odometer: Accurate odometer readings ensure reliable mileage totals and cost-per-mile/km analysis.\n  • Add purpose and context: Note client/project, cargo/towing, or special conditions (traffic, weather) that affect timing and fuel usage.\n  • Use templates for recurring trips: Save time by duplicating a prior entry and adjusting dates/notes.\n  • Attach supporting documents: Photos of toll receipts, parking, or gate tickets help with reimbursement and audits.\n• Keep units aligned: Ensure each vehicle’s distance unit matches your preference; the app formats displays per your global Settings."
		
		static let header3 = "What the Travel Log stores"
		static let message3 =
		"  • Identity and timing: Vehicle reference, optional log name, start/end date and time, and trip duration.\n  • Odometer and distance: Starting and ending odometer readings with computed distance (mi/km). Engine hours may be recorded if your workflow uses them.\n  • Locations and route: Origin/destination fields, intermediate stops in notes, and optional location labels for quick filtering.\n  • Purpose and classification: Business vs. personal, client/project, billing code, reimbursable flag, and custom tags/categories.\n  • Costs and incidentals (optional): Tolls, parking, per‑diem or other expenses captured in notes or custom fields.\n  • Media and notes: Photos (receipts, cargo, site conditions) and free‑form notes for context.\n• Status and organization: Active/inactive flag for cleanup without deleting history."
		
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Mileage reporting and reimbursement: Generate per‑vehicle or all‑vehicles reports (PDF/CSV) with totals grouped by category, client/project, or tag.\n  • Tax and compliance: Maintain defensible business mileage logs with timestamps, origins/destinations, and receipts.\n  • Utilization insights: Analyze how much and how far each vehicle travels to plan service intervals and lifecycle decisions.\n  • Correlation with fuel and service: View Travel Logs alongside Fuel Logs and Service Records for a full timeline; distance and utilization trends inform maintenance planning and fuel economy interpretation.\n  • Filtering and dashboards: Filter by vehicle, date range, purpose, tags, or reimbursable status to focus on what matters.\n• Unit consistency and formatting: Distance is calculated using each vehicle’s configured units; display follows global Settings.\n  • Exports and sharing: Produce CSVs for accounting or client billing and PDFs for audits or records.\n  • iCloud sync: Trip entries are stored locally and synced via iCloud, keeping your mileage history consistent across devices."
	}
	
	enum VehicleService_Records {
		static let title = "Vehicle Service: Records"
		static let systemImage = "square.grid.3x1.folder.badge.plus"
		
		static let header1 = "Overview"
		static let message1 =
		"The Service Records table is where you document all maintenance and repair work performed on your vehicles—everything from routine oil changes and inspections to major component replacements. Each record ties together the vehicle, the work performed (optionally referencing a Service Item/maintenance plan), the vendor/shop, the parts and labor used, and the resulting costs. A complete service history supports maintenance scheduling, warranty claims, resale value, and a true total cost of ownership."
		
		static let header2 = "Best practices"
		static let message2 =
		"  • Log work as it happens: Capture date, odometer/engine hours, and a clear description immediately after the job to keep history accurate.\n  • Reference Service Items when applicable: Linking a Service Record to a planned item (e.g., “Engine Oil & Filter”) ensures due‑date tracking and closes out the plan instance.\n  • Itemize parts and labor: Add parts from the catalog and record labor time/cost so reports reflect true maintenance expenses.\n  • Attach documentation: Photos of receipts, invoices, and work areas (before/after) help with warranties and resale.\n  • Track vendor details: Link the vendor/shop to analyze reliability, costs, and warranty coverage over time.\n• Use tags and categories: Group records by system (engine, brakes, tires), season, or project to make filtering and reporting easier.\n• Record next‑due hints: If the service establishes a new interval (time or mileage), note it so future reminders are accurate."
		
		static let header3 = "What the Service Records table stores"
		static let message3 =
		"  • Identity and timing: Vehicle reference, record name/summary, service date, created/updated timestamps.\n  • Usage context: Odometer reading and/or engine hours at time of service (units respect vehicle settings).\n  • Work performed: Detailed description of tasks completed; optional link to a Service Item (maintenance plan) to mark the plan occurrence complete.\n  • Parts and labor: Line items for parts (from the Parts catalog) with quantity and unit cost; labor hours/rate; taxes/fees; and computed totals.\n  • Vendor/shop: Reference to the vendor or shop that performed the work, including contact info or invoice number in notes.\n  • Warranty and return info (optional): Warranty period, claim notes, or return authorizations for defective parts.\n• Media and notes: Photos/PDFs of receipts, diagrams, or the serviced area; free‑form notes for torque values and follow‑ups.\n  • Organization and status: Category/system tags (engine, brakes, tires), active/inactive flag, and optional reminder/next‑due hints."
		
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Maintenance history: Service Records form the definitive history for each vehicle. They appear in per‑vehicle timelines alongside Fuel and Travel logs.\n  • Cost tracking and TCO: Itemized parts and labor roll up to per‑vehicle and all‑vehicles totals, enabling total cost of ownership analysis and budgeting.\n  • Service Items integration: When linked to a Service Item, completing a record can reset due counters (time and/or mileage) and mark the plan instance complete.\n  • Parts usage and inventory: Selecting parts from the catalog standardizes names and costs and shows where each part was used across vehicles.\n  • Vendor analytics: Reports can group by vendor/shop to understand spend, reliability, and warranty claims.\n  • Reports and exports: Generate PDF/CSV service histories with filters by vehicle, date range, system, vendor, or tag for audits and resale documentation.\n  • Reminders and planning: Next‑due hints derived from completed work help you anticipate upcoming maintenance windows.\n  • Unit consistency: Odometer/engine‑hour values respect vehicle settings; display formatting follows global Settings.\n  • iCloud sync: Records are stored locally and synced via iCloud to keep your maintenance history consistent across devices."
	}
	
	enum VehicleService_Items {
		static let title = "Vehicle Service: Items"
		static let systemImage = "folder.badge.gearshape"
		
		static let header1 = "Overview"
		static let message1 =
		"The Service Items table is your library of repeatable maintenance templates. Each entry defines a task (for example, “Engine Oil & Filter” or “Front Brake Pads”) with the default details you typically reuse: a description of the work, an optional preferred vendor/shop, an estimated labor cost, scheduling intervals (miles, months, or engine hours), and the parts commonly needed with their quantities, units, and costs. When you create a new Service Record, selecting a Service Item instantly pre‑fills those fields, speeding up entry and ensuring consistent naming and costing. Service Items can be scoped to a specific vehicle and system so your templates match the equipment they apply to."
		
		static let header2 = "Best practices"
		static let message2 =
		"  • One template per recurring job: Create clear, reusable items for oil service, tire rotation, coolant flush, battery replacement, inspections, etc.\n  • Be specific and searchable: Include the system or variant in the name (e.g., “Oil & Filter – 2.5L” vs. “Oil & Filter – 3.6L”) so pickers are unambiguous.\n• Capture realistic defaults: Set the vendor, labor cost, and typical parts bundle (names, units, quantities, and costs) so new records are nearly one‑tap.\n  • Use intervals as planning hints: Enter miles, months, and/or engine hours to reflect how often the job should occur; these values provide guidance when reviewing service needs.\n  • Link to your parts catalog: Choose parts from the Parts table so names, units, and costs are consistent across items and records.\n  • Iterate over time: As pricing or preferred parts change, update the template—future records will use the latest defaults while past records remain unchanged.\n• Organize by vehicle/system: Assign a vehicle and system so filtering and reporting remain tidy, especially when managing multiple vehicles."
		
		static let header3 = "What the Service Items table stores"
		static let message3 =
		"  • Identity and scope: Vehicle (optional), vehicle system (engine, brakes, tires, etc.), and a unique item name.\n• Description and notes: A concise description of the work plus free‑form notes for instructions or torque values.\n  • Vendor and labor: Default vendor/shop and a labor cost estimate for the job.\n  • Intervals: Suggested schedule fields—intervalMiles, intervalMonths, and intervalHours—to guide when the task should be performed next.\n  • Parts bundle (up to five): For each part—name, optional ID, quantity, unit, and cost per unit. These defaults become line items on new Service Records.\n  • Media: Up to three images with captions for diagrams, checklists, or reference photos.\n  • Timestamps: Created/updated dates for auditing and sorting."
		
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Prefill new Service Records: In a new Service Record, pick a Service Item (via the Items picker). The app copies its defaults—description, vendor, labor, intervals, and parts (names, quantities, units, and costs)—into the record, which you can edit before saving.\n  • Consistent parts and costs: Because items pull parts from the Parts catalog, usage and costs remain consistent across vehicles and reports.\n  • Vendor workflows: Setting a default vendor on an item helps standardize shop selection and enables vendor‑based analysis later.\n  • Vehicle/system filtering: Items can be scoped to a vehicle and system, making it easy to focus on the correct templates while editing or reporting.\n  • Reporting context: The Service Item name appears on Service Records and in PDF reports, making histories easier to scan by task.\n  • Independence of history: Editing a Service Item updates future records; existing Service Records keep the values that were applied at the time.\n  • Backup and sync: Items are stored locally in your database and synced via iCloud so your templates are available on all your devices."
	}

	enum Setup_Systems {
		static let title = "Setup: Systems"
		static let systemImage = "glowplug"
		static let header1 = "Overview"
		static let message1 =
		"The Systems table centralizes the controlled vocabularies that power pickers, filters, and classifications across the app. Use it to define consistent names for vehicle systems (engine, brakes, tires), service categories, parts categories, and other organizational labels the app relies on. Centralizing these definitions prevents typos and duplicates, keeps lists tidy, and ensures reports and exports group your data correctly. Changes you make here immediately improve data entry and filtering everywhere else."
		static let header2 = "Best practices"
		static let message2 =
		"  • Keep names concise and specific: Short, unambiguous names work best in pickers and report groupings (e.g., “Engine,” “Brakes,” “Cooling”).\n  • Prefer editing over deleting: If a term is already used in records, rename it to correct spelling or clarify meaning. Delete only unused terms; otherwise use the Inactive flag.\n  • Use categories consistently: Decide on a small, stable set of systems and categories before heavy data entry to avoid later cleanup.\n• Leverage sort order: Assign an explicit sort index so your most-used systems appear first in pickers.\n  • Scope where appropriate: If your workflow distinguishes by vehicle or subsystem, create separate entries (e.g., “Brakes – Front,” “Brakes – Rear”) rather than overloading a single label.\n  • Document with notes: Add brief descriptions so collaborators (or future you) understand how each term should be used.\n  • Review periodically: As your parts and service libraries grow, prune unused or redundant terms and inactivate those you no longer want offered by default."
		static let header3 = "What the Systems table stores"
		static let message3 =
		"  • Type/domain: The purpose of the entry (e.g., VehicleSystem, ServiceCategory, PartsCategory, TripCategory). This determines where it appears in the UI.\n  • Name: The display name shown in pickers, filters, and reports.\n  • Description/notes: Optional guidance on when to use the term.\n  • Icon and color (optional): Visual hints used in lists and reports to improve scanning.\n  • Sort order: An integer index that controls picker order.\n  • Active flag: Marks whether the term should be offered for new entries. Inactive terms remain available for existing records and reporting.\n  • Scope (optional): A vehicle or group scope when a term is intended for a specific vehicle or context.\n• Metadata: Created/updated timestamps and a unique ID for reliable references."
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Service Items: Choose a Vehicle System for each maintenance template so items are grouped and filtered logically (e.g., Engine, Brakes, Tires). This system label carries through to Service Records created from the item.\n  • Service Records: Tag completed work with a system/category to organize histories and power system-based reporting and filters.\n  • Parts: Assign parts to a category so you can analyze spend by category and quickly find compatible items while building Service Items.\n  • Travel and Fuel filters: If you define trip or purpose categories, they appear in Travel Log pickers and report groupings.\n  • Reporting and dashboards: Systems and categories are used as grouping keys in PDF/CSV exports and summary views (e.g., costs by system, parts spend by category).\n  • Pickers and validation: The Systems table drives the options shown in dropdowns throughout the app, ensuring consistent naming and preventing free‑form duplicates.\n  • Inactivation behavior: Inactivating a term removes it from new-entry pickers while preserving historical records and their reports. Renaming a term updates future pickers and report labels without altering stored historical context.\n  • Sync and backup: System definitions live in your local database and sync via iCloud so the same controlled lists are available across devices and included in backups."
	}

	enum Setup_Vendors {
		static let title = "Setup: Vendors / Shops"
		static let systemImage = "person.2.badge.gearshape"
		static let header1 = "Overview"
		static let message1 =
		"The Vendors/Shops table is your directory of businesses and individuals who sell parts, provide services, or perform repairs on your vehicles. Centralizing vendors enables consistent selection during data entry, accurate spend analysis by vendor, streamlined reordering of parts, and better documentation for warranties and audits. Defining vendors once and referencing them across Parts, Service Items, and Service Records keeps your data clean, searchable, and report‑ready."
		static let header2 = "Best practices"
		static let message2 =
		"  • Capture complete contact info: Include the vendor’s name, phone, website, email, and physical address to simplify scheduling, ordering, and navigation.\n  • Use categories and tags: Distinguish vendors by specialty (e.g., “Tires,” “Brakes,” “Body,” “Dealer,” “Online”) for faster filtering and reporting.\n  • Track account identifiers: Store your customer/account number, preferred salesperson/tech, and tax IDs for invoicing and warranty claims.\n  • Keep pricing context: Note labor rates, typical fees, and preferred payment methods to speed up Service Record entry and cost comparisons.\n  • Attach documents: Save PDFs or photos of quotes, warranties, and past invoices for quick reference.\n  • Prefer inactivation over deletion: Mark vendors inactive if you no longer use them; this preserves historical references in records and reports.\n• Standardize names: Avoid duplicates by using a consistent naming convention (e.g., “ACME Tire & Auto – Downtown”)."
		static let header3 = "What the Vendors/Shops table stores"
		static let message3 =
		"  • Identity: Vendor/shop name, display alias (optional), and unique ID.\n  • Contact details: Phone, email, website, physical address, and hours/notes.\n  • Classification: Category/specialty (tires, brakes, general repair, dealer, online retailer) and tags for custom grouping.\n  • Accounts and terms: Your account number, tax ID, labor rate, typical fees, and payment terms or preferences.\n  • People: Primary contact, technician, or salesperson names with optional notes.\n  • Integrations and identifiers: Vendor SKUs or prefixes used on Parts, and internal reference codes for exports.\n  • Media and documents: Photos or PDFs (warranty cards, quotes, invoices) and free‑form notes.\n  • Status and ordering: Active/inactive flag and sort order to surface preferred vendors first.\n• Metadata: Created/updated timestamps for auditing."
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Parts catalog: Link parts to a preferred vendor and store their SKU. This speeds reordering and lets you analyze spend by vendor and category.\n  • Service Items (templates): Set a default vendor on maintenance templates to standardize where you typically purchase parts or have work performed; this pre‑fills new Service Records.\n  • Service Records (work performed): Select the vendor/shop that completed the job. Vendor information appears on reports/exports and supports warranty and cost analysis.\n  • Reporting and dashboards: Group service and parts spend by vendor to identify top suppliers, compare labor rates, and track warranty claims.\n  • Quick actions: Tap a vendor to call, email, open their website, or view directions using the stored contact details.\n  • Filters and pickers: Vendor lists populate dropdowns across Parts, Service Items, and Service Records, with inactive vendors hidden from new selections by default.\n  • Consistency and cleanup: Centralizing vendors prevents free‑form duplicates and ensures historical records remain linked even if a vendor is renamed or inactivated.\n  • Sync and backup: Vendor records are stored locally and synced via iCloud so your directory and references are available across devices and preserved in backups."
	}
	
	enum Setup_Settings {
		static let title = "Setup: Settings"
		static let systemImage = "gearshape"
		static let header1 = "Overview"
		static let message1 =
		"The Settings table defines global preferences that control how \(AppInfo.displayName) behaves and how information is displayed across your devices. These preferences cover units of measure, formatting and locale, default selections, privacy and data handling, and app‑wide behaviors such as attachments and reporting. Settings are synced via iCloud so you configure them once and enjoy a consistent experience on iOS, iPadOS, and macOS."
		static let header2 = "Best practices"
		static let message2 =
		"  • Set units first: Choose distance, volume, and fuel‑economy display units before entering data. Vehicle‑specific units are always respected for calculations; global Settings control default display formatting.\n  • Align with your locale: Confirm currency, date, and number formatting so reports and exports match your region and accounting needs.\n • Pick a default vehicle: If you primarily work with one vehicle, set it as the default to speed up new entries (you can always change it per entry).\n  • Keep it simple: Start with a minimal set of customizations; add advanced options (attachments quality, export defaults) as your workflow matures.\n  • Review periodically: As your fleet or goals change, revisit Settings to ensure units, defaults, and privacy options still fit your workflow.\n  • Prefer in‑app conversions: Enter data in real‑world units from receipts or odometers; let the app convert for display based on Settings.\n  • Sync awareness: If multiple devices are used, give iCloud time to sync Settings after changes before heavy data entry."
		static let header3 = "What the Settings table stores"
		static let message3 =
		"  • Units of measure: Display units for distance (mi/km), volume (gal/L), fuel economy (MPG, L/100km, km/L), and engine hours (h). Vehicles may specify their own units for calculations.\n• Formatting and locale: Currency symbol/code, thousands/decimal separators, date format (short/long), time format (12/24‑hour), and first day of week.\n  • Defaults and behaviors: Default vehicle, default vendor for new records (optional), default report date range, and whether to prefill last‑used values in editors.\n• Attachments and media: Preferred image size/quality for photos, whether to include images in PDF exports by default, and cellular‑data usage preferences for uploads.\n  • Privacy and security: Redaction options for exports (hide addresses/VINs), whether to include personal notes in reports, and confirmation prompts for destructive actions.\n  • Sync and backup options: iCloud sync toggle, conflict resolution preference (prefer newest vs. manual review, if supported), and backup/export destinations defaults.\n  • Advanced calculations: Rounding modes for currency and consumption, treatment of partial fuel fills in economy calculations, and thresholds for service reminders.\n  • Metadata: Created/updated timestamps and a unique ID to sync Settings reliably across devices."
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Editors and pickers: New entries in Fuel, Travel, Parts, and Service screens respect your default units and prefill choices (default vehicle/vendor, last‑used values) to speed data entry.\n  • Calculations and display: Vehicle‑specific units drive calculations; global Settings determine how values are formatted for display and in reports (currency, dates, number precision).\n  • Reports and exports: PDF/CSV generation uses Settings for date ranges, unit formatting, currency, redaction, and whether to embed images by default.\n  • Attachments: Image capture/import respects media quality and cellular‑data preferences; exports include or exclude attachments based on Settings.\n  • Service reminders and intervals: Rounding and threshold preferences influence how due‑soon indicators are presented across Service Items and Records.\n  • Multi‑device consistency: Settings sync via iCloud so your preferences apply on iOS, iPadOS, and macOS without reconfiguration.\n  • Safety and privacy: Destructive actions, sensitive fields, and personally identifiable information in exports obey your confirmation and redaction preferences.\n  • Import/backup flows: Defaults guide where backups are saved, how imports are interpreted (units/locale), and how conflicts are resolved to keep your data consistent."
	}
	
	enum DataManagement_BackupRestore {
		static let title = "Data Management: Backup / Restore"
		static let systemImage = "square.and.arrow.up"
		static let header1 = "Overview"
		static let message1 =
		"The Backup & Restore tools protect your data and make it portable across devices. A backup captures your local database (and, optionally, attachments) into a single archive you can store in Files, iCloud Drive, or share externally. Restore safely replaces your current database with a selected backup, allowing you to recover from mistakes, device loss, or try new workflows without risking your history. Because \(AppInfo.displayName) syncs via iCloud, backups are most effective when used as point‑in‑time snapshots and when restores are performed thoughtfully to avoid sync conflicts."
		static let header2 = "Best practices"
		static let message2 =
		"  • Back up before major changes: Create a backup before bulk edits, imports, or app updates so you can roll back if needed.\n  • Name and organize backups: Use descriptive names (date, device, purpose) and keep a small set of known‑good snapshots rather than many random files.\n  • Let sync settle: Before backing up or restoring, give iCloud time to finish syncing across devices to ensure a complete snapshot and a clean restore.\n  • Keep off‑device copies: Store at least one backup outside the device (iCloud Drive or external storage) to protect against device loss.\n  • Avoid concurrent edits during restore: Close the app on other devices and pause editing until the restore completes and sync stabilizes.\n • Test occasionally: Restore a non‑critical backup to verify your process and confidence—especially before trips or projects.\n  • Prefer export for sharing: Use CSV/PDF exports to share reports; use backups only when you intend to fully replace an app database."
		static let header3 = "What the Backup/Restore stores and expects"
		static let message3 =
		"  • Backup contents: A snapshot of your local SQLite database; optionally includes attachments (images/documents) referenced by records.\n  • File format: An app‑specific archive with metadata (creation date, app/database version, device info) to help validate compatibility at restore time.\n  • Integrity checks: Basic validation to ensure the archive isn’t corrupted and the database schema can be read.\n  • Version awareness: Backups record schema/app versions so the app can migrate forward when restoring from older versions (downgrades may be blocked).\n  • Safety snapshots: During restore, the current database can be snapshotted temporarily so you can revert if you cancel or something fails.\n  • Permissions and storage: Restores require sufficient free space for the archive and temporary files; large attachment sets may need extra room."
		static let header4 = "How it’s used throughout the application"
		static let message4 =
		"  • Creating a backup: From Data Management, choose Backup. Pick whether to include attachments, then save the archive to Files/iCloud Drive or share it using the system share sheet.\n  • Restoring a backup: Choose Restore, select an archive from Files/iCloud Drive, review the summary (date, version, size), and confirm. The app replaces the current database with the archive and reloads your data.\n  • Sync coordination: After restore, iCloud sync resumes and reconciles changes across devices. For best results, open the restored device first, allow it to fully sync, then open other devices.\n  • Cross‑device portability: A backup created on iOS, iPadOS, or macOS can be restored on another device using the same Apple ID, keeping your history portable.\n  • Attachments handling: If you include attachments in the backup, they are restored alongside the database so records, photos, and PDFs relink correctly.\n  • Reporting continuity: After a restore, reports, filters, and pickers immediately reflect the restored state—vehicles, trips, fuel logs, service items/records, parts, systems, vendors, and settings.\n  • Safety prompts: Restores require explicit confirmation and may offer to create a pre‑restore snapshot for quick rollback.\n  • Maintenance and cleanup: Use old backups to archive milestones (e.g., before selling a vehicle). Periodically delete outdated archives to reclaim storage."
	}
}
