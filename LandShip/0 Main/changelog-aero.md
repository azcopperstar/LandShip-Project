AEROTRAX CHANGE LOG

Send suggestions for features & improvements to: [info@aeronauticaltrax.com](mailto:info@aeronauticaltrax.com)

----------------------------------
Version: 2026.09.07 Build: 108
ADDED

## Fluid Checks
- Aviation-specific fluid check items: the Fluid Checks popup (Fuel Log and Travel Log) now shows aircraft items — Engine Oil, Hydraulic Fluid, Brake Fluid, Deice/TKS Fluid, and Fuel Strainer/Gascolator Drained — instead of the land-vehicle list.
- Configurable in Settings: choose which items appear under Settings > Fluid Checks.

## Location
- Nearest airport lookup: the Location field on Fuel Log and Travel Log lists the 2 closest airports by ICAO/IATA code and distance, each with a "Use" button.
- Current location shown: a caption below the field displays your current latitude/longitude.
- Home Location: set a Home location in Settings from your current position — it becomes the top "Use" choice whenever it's closer than the nearest airport.

----------------------------------
Version: 2026.09.07 Build: 98
ADDED

## Fuel Log
- Canonical uplift tracking: record quantity in gallons, pounds, liters, or kilograms alongside the fueling ticket's density, so weight and volume convert correctly instead of assuming Jet A's nominal 6.7 lb/gal.
- Full/partial fill tracking: mark each uplift Full, Partial, Topped Off, Tankered, or Defuel — economy is now measured between known-full points, with a flag shown whenever a partial fill or missing history affects the number.
- Fuel on board and UTC offset: record FOB before/after a fill and the capture-time UTC offset, for reconciling against trip sheets kept in Zulu.
- Cost & Contract Fuel: track posted vs. contract price, contract release number, loyalty discounts, tax breakout (federal excise/state/local/sales), the full fee stack (flowage, into-plane, ramp, handling, overnight, facility, after-hours, GPU, lav service), fee-waiver thresholds, and currency/VAT for international stops.
- Fuel Quality: sump/water check results, fuel sample retention, FSII/biocide/static-dissipator additives, and SAF blend percentage with certificate reference.
- Performance: planned burn, taxi fuel, landing reserve, and burn by flight phase (climb/cruise/descent).
- Linkage: trip/mission number, cost center, client, and operating rule (Part 91/135/121) for charter and fractional billing.
- Fuel Program report: a new PDF report showing price and contract-fuel trend by airport, plus fee-waiver misses, alongside the existing Fuel Log report.
- Attachments: attach fueling tickets and receipts directly to a Fuel Log entry.

----------------------------------
Version: 2026.09.02 Build: 97
NOTES
- Initial launch of new product
- AeroTrax is a personal aircraft recordkeeping tool. It does not replace your official aircraft maintenance logbook, an A&P/IA's signoff, or your own research into applicable Airworthiness Directives — always verify compliance through official FAA sources before flight.
- Email us (using the above link or the link on the Resources tab) with suggestions for improvements, application features, or issues with the application.

ADDED

## Aircraft
- Aviation terminology throughout: Hangar, Hobbs Time, Tach Time, Tail Number, and Flight Log replace their land-vehicle equivalents everywhere in the app.
- Airworthiness Directives, Inspection Cycles, and Component Times: dedicated records for tracking AD compliance, recurring inspections, and individual component time-in-service.
- Pilot Logbook: certifications and flight logbook entries, with a dedicated PDF report.

## Fuel Log
- Aviation Fuel Types: the Fuel Type picker now shows aviation-correct fuels (100LL, Jet A/A-1, SAF, military JP-series, and more) grouped by category, instead of the land-vehicle Gasoline/Diesel/EV/Hybrid list.
- Configurable fuel list: choose which fuel types appear in the picker under Settings > Fuel Types — the selection syncs across your devices.
