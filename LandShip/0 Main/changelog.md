VEHICLETRAX CHANGE LOG

Send suggestions for features & improvements to: [info@aeronauticaltrax.com](mailto:info@aeronauticaltrax.com)

----------------------------------
Version: 2026.09.01 Build: 86
NOTES
- This is a major revision with many new options added.  Updates were delayed due to mistaken update of xCode to beta version which App Connect would not accept.

ADDED

## Dashboard
- New customization sheet (slider icon in the toolbar) lets you choose which cards are shown and drag to reorder them. The scheme is saved to your account and applies on every device.
- New vehicle checklist in the customization sheet lets you exclude specific vehicles from "All Vehicles" totals across every card.

## Vehicles
- Added Wheel Stud Size, Wheel Nut Socket, and Wheel Nut Torque text fields to the Tire Information section.
- Added weight scale reading fields to the Weight Data section (all axles except trailer) and Total Rolling Weight (all axles combined) are computed and displayed automatically.
- Added CAT Scale Tickets sub-form. Each vehicle can store unlimited weigh station tickets.
- Added ability to link vehicle records together to track different aspects of the same physical vehicle (e.g. Chassis, Engine, Body/House).
- List: Rows now show "Linked to: [vehicle]" if the vehicle links to a master, and "Linked vehicles: [names]" if the vehicle is itself a master.

## Fuel Log
- Field to track DEF price per gallon & DEF remaining in 1/8 increments
- Exit Time field added below Date/Time, so a fuel log records both arrival and departure the same way a travel log's enroute stop does. When a stop and a fuel log are linked the two exit times stay matched — saving the trip writes the stop's exit time to the log, and opening a stop picks up the exit time held on its linked log. The fuel log detail view shows Exit Time once one later than the entry time has been recorded.
- The edit form is reordered to match a travel log's enroute fuel stop — Fuel Level Start, then Fuel Added, Price and Cost, then Fuel Level End, followed by a "Fluids Added" group holding Oil Added and the DEF fields. Fuel Level End also auto-calculates from Fuel Added here now, which it previously did not.
- The Fuel Level Start and Fuel Level End quantities are now editable too, matching the travel log.
- The detail view now shows DEF Cost (DEF added times its price) below DEF Price, the same way fuel shows Cost below Price.
- The Fluid Checks button now matches a travel log's enroute stop — a plain bordered button in the Fluids Added group rather than its own card with a "FLUID CHECKS" heading, and its title shows the count: "Fluid Checks (4 completed)".
- List: The Fuel line on each row now also shows price per unit (e.g. "$3.89/gal"), and a DEF line (quantity and price per unit) is shown below it when DEF was added.
- List: The section header now shows Total Fuel, Total Cost, and Average Cost/Unit for the currently listed records, plus a second line with Distance and Average Fuel Economy when a single vehicle is selected.

