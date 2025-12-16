import Foundation
import CoreLocation
import SwiftUI

@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isFetching: Bool = false
    @Published private(set) var lastError: Error?

    private let locationManager: CLLocationManager
    private let geocoder: CLGeocoder

    override init() {
        locationManager = CLLocationManager()
        geocoder = CLGeocoder()
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    // Public async method to get current place string
    func currentPlaceString(preferBusinessName: Bool = true) async -> String? {
        lastError = nil

        // Ensure authorization
        let status = await requestAuthorizationIfNeeded()
        switch status {
        case .denied, .restricted:
            return nil
        default:
            break
        }

        do {
            isFetching = true
            let location = try await requestOneLocation()
            let placemarks = try await reverseGeocode(location: location)
            isFetching = false

            guard let placemark = placemarks.first else {
                return nil
            }

            if preferBusinessName,
               let name = placemark.areasOfInterest?.first ?? placemark.name,
               !name.isEmpty {
                return name
            }

            let address = Self.composeAddress(from: placemark)
            if !address.isEmpty {
                return address
            }

            return placemark.name
        } catch {
            self.lastError = error
            self.isFetching = false
            return nil
        }
    }

    private func requestAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            return await withCheckedContinuation { continuation in
                let delegate = AuthorizationDelegate {
                    continuation.resume(returning: self.locationManager.authorizationStatus)
                }
                locationManager.delegate = delegate
                locationManager.requestWhenInUseAuthorization()
                // The AuthorizationDelegate instance needs to be kept alive until callback
                self.authorizationDelegateHolder = delegate
            }
        } else {
            return status
        }
    }

    private func requestOneLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = LocationRequestDelegate { result in
                continuation.resume(with: result)
            }
            locationManager.delegate = delegate
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.requestLocation()
            // Keep delegate alive until callback
            self.locationRequestDelegateHolder = delegate
        }
    }

    private func reverseGeocode(location: CLLocation) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    // Compose a short address string from placemark components
    private static func composeAddress(from placemark: CLPlacemark) -> String {
        var parts: [String] = []

        if let street = placemark.thoroughfare {
            parts.append(street)
        }
        if let city = placemark.locality {
            parts.append(city)
        }
        if let state = placemark.administrativeArea {
            parts.append(state)
        }

        return parts.joined(separator: ", ")
    }

    // Hold delegates so they don't get deallocated immediately
    private var authorizationDelegateHolder: AuthorizationDelegate?
    private var locationRequestDelegateHolder: LocationRequestDelegate?
}

// MARK: - CLLocationManagerDelegate helpers

private final class AuthorizationDelegate: NSObject, @MainActor CLLocationManagerDelegate {
    private let continuation: () -> Void

    init(continuation: @escaping () -> Void) {
        self.continuation = continuation
        super.init()
    }

    @MainActor
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuation()
    }
}

private final class LocationRequestDelegate: NSObject, @MainActor CLLocationManagerDelegate {
    private let callback: (Result<CLLocation, Error>) -> Void

    init(callback: @escaping (Result<CLLocation, Error>) -> Void) {
        self.callback = callback
        super.init()
    }

    @MainActor
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            callback(.success(location))
        } else {
            callback(.failure(LocationError.noLocations))
        }
        // Remove delegate to break retain cycle
        cleanupDelegate(from: manager)
    }

    @MainActor
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        callback(.failure(error))
        cleanupDelegate(from: manager)
    }

    @MainActor
    private func cleanupDelegate(from manager: CLLocationManager) {
        manager.delegate = nil
    }

    enum LocationError: Error {
        case noLocations
    }
}

extension LocationProvider: @MainActor CLLocationManagerDelegate {
    @MainActor
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
}
