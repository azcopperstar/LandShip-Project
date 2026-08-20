VEHICLETRAX CHANGE LOG

Send suggestions for features & improvements to: [info@aeronauticaltrax.com](mailto:info@aeronauticaltrax.com)

----------------------------------
Version: 2026.09.01 Build: 78
ADDED
- Settings: New "Fuel Log — Fluid Checks" section in Settings. Each of the 10 fluid check items can be individually shown or hidden. Hidden checks no longer appear in the Fluid Checks popup.
- Fuel Log: The 10 inline fluid check toggles in the edit form are replaced by a "Fluid Checks" button that opens a popup sheet. Only checks enabled in Settings are shown in the popup.
- Travel Log: The inline "Oil Checked" toggle in each enroute stop section is replaced by a "Fluid Checks" button that opens a popup sheet.
- Fuel Log: Field to track DEF price per gallon 
- Fuel Log: Field to track DEF remaining in 1/8 increments 
- Travel Log: Date/time field for each enroute fuel stop; value propagates to the linked Fuel Log record on save.
- Travel Log: Option to attach up to 3 photos to each enroute fuel stop; photos save to the linked Fuel Log record and display as thumbnails in the trip detail view.
- Travel Log: Exit time field for each enroute fuel stop. Trip detail view shows "Departed" time per stop, plus computed "Stop Time" and "Time Moving" totals based on stop durations.
- Travel Log: Enroute fuel stop sections renamed to "Stop #" — stops can now also track Stop Reason. Reason appears in the trip detail view.
- Travel Log: "Other" stop reason opens a text field to enter a custom description; custom text is stored directly and displayed in the detail view.
- Travel Log: Comments field added to each enroute stop for free-form notes; displayed in the trip detail view.
- Travel Statistics: Three computed time fields — Total Elapsed (start to end), Time Underway (total minus stop time), and Engine Time (engine hours end minus start).
- Vehicle Totals: Same three time fields accumulated across all trips — Total Elapsed, Underway Hours, and Engine Time.
- Fuel Log: FLUID CHECKS section with 10 toggles to record which fluids were inspected at each fuel stop
- Travel Log: Trip Group field added to each travel log record. Groups allow related trip legs (e.g. legs of a single journey) to be associated under a named group. The group name is assigned in the GENERAL section of the edit form via a dropdown picker populated from existing group names; a "New Group..." option reveals a text field to create a new group name.
- Travel Log: GROUP TOTALS card added to the travel log detail view.
- Vehicle record: Added Wheel Stud Size, Wheel Nut Socket, and Wheel Nut Torque text fields to the Tire Information section.
- Vehicle record: Added weight scale reading fields to the Weight Data section (all axles except trailer) and Total Rolling Weight (all axles combined) are computed and displayed automatically.
- Vehicle record: Added CAT Scale Tickets sub-form. Each vehicle can store unlimited weigh station tickets. Gross weight is computed automatically from the three axle weights. Tickets are listed in the vehicle detail view and can be added or edited from the edit form.
- Service Records: "Transfer to Additions" — a new LINK TO ADDITIONS card in the service record edit form allows each part and labor line item to be individually transferred into the Additions tracker. A category picker (with option to create a new category) and optional sub-category are assigned at transfer time. 
- Project List: "Transfer to Additions" — same link-to-Additions capability added to the project item edit form. 
- Vehicle record: Added ability to link vehicle records together to track different aspects of the same physical vehicle (e.g. Chassis, Engine, Body/House). One linked record acts as the master; other records choose which fields to mirror from it via a new checkable "Synced Fields" popup, and stay in step automatically whenever the master is saved.
- Vehicles List: Rows now show "Linked to: [vehicle]" if the vehicle links to a master, and "Linked vehicles: [names]" if the vehicle is itself a master.
- Service Records & MX Items: Added a custom tracking field to each service record — user defines a field name, unit of measure, and numeric value to track anything beyond Miles/Engine Hours (e.g. Water Gallons). 
- Dashboard: New customization sheet (slider icon in the toolbar) lets you choose which cards are shown and drag to reorder them. The scheme is saved to your account and applies on every device.
- Dashboard: Four cards that existed in the app but weren't wired up are now available to enable.
- Dashboard: New vehicle checklist in the customization sheet lets you exclude specific vehicles from "All Vehicles" totals across every card.
- Trip Log: Stop Location field no longer auto-fills with current location. The arrow button must be pressed to fill in location. 
- Trip Log: Enroute stop fields (location, date/time, quantity, fluids, notes, photos, etc.) stay hidden on a new stop until a Stop Reason is chosen; once selected, the full set of fields is shown.
- Trip Log List: Each trip row now shows both "Total Enroute" (start to end) and "Underway" (total enroute minus time spent at enroute stops) time.
- Trip Log: The Quantity field on an enroute stop is hidden unless Stop Reason is set to "Fuel".
- Trip Log List: Each trip row now shows Group (if assigned), Total Miles, and Total Fuel used, together on one line (e.g. "Group: Trip A   142mi   15.2gal"). For trips in a group, miles and fuel reflect the sum across every leg in that group, not just the current leg.
- Trip Log List: The "Total Enroute" time line on each trip row is replaced with "Fuel Burn" for that individual leg, shown below "Time Underway" (renamed from "Underway").
- Fuel Log List: The Fuel line on each row now also shows price per unit (e.g. "$3.89/gal"), and a DEF line (quantity and price per unit) is shown below it when DEF was added.
- Fuel Log List: The section header now shows Total Fuel, Total Cost, and Average Cost/Unit for the currently listed records, plus a second line with Distance and Average Fuel Economy when a single vehicle is selected.
- Trip Log List: The section header now shows Total Miles, Total Fuel, and Average Economy on one line, plus Time Underway and Average Speed on a second line, for the currently listed trips.

FIXED
- Service Records: Miles and Engine Hours are no longer shown in the records list when their value is 0.
- Vehicle name not persisting after edit (EditVehicle.swift): updateItem() was writing to dataSet.name but not dataSet.displayName. D
- Vehicle record: Editing a vehicle's Name now warns that other records reference the vehicle by name and will lose their link if the name changes. On Save, the user can choose to automatically update all of those records to the new name, or save without updating them.
- Vehicle record: A newly created vehicle's Name field now starts blank with a "(New Vehicle)" placeholder instead of showing its internal placeholder ID. Saving a blank name, or a name already used by another vehicle, is blocked with a warning instead of being allowed to save.

NOTES
- This was a major revision with many new options added.  Updates were delayed due to mistaken update of xCode to beta version which App Connect would not accept.

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