## Trip Log
- Date/time field for each enroute fuel stop.
- Option to attach up to 3 photos to each enroute fuel stop.
- Exit time field for each enroute fuel stop. Trip detail view shows "Departed" time per stop, plus computed "Stop Time" and "Time Moving" totals based on stop durations.
- "Other" stop reason opens a text field to enter a custom description.
- Comments field added to each enroute stop for free-form notes.
- Trip Group field added to each travel log record. Groups allow related trip legs to be associated under a named group.
- Stop Location field no longer auto-fills with current location. The arrow button must be pressed to fill in location.
- Enroute stop fields stay hidden on a new stop until a Stop Reason is chosen.
- List: Each trip row now shows both "Total Enroute" (start to end) and "Underway" (total enroute minus time spent at enroute stops) time.
- The Quantity field on an enroute stop is hidden unless Stop Reason is set to "Fuel".
- List: Each trip row now shows Group (if assigned), Total Miles, and Total Fuel used, together on one line (e.g. "Group: Trip A   142mi   15.2gal").
- List: The "Total Enroute" time line on each trip row is replaced with "Fuel Burn" for that individual leg
- List: The section header now shows Total Miles, Total Fuel, and Average Economy on one line, plus Time Underway and Average Speed on a second line, for the currently listed trips.
- Each enroute fuel stop now records Fuel Type, Fuel Level Start, Fuel Level End and DEF Level. The fields appear once "Create Fuel Log" is on, and are saved to (and read back from) that stop's linked fuel log record — so the fuel log created from a stop now carries the actual levels entered instead of assumed ones. Fuel Type starts out matching the vehicle's fuel type. The trip detail view shows Fuel Type, Fuel Level and DEF Level under each stop that has a linked fuel log.
- An enroute stop's entry and exit times are now stored as "not recorded" until they are actually set, rather than defaulting to whenever the record happened to be created. A new stop opens with both times set to the current date/time; an older stop that has an entry time but no exit time opens with its exit time matching its entry time, so it no longer reports a departure nobody entered. Stop durations, "Time Moving" and "Time Underway" only count stops where a real departure was recorded.
- Each enroute fuel stop can now be linked to a fuel log that already exists. With "Create Fuel Log" on, a "Fuel Log" dropdown lists that vehicle's existing fuel logs (date, quantity and location, newest first); choosing one fills the stop in from that record and keeps the two in sync on save. Logs already attached to another stop on the same trip are left out of the list, and choosing "New Log" unlinks the stop so a fresh record is created instead.
- The "Create Fuel Log" toggle on an enroute stop only appears once Stop Reason is set to "Fuel". Changing the reason away from Fuel now also switches the fuel log off, so its fields don't stay on screen without a control to dismiss them.
- On an enroute stop, "Date/Time" and "Exit Time" are renamed "Start Stop" and "End Stop".
- Each enroute stop's "STOP 1"…"STOP 6" heading now sits on a filled banner rather than being a thin centred label, so it's obvious where one stop's fields end and the next begins.
- An enroute fuel stop's Odometer and Engine Hours now sit directly below Location, with Fuel Type under them, ahead of the tank readings and the amount added.
- An enroute fuel stop's fields are reordered to follow the order things happen — Fuel Level Start now sits between Location and Quantity, and Fuel Level End directly below Quantity. Entering a quantity (or changing the start level) now fills the end fuel quantity in automatically as start plus amount added, capped at the tank's capacity, so a stop only needs the level before fuelling and the amount put in. The end level can still be overridden by hand.
- Each enroute fuel stop can now have its Fuel Level Start, Fuel Level End and DEF Level quantities typed in directly, the same as Travel Start and Travel End. The figures are saved on that stop's linked fuel log, so a stop and its fuel log always agree, and the dropdowns are snapped to match the quantities on save.
- The fuel quantity beside the Fuel Level dropdown on Travel Start and Travel End is now editable, for vehicles with a digital fuel readout where an exact figure beats an eighths estimate. Choosing a fraction from the dropdown still fills the quantity in as before; typing over it keeps the exact amount. On save the dropdown and its fraction label are set from whatever the quantity ended up as, so the record reopens consistent, and trip statistics use the exact figures.
- An enroute fuel stop now records DEF price per unit alongside DEF Added, saved to the stop's linked fuel log. The trip detail view shows DEF Price and the computed DEF Cost under each stop that has one.
- Oil Added is now on its own row at the top of the Fluids Added group instead of sharing a row with DEF Added, so the DEF entries read as one block: DEF Level Start, DEF Added, DEF Price, DEF Level End — the same order as the fuel log.
- The "Fluid Checks" button on Travel Start, Travel End and each enroute stop now shows how many were done — "Fluid Checks (4 completed)" — so the count is visible without opening the sheet. The count updates as soon as the sheet is dismissed.
- A "Fluid Checks" button has been added to the Travel Start and Travel End sections, opening the same popup sheet used for fuel stops. Fluids checked at departure and arrival are tracked separately, and the trip detail view lists them on a "Fluids Checked" line in each section.

## Trip Log & Fuel Log
- A "Fluid Checks" button that opens a popup sheet.
- A stop's Exit Time can no longer be set earlier than its entry Date/Time. The date picker won't go below the entry time, the "Now" button respects it, and moving the entry time later pushes the exit time along with it.
- DEF Level End now fills in automatically as DEF Level Start plus DEF Added, capped at the tank's capacity, the same way Fuel Level End derives from the amount of fuel added. It can still be overridden by hand.
- DEF fields (DEF Level Start, DEF Added, DEF Price, DEF Level End) only appear when Fuel Type is set to "Diesel", on an enroute fuel stop as well as the fuel log.
- New "DEF Level Start" field records the DEF level before adding any, sitting directly above DEF Added on both an enroute fuel stop and the fuel log. The existing DEF level is relabelled "DEF Level End" to match, and both detail views list the two separately. It behaves like every other tank reading — pick an eighth or type the exact amount.
- Tank readings in the detail views now show the actual quantity next to its fraction — "1/4 Tank (25.0gal) to Full Tank (100.0gal)" under each enroute stop, and the stored figure rather than a recomputed one on the fuel log's Fuel Level Start, Fuel Level End and DEF Level lines. A typed exact amount is no longer displayed as the eighth it snapped to.
- DEF now tracks an actual quantity, not just an eighths estimate. The figure beside every DEF Level dropdown — Travel Start, Travel End and the fuel log — is editable on the same terms as fuel: pick a fraction to fill it in, or type the exact amount from a digital readout. On save the dropdown and fraction label are set from whatever the quantity ended up as. Records saved before the field existed derive their DEF quantity from the stored fraction the first time they're opened, so nothing reads as empty.

