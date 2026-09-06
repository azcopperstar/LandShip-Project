VEHICLETRAX CHANGE LOG

Send suggestions for features & improvements to: [info@aeronauticaltrax.com](mailto:info@aeronauticaltrax.com)

----------------------------------
Version: 2026.09.02 Build: 96
NOTES
- This is a major revision with many fixes and new features.  
- Email us (using the above link or the link on the Resouces tab) with suggestions for improvements, application features or issues with the application.

ADDED

## Dashboard
- New customization sheet: (slider icon in the toolbar) lets you choose which cards are shown and drag to reorder them. The scheme is saved to your account and applies on every device.
- New vehicle checklist: in the customization sheet lets you exclude specific vehicles from "All Vehicles" totals across every card.
- New "Inventory Status" card: lists inventory-tracked parts that are low or out of stock, with a detail view grouping parts into Out of Stock, Low Stock, and Well Stocked.

## Vehicles
- Added Wheel Stud Size, Wheel Nut Socket, and Wheel Nut Torque: text fields to the Tire Information section.
- Weight scale reading fields to the Weight Data: section (all axles except trailer) and Total Rolling Weight (all axles combined) are computed and displayed automatically.
- CAT Scale Tickets sub-form: Each vehicle can store unlimited weigh station tickets.
- Ability to link vehicle records together: to track different aspects of the same physical vehicle (e.g. Chassis, Engine, Body/House).
- Linked to [vehicle]: if the vehicle links to a master, and "Linked vehicles: [names]" if the vehicle is itself a master.

## Parts
- Inventory Tracking card: on each part — a "Track Inventory for this Part" checkbox reveals Quantity On Hand, Reorder Point, and Reorder Quantity fields.
- Consuming an inventory-tracked part on a service record: automatically subtracts the quantity used from that part's inventory, and restores it if the service record is later deleted or the part/quantity is changed.
- Remaining inventory is now shown next to the part: on the Parts list, on Service Items, and on the service record that consumed it, with a low-stock warning once quantity on hand falls to or below the reorder point.

## Fuel Log
- Field to track DEF price per gallon: DEF remaining in 1/8 increments
- Exit Time field added below Date/Time: so a fuel log records both arrival and departure the same way a travel log's enroute stop does.
- Edit form is reordered to match a travel log's enroute fuel stop:
- Fuel Level Start and Fuel Level End quantities: are now editable too, matching the travel log.
- DEF Cost (DEF added times its price) below DEF Price: the same way fuel shows Cost below Price.
- Fluid Checks button now matches a travel log's enroute stop:
- Fuel line on each row now also shows price per unit:
- The section header now shows Total Fuel, Total Cost, and Average Cost/Unit:

