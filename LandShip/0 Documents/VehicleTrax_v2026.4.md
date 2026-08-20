# VehicleTrax
### Complete Vehicle Management for iOS and macOS
**Version 2026.4 — Release Notes & Feature Overview**

---

## What is VehicleTrax?

VehicleTrax is a comprehensive vehicle management application built for iPhone, iPad, and Mac. All data is stored in a private iCloud-backed database and synced automatically across every device on your Apple account. Enter your information once and it's available everywhere — no subscriptions, no cloud fees beyond your existing iCloud storage.

VehicleTrax tracks the full lifecycle of your vehicles: fuel consumption, trip logs, parts inventory, service history, maintenance schedules, vendor contacts, upgrades and modifications, recurring expenses, project planning, and reusable inspection checklists.

---

## What's New in Version 2026.4

### Improvements & Add-Ins
Track every upgrade, modification, and accessory added to your vehicles. From lift kits and floor mats to custom lighting and performance parts, each addition is documented with name, category, vendor, cost, photos, and the mileage or engine hours at the time of installation.

- Records grouped by category and sub-category with live subtotals and a grand total
- Attach up to five photos per record (before/after, receipts, installation shots)
- Dashboard integration: a new Additions Cost card shows total modification spend per vehicle and across your fleet
- PDF report generation filtered by vehicle or across all vehicles

### Expenses & Subscriptions
Capture recurring charges and one-time expenses tied to your vehicles. Insurance premiums, roadside assistance, registration fees, satellite radio, GPS tracking, and lease payments all belong here — giving you a true total cost of ownership picture.

- Flag items as recurring charges for easy identification
- Category and sub-category grouping with cost subtotals and grand total
- PDF report generation with full cost breakdown
- Filter by vehicle to review per-vehicle expense history

### Projects & Punch Lists
Plan, track, and document vehicle projects from start to finish. Restorations, seasonal prep, multi-phase builds, or any organized list of work — Projects keeps it structured.

- Create projects with categories, sub-categories, descriptions, and notes
- Each project has an ordered punch list of tasks with completion checkboxes
- Drag to reorder both projects and individual tasks
- **Live Punch List view** — a streamlined in-garage interface for checking off items in real time on iPhone or iPad
- Two PDF reports: Project List summary and detailed Punch List report
- Rename and reorder categories; rename the "Sub-Items" label per item

### CheckLists & Sub-Items
A reusable checklist system for routine inspections, pre-trip walkarounds, seasonal maintenance, and any repeatable process. Unlike Projects, CheckLists are designed to be used over and over.

- **Sub-Items**: each checklist item can contain unlimited sub-items for granular step-by-step breakdowns
- Visual indicators show completed (✓ green) and in-progress (○ orange) sub-item counts at a glance
- **Smart completion logic**: checking a parent automatically completes all sub-items; completing all sub-items automatically marks the parent complete
- Customizable sub-item section labels per parent item ("Steps", "Tasks", or any label)
- Collapse/expand sub-item groups to keep the view focused
- Cascading deletion: removing a parent item removes all its sub-items
- **Live CheckList view** — real-time interactive interface optimized for in-field and in-garage use
- PDF report of checklist items and completion status
- Context menus for quick actions: add sub-items, rename sections, expand/collapse

### Dashboard Enhancements
- New **Additions Cost** card showing vehicle modification spend by category with fleet-wide totals
- Updated layout to accommodate the expanded set of tracked data

---

## Core Features (All Versions)

### Garage
**Vehicles** — The anchor of the entire application. Define each vehicle with full specifications: make, model, year, VIN, mileage, engine hours, fuel type, capacity, and more. Every other module links back to a vehicle.

**Parts Inventory** — Catalog every part across your fleet: part number, description, quantity on hand, location, cost, vendor, and compatibility. Parts feed directly into Service Items and Service Records.

### Vehicle Service
**Service Items (Templates)** — Define reusable maintenance templates: oil changes, tire rotations, brake inspections, filter replacements. Set service intervals by mileage, engine hours, or calendar date. Templates pre-fill new Service Records to speed data entry.

**Service Records** — Log every maintenance event: date, mileage, hours, work performed, parts used, vendor, cost, and notes. Records link back to Service Items and Parts for a complete, searchable service history. Generate PDF service reports per vehicle.

### Data Tracking
**Fuel Log** — Record every fill-up: date, odometer, gallons/liters, price per unit, total cost, and station. Fuel economy (MPG, L/100km, km/L) is calculated automatically. View trends over time.

**Trip Log** — Document trips with start/end odometer, date, duration, purpose, route notes, and cost. Supports personal and business use tracking.

### Setup
**Systems** — Define vehicle systems (Engine, Transmission, Brakes, Electrical, etc.) to categorize service work. Systems link to Service Items for organized reporting and filtering.

**Vendors / Shops** — Maintain a directory of parts suppliers, repair shops, and service providers. Store contact info, account numbers, labor rates, and notes. Vendors populate dropdowns across Parts, Service Items, and Records.

**Settings** — Configure units of measure (miles/km, gallons/liters, MPG/L/100km), currency, date format, and other application-wide preferences. Settings sync via iCloud.

### Data Management
**Backup & Restore** — Create point-in-time backups of your entire database to Files or iCloud Drive, with optional inclusion of attached photos. Restore from any saved backup. Cross-device portable — a backup from iPhone can be restored on Mac.

---

## Platform Support

| Platform | Minimum Version |
|---|---|
| iPhone | iOS 17 |
| iPad | iPadOS 17 |
| Mac | macOS 14 Sonoma |

All data syncs via iCloud across all platforms on the same Apple ID.

---

## Version History

| Version | Date | Highlights |
|---|---|---|
| 2026.4.1 | March 2026 | Additions, Expenses/Subscriptions, Projects & Punch Lists, CheckLists with Sub-Items, Dashboard Additions Cost card |
| 2025.12.4 | December 2025 | "All Vehicles" alert dialogs in Fuel, Trip, Records, and Items; in-app changelog display |
| 2025.12.1 | December 2025 | Initial release: Vehicles, Parts, Fuel Log, Trip Log, Service Items, Service Records, Systems, Vendors, Settings, Backup/Restore, CloudKit sync |

---

*VehicleTrax — Know your vehicles, inside and out.*