## Trip Statistics
- Three computed time fields — Total Elapsed, Time Underway and Engine Time.
- Vehicle Totals: the same three time fields accumulated across all trips — Total Elapsed, Underway Hours, and Engine Time.

## Service Records & MX Items
- "Transfer to Additions" — a new LINK TO ADDITIONS card in the service record edit form allows each part and labor line item to be individually transferred into the Additions tracker.
- Added a custom tracking field to each service record — user defines a field name, unit of measure, and numeric value to track anything beyond Miles/Engine Hours (e.g. Water Gallons).

## Project List
- "Transfer to Additions" — same link-to-Additions capability added to the project item edit form.

## Settings
- New "Fuel Log — Fluid Checks" section in Settings.

## Help & Feedback
- New "Send Feedback" form — under Resources on iPhone/iPad, and in the Support section of Help on Mac. Choose Suggestion, Improvement, Issue or Question, fill in a subject and the details, and the form opens your mail app with the message addressed and ready; nothing is sent until you press Send there. Your name and a reply address are optional. App version, platform and device model are attached by default — they're shown in the form and can be switched off, and no vehicle records are ever included. A "Copy Message" button covers devices with no mail account set up.
- What's New now groups each version's entries under the area they affect, each on a faint tinted heading, rather than running them together as one long list.