## Trip Log
- Date/time field for each enroute fuel stop:
- Option to attach up to 3 photos to each enroute fuel stop:
- Exit time field for each enroute fuel stop:
- "Other" stop reason: opens a text field to enter a custom description.
- Comments field added to each enroute stop for free-form notes:
- Trip Group field added to each travel log record: Groups allow related trip legs to be associated under a named group.
- Stop Location field no longer auto-fills with current location:
- Enroute stop fields stay hidden: on a new stop until a Stop Reason is chosen.
- Each trip row now shows both "Total Enroute" (start to end) and "Underway": (total enroute minus time spent at enroute stops) time.
- The Quantity field on an enroute stop is hidden unless Stop Reason is set to "Fuel":
- Each trip row now shows Group (if assigned): Total Miles, and Total Fuel used, together on one line (e.g. "Group: Trip A   142mi   15.2gal").
- "Total Enroute" time line: on each trip row is replaced with "Fuel Burn" for that individual leg
- The section header now shows Total Miles: Total Fuel, and Average Economy on one line, plus Time Underway and Average Speed on a second line, for the currently listed trips.
- Each enroute fuel stop now records: Fuel Type, Fuel Level Start, Fuel Level End and DEF Level. 
- An enroute stop's entry and exit times are now stored: as "not recorded" until they are actually set, rather than defaulting to whenever the record happened to be created.
- Each enroute fuel stop can now be linked to a fuel log that already exists:
- "Create Fuel Log" toggle: on an enroute stop only appears once Stop Reason is set to "Fuel". 
- Each enroute stop's "STOP 1"…"STOP 6" heading: now sits on a filled banner rather than being a thin centred label, so it's obvious where one stop's fields end and the next begins.
- An enroute fuel stop's Odometer and Engine Hours: now sit directly below Location, with Fuel Type under them, ahead of the tank readings and the amount added.
- An enroute fuel stop's fields are reordered to follow the order things happen:  Fuel Level Start now sits between Location and Quantity, and Fuel Level End directly below Quantity.
- Each enroute fuel stop can now have its Fuel Level Start, Fuel Level End and DEF Level: quantities typed in directly, the same as Travel Start and Travel End.
- The fuel quantity beside the Fuel Level dropdown on Travel Start and Travel End is now editable: for vehicles with a digital fuel readout where an exact figure beats an eighths estimate. 
- An enroute fuel stop now records DEF: price per unit alongside DEF Added, saved to the stop's linked fuel log.
- Oil Added is now on its own row: at the top of the Fluids Added group instead of sharing a row with DEF Added.
- The "Fluid Checks" button on Travel Start, Travel End: and each enroute stop now shows how many were done.
- A "Fluid Checks" button has been added: to the Travel Start and Travel End sections.

## Trip Log & Fuel Log
- A "Fluid Checks" button that opens a popup sheet:
- A stop's Exit Time can no longer be set earlier than its entry Date/Time:
- DEF Level End now fills in automatically: as DEF Level Start plus DEF Added, capped at the tank's capacity, the same way Fuel Level End derives from the amount of fuel added. It can still be overridden by hand.
- DEF fields: (DEF Level Start, DEF Added, DEF Price, DEF Level End) only appear when Fuel Type is set to "Diesel", on an enroute fuel stop as well as the fuel log.
- New "DEF Level Start" field: records the DEF level before adding any, sitting directly above DEF Added on both an enroute fuel stop and the fuel log.
- Tank readings in the detail views: now show the actual quantity next to its fraction.
- DEF now tracks an actual quantity: not just an eighths estimate.

## Trip Statistics
- Three computed time fields:  Total Elapsed, Time Underway and Engine Time.
- Vehicle Totals: the same three time fields accumulated across all trips — Total Elapsed, Underway Hours, and Engine Time.

## Service Records & MX Items
- "Transfer to Additions":  a new LINK TO ADDITIONS card in the service record edit form allows each part and labor line item to be individually transferred into the Additions tracker.
- Added a custom tracking field to each service record:  user defines a field name, unit of measure, and numeric value to track anything beyond Miles/Engine Hours (e.g. Water Gallons).
- Service Items now show remaining inventory: next to any inventory-tracked part picked for that item.
- Up to 5 embedded sub service items per record: a new SUB SERVICE ITEMS card lets one service record cover several service items from the same visit — an oil change, a filter swap, and a tire rotation, say, all in the same shop stop — instead of splitting them across separate records. Each of the 5 slots can be picked from your Service Items list or typed manually, with its own Description and Labor Cost field. Item 2 only appears once Item 1 has a name, Item 3 once Item 2 does, and so on through Item 5, the same progressive reveal Trip Log already uses for its 6 enroute stops. Picking a Database Item copies its description and labor cost into the record as a one-time snapshot: it stays exactly as copied even if that Service Item's own cost is edited afterward, so a saved record always reflects what the visit actually cost at the time. Sub-item labor rolls into the record's Grand Total, its cost-per-mile and cost-per-engine-hour figures, the read-only SUB SERVICE ITEMS summary, the PDF report's Costs column and summary block, and the Dashboard's Cost Snapshot (month-to-date, last-90-days, year-to-date, and the top-spend chart). Re-picking a different Database Item on the record replaces every previously-copied sub-item, the same way it already replaces the description, vendor, and parts.
- Service Items can now be marked "All Vehicles": the Vehicle field on a Service Item template can be set to a new "All Vehicles" choice instead of one specific vehicle, for a generic task like "Check Oil Level" or "Inspect Fire Extinguisher" that applies fleet-wide rather than to one vehicle's particular maintenance schedule. An "All Vehicles" item shows up alongside a vehicle's own items in the Database Item picker and in all 5 Sub Item pickers on a service record, and in the Service Items list itself even while that list is scoped to one specific vehicle. Note that Dashboard's Next Service Due and Maintenance Status cards still compute a due date against one vehicle's odometer/hours, so a generic "All Vehicles" item won't produce a due-date on those cards — the same limitation parts already have, since parts never tracked service intervals either.
- Service Items can bundle up to 5 sub-items of their own: a Service Item template now has the exact same SUB SERVICE ITEMS card as a service record, letting a "master" item (e.g. "50-Hour Service") list up to 5 other Service Items it's meant to cover. Picking that master item on a service record's Database Item picker now imports its whole bundle in one step — all 5 of the master's sub-items are copied straight into the record's own SUB SERVICE ITEMS slots, on top of the record's usual description/vendor/parts copy — instead of picking each one by hand. The import is a one-time snapshot of the master's own sub-items only (one level deep — a sub-item's own bundle, if it has one, isn't expanded further), and re-picking the master item later re-imports and replaces whatever sub-items were there before, the same overwrite-on-repick behavior as every other field that copies from a Service Item template.
- Each of a service record's 5 sub-items now has its own multi-line Comments field: sitting below that sub-item's Labor Cost, for notes specific to that one piece of work — what was actually found or done, a part substitution, anything worth remembering next time. Picking a Database Item for that slot seeds Comments from that Service Item's own Item Notes field, the same one-time-snapshot copy already used for Description and Labor Cost, so re-picking a different item replaces it too; from there it's freely editable and independent of the source item. It only shows in the read-only summary when something's actually been typed, same as the record's other optional fields. On the read-only Service Record details screen, each sub-item now renders as its own card (SUB SERVICE ITEM 1 through 5) instead of one shared card divided by lines, matching the separation the PART 1...PART 5 cards already use.
- A Service Item's own bundled sub-items now get the same Comments field: each of the 5 slots on a Service Item template (e.g. "50-Hour Service") has a Comments field just like a service record's does, seeded the same way from the picked sub-item's Item Notes. When that master item is later picked on a service record, the record's SUB SERVICE ITEMS import now carries each sub-item's Comments along too, instead of leaving that slot's Comments blank.
- New "Mark as Sub-Item" field on Service Items: a checkbox in SERVICE ITEM DETAILS flags an item as meant to be picked as a sub-item rather than a standalone item — useful for granular tasks like "Check Coolant System Level" that rarely stand on their own. A flagged item shows "(Sub-Item)" after its name everywhere Service Items appear in a picker dropdown (the main Database Item picker, every Sub Item picker on a service record, and every Sub Item picker on another Service Item's own bundle), so it's easy to tell apart from a standalone master item at a glance. The flag is purely a label — it doesn't hide the item from any picker or stop it from being picked as a master item too.
- The Service Items list now shows both sides of the sub-item relationship: a master item's row lists its bundled sub-items under a "Sub-Items:" heading, one bullet per sub-item (with that sub-item's labor cost, if any) right under its parts, and any item marked "Mark as Sub-Item" gets an orange "SUB-ITEM" tag next to its name plus an orange-tinted card background — vs. the usual blue — so browsing the list makes it obvious at a glance which items are meant to stand alone and which are meant to be picked into something else.
- New "List Sub-Items Last" checkbox above the Service Items list: when checked, every item marked "Mark as Sub-Item" moves to the bottom of the list, after all standalone items — the active sort still governs order within each of those two groups, it just no longer interleaves sub-items among the standalone ones. The setting is remembered between visits to the list.
- An "All Vehicles" item now says so on its row when a specific vehicle is scoped: previously the row only showed a vehicle name while browsing "All Vehicles" itself, so a generic item mixed into a single vehicle's list looked identical to that vehicle's own items with nothing to explain why it showed up there.
- Each embedded sub-item on a service record or Service Item now gets its own card in the edit form: previously all 5 slots (ITEM 1 through ITEM 5) shared one long card, separated only by a banner and a divider. Each slot is now its own card, matching how PART 1 through PART 5 already stand apart, so it's easier to see where one sub-item ends and the next begins. Sub-items on a Service Item's read-only details screen got the same split (matching the service record details screen, which already had it).