## Backup & Restore
- Settings: New "Automatic Backups" section lets you choose how often & how many recent backups to keep. When due, a backup is created quietly the next time you open the app — no file picker needed.
- Sidebar: The backup date under the Backup button is now two separate, independently tracked lines — "Last Manual Backup" and "Last Auto Backup" (only updated by the automatic schedule).
- Restore: When restoring while iCloud sync is active, you can now choose "Resync from iCloud" (re-downloads vehicle/service data fresh from iCloud) or "Restore Exact Snapshot" (forces the backup's database back in exactly as saved).

FIXED

## Vehicles
- Vehicle name not persisting after edit (EditVehicle.swift): updateItem() was writing to dataSet.name but not dataSet.displayName.
- Editing a vehicle's Name now warns that other records reference the vehicle by name and might lose their link if the name changes. On Save, the user can choose to automatically update all of those records to the new name, or save without updating them.
- A newly created vehicle's Name field now starts blank with a "(New Vehicle)" placeholder instead of showing its internal placeholder ID.

## Fuel Log
- The edit form now re-reads the record when opened, so values written by a travel log's enroute stop (DEF price, quantities, levels) appear instead of whatever was loaded the first time the form was shown.
- Saving no longer discards the value in whichever field you were still typing in. The Save button now ends editing before reading the form, so a figure entered in DEF Price (or Price, Cost, or any other numeric field) is committed instead of reverting to its previous value. Previously the form was torn down before the field had written its value back.

## Trip Log & Fuel Log
- Exact typed fuel and DEF quantities are no longer replaced by their eighths equivalents every time the record is opened. Seeding the Vehicle picker on open was firing the "vehicle changed" handler, which rescales both tanks from the fraction dropdowns — so a typed 47.3 gal became 50.0 on the next open, and saving made it permanent. The tanks are now only rescaled when the vehicle is actually changed to a different one.

## Service Records
- Miles and Engine Hours are no longer shown in the records list when their value is 0.

## Backup & Restore
- Backup: The post-backup summary dialog is now scrollable.
- Backup: Creating a backup no longer freezes the app while it scans your data.
- Backup: Backups now include hidden support files that were previously skipped.
- Restore: Selecting a folder that isn't actually a valid backup now shows an error instead of silently reporting "Restore complete" with nothing restored.
- Restore: If a restore is interrupted partway through (e.g. low disk space), your existing data is now safely rolled back instead of being left partially overwritten.
- Restore: After a successful restore, the app now requires a full restart to finish loading the restored data safely.
- Restore: When iCloud sync is active, restoring no longer automatically overwrites your local database with the backup snapshot (which could push old or deleted records back out to your other synced devices). Instead, restoring now offers a choice: "Resync from iCloud" (recommended) restores Documents from the backup and lets vehicle/service data re-download fresh from iCloud, or "Restore Exact Snapshot" forces the backup's database back in exactly as saved — useful when restoring onto a different iCloud account, or when iCloud's own data didn't come back correctly. The confirmation prompt explains both options before you restore. A full raw restore still happens automatically (no choice needed) when iCloud sync isn't active.

----------------------------------
Version: 2026-05-21
ADDED
- Added 'Settings' item to set the screen presented each time the application is opened. 
- Checklists: Added option to change header background and text colors on individual checklist.
- Added: Fields in 'Vehicles' database table to track warrenty data.  Displayed and edited in Garage > Vehicles section.  unlimited warrenties can be tracked for different components (engine, chassis, tranmission...).
- Added: Sort descending and accending to all views and persist all choices to be restored on next view.
- Added: Last backup date below left 'Backup' menu item.
- Added: Fields to Vehicle table to track component serial numbers.
 
FIXED
- MacOS version only. Within 'Vehicle Financials - Improvements': if an entry did not have both a category and sub-category entry in the database, a crash of the application would result.  Corrected code to account for the above in MacOS code.
- 'Vehicle Financials - Improvements': when a different vehicle is selected from the dropdown, the '+' add new record button in the menu does not respond until a current record is selected.  Corrected code.
- 'Vehicle Financials - Improvements': when the + add new record is selected the new record should be pre-populated with the selected vehicle (if one is selected, if not leave blank). Corrected code.
- 'Vehicle Financials - Improvements': when add record is selected, a new record is being created and added to the list, but the editadditions.swift form doea not always open with the new record. Corrected code.
- All PDF report generations on MacOS would not print and raised a 'not available' dialog. Corrected code.
- Several forms had top menu items duplicated. Corrected code.
- Corrected size of upper menu item 'report' on all forms to make room for text.
- Improved dashboard page cards telemetry data displays.
- For service items, the name of the item will be locked after initial creation.  Since the name of the item is used to generate telemetry data, changing the name would corrupt the telemetry calculations.


CHANGED
- Removed build number from version header on forms. 
- Removed presented graphic from several sections due to display performance.
NOTES
- 

----------------------------------
Version: 2026-03-22
ADDED
- Added Additions module with full CRUD operations including DisplayAdditions, EditAdditions, and PDF report generation. This module allows users to track vehicle additions and modifications with comprehensive reporting capabilities.

- Added Subscriptions module with complete functionality including DisplaySubscriptions, EditSubscriptions, and PDF report generation. Users can now manage recurring vehicle-related subscriptions and expenses with detailed tracking and reporting.

- Added Projects module with DisplayProjectList, EditProjectList, and dual PDF reporting (ProjectList and PunchList reports). The LivePunchListView provides real-time project tracking, enabling users to manage vehicle-related projects and punch lists efficiently.

- Added CheckLists module with DisplayCheckList, LiveCheckListView, and PDF report generation for checklist items. This feature enables users to create, track, and complete vehicle maintenance and inspection checklists with live updates and comprehensive reporting.

- **NEW: Sub-Items Feature for CheckLists** - Major enhancement to the CheckLists module with hierarchical task management:
  - Create unlimited sub-items within any checklist item for detailed task breakdown
  - Collapsible/expandable sub-items sections with automatic expansion on load
  - Visual completion indicators showing completed (green checkmark) and in-progress (orange dotted circle) sub-item counts at a glance
  - Full editing capabilities for sub-items including name, description, notes, and completion dates
  - Customizable section names - rename "Sub-Items" to "Steps", "Tasks", or any custom label per parent item
  - Smart completion logic: checking a parent automatically completes all sub-items, and completing all sub-items automatically marks the parent as complete
  - Context menu support for quick actions: add sub-items, edit names, expand/collapse editors
  - Inline editing with double-tap on section names and item names
  - Cascading deletion: removing a parent item automatically removes all its sub-items
  - Compact, space-efficient design with expandable editors for detailed sub-item information

	- Enhanced dashboard with new AdditionsCost tracking component (DashboardView+AdditionsCost.swift), providing users with visual insights into vehicle addition expenses and cost tracking across the fleet.

FIXED
- Added close button to MacOS changelog display.
- Fixed SwiftData compatibility issue with PersistentIdentifier storage by implementing UUID-based parent-child relationships for sub-items

CHANGED
- Updated CheckListItem model to support hierarchical relationships using itemID and parentItemUUID properties
- Enhanced LiveCheckListView with sub-items display and management capabilities
NOTES
- Sub-items feature uses UUID-based relationships for SwiftData compatibility and CloudKit sync support 

----------------------------------
Version: 2025-12-22
ADDED
- Added dialogs to Fuel Log, Trip Log, Service Records and Service Items that displays if 'All Vehicles' is selected and a new record is created.
- Added this change log to be displayed once with each new version.

FIXED
- 
CHANGED
- 
NOTES
- 

----------------------------------
Version: 2025-12-22
ADDED
- Initial release of VehicleTrax.
- SwiftData model container with CloudKit sync and local fallback.
- macOS Help window and custom Help menu command.
- Settings presented as a sheet from the main UI.
FIXED
- 
CHANGED
- 
NOTES
- 