## Project List
- "Transfer to Additions":  same link-to-Additions capability added to the project item edit form.

## Settings
- New "Fuel Log — Fluid Checks": section in Settings.

## Help & Feedback
- New "Send Feedback" form: under Resources on iPhone/iPad, and in the Support section of Help on Mac. 
- What's New now groups each version's entries: under the area they affect, each on a faint tinted heading, rather than running them together as one long list.

## Backup & Restore
- New "Automatic Backups" section: lets you choose how often & how many recent backups to keep. 
- The backup date under the Backup button is now two separate, independently tracked lines:
- When restoring while iCloud sync is active, you can now choose "Resync from iCloud": (re-downloads vehicle/service data fresh from iCloud) or "Restore Exact Snapshot" (forces the backup's database back in exactly as saved).

## PDF Reports
- Reports were redesigned: with a consistent portrait layout, combined data categories, an in-report vehicle picker, and a totals summary specific to each report's own data.

## Data Export
- New "Export CSV" button on every report screen: produces a full spreadsheet of every field behind that report — not just what's shown on the PDF — including resolved names like a vehicle's display name instead of its raw ID.
- You choose where the file goes: CSV export uses the system save/share sheet instead of a fixed folder, so it can go straight to Files, Mail, or any other app.

FIXED

## Vehicles
- Vehicle name not persisting after edit: (EditVehicle.swift): updateItem() was writing to dataSet.name but not dataSet.displayName.
- Editing a vehicle's Name now warns that other records: reference the vehicle by name and might lose their link if the name changes. On Save, the user can choose to automatically update all of those records to the new name, or save without updating them.
- A newly created vehicle's Name field now starts blank: with a "(New Vehicle)" placeholder instead of showing its internal placeholder ID.

## Fuel Log
- The edit form now re-reads the record when opened: so values written by a travel log's enroute stop (DEF price, quantities, levels) appear instead of whatever was loaded the first time the form was shown.
- Saving no longer discards the value in whichever field you were still typing in:

## Trip Log & Fuel Log
- Exact typed fuel and DEF quantities are no longer replaced: by their eighths equivalents every time the record is opened.
## Service Records
- Miles and Engine Hours are no longer show:n in the records list when their value is 0.
- Renaming a Service Item now also updates every sub-item slot that referenced it: previously the rename-cascade prompt only fixed up a record's own Database Item link, so a rename could silently orphan any of the 5 sub-item slots (on a service record or on another Service Item's own bundle) that pointed to the renamed item by name.

## Backup & Restore
- The post-backup summary dialog is now scrollable:
- Creating a backup no longer freezes the app while it scans your data:
- Backups now include hidden support files that were previously skipped:
- Selecting a folder that isn't actually a valid backup now shows an error: instead of silently reporting "Restore complete" with nothing restored.
- If a restore is interrupted partway through (e.g. low disk space), your existing data is now safely rolled back: instead of being left partially overwritten.
- After a successful restore, the app now requires a full restart: to finish loading the restored data safely.
- When iCloud sync is active, restoring no longer automatically overwrites: your local database with the backup snapshot.

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
