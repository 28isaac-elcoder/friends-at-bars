import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject private var testMode = TestModeStore.shared
    @ObservedObject private var locationAuth = LocationAuthorizationStore.shared
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.002, longitude: -83.008),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )
    @State private var selectedVenue: CatalogVenue?

    /// Live OS permission, or Test Mode mock + simulate-location toggle.
    private var mapUnlocked: Bool {
        if testMode.uiEnabled && testMode.useMockCheckIns {
            return testMode.simulateLocationAllowed
        }
        return locationAuth.isAuthorized
    }

    /// Highest live headcount among currently shown venues (for relative heat).
    private var maxAttendance: Int {
        appModel.venues.reduce(0) { partial, venue in
            max(partial, appModel.venueCounts[venue.name, default: 0])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(appModel.venues) { venue in
                        let count = appModel.venueCounts[venue.name, default: 0]
                        Annotation(
                            venue.name,
                            coordinate: CLLocationCoordinate2D(
                                latitude: venue.latitude,
                                longitude: venue.longitude
                            )
                        ) {
                            Button {
                                selectedVenue = venue
                            } label: {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(pinColor(count: count, maxCount: maxAttendance))
                                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }

                    if mapUnlocked {
                        UserAnnotation()
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .tint(.green)
                .mapControls {
                    MapCompass()
                }
                .disabled(!mapUnlocked)

                if !mapUnlocked {
                    if testMode.uiEnabled && testMode.useMockCheckIns {
                        testModeLocationGate
                    } else {
                        LocationAllowOverlay()
                    }
                }

                if let venue = selectedVenue {
                    venuePopup(venue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
                if testMode.uiEnabled && testMode.useMockCheckIns {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            testMode.simulateLocationAllowed.toggle()
                            DiagnosticLog.shared.append(
                                category: "system",
                                message: "Map simulate location allowed=\(testMode.simulateLocationAllowed)"
                            )
                        } label: {
                            Image(systemName: testMode.simulateLocationAllowed
                                  ? "location.fill"
                                  : "location.slash")
                        }
                        .accessibilityLabel(
                            testMode.simulateLocationAllowed
                                ? "Simulate location on"
                                : "Simulate location off"
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation {
                            position = .userLocation(fallback: .automatic)
                        }
                    } label: {
                        Image(systemName: "location")
                    }
                    .disabled(!mapUnlocked)
                    .accessibilityLabel("Center on my location")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onChange(of: testMode.useMockCheckIns) { _, _ in
                selectedVenue = nil
                Task { await appModel.refreshCatalog() }
            }
            .onChange(of: testMode.simulateLocationAllowed) { _, allowed in
                if !allowed { selectedVenue = nil }
            }
            .onAppear { locationAuth.refresh() }
        }
    }

    /// Soft gate for Test Mode when simulate-location is off (parity with Activities/Chat).
    private var testModeLocationGate: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 40))
                Text("Simulate location access")
                    .font(.title3.bold())
                Text("Turn on the location toggle to preview the map with mock attendance — no Settings permission required in Test Mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    testMode.simulateLocationAllowed = true
                } label: {
                    Text("Light Up the Map")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 24)

                Text(LocationPrivacyCopy.underButton)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func venuePopup(_ venue: CatalogVenue) -> some View {
        let count = appModel.venueCounts[venue.name, default: 0]
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { selectedVenue = nil }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(venue.name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        if !venue.area.isEmpty {
                            Text(venue.area.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        selectedVenue = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }

                if count == 0 {
                    Text("No one checked in live right now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(count) \(count == 1 ? "person" : "people") live at venue")
                        .font(.subheadline.weight(.semibold))
                }

                Button {
                    openDirections(to: venue)
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 24)
        }
    }

    /// Relative heat: white when empty / below ~half of tonight’s busiest bar; bright red at the max.
    private func pinColor(count: Int, maxCount: Int) -> Color {
        guard count > 0, maxCount > 0 else {
            return .white
        }
        let ratio = Double(count) / Double(maxCount)
        // Keep most pins near white; only the busier half of the range reddens.
        let heat = max(0, min(1, (ratio - 0.45) / 0.55))
        return Color(
            red: 1.0,
            green: 1.0 - heat * 0.85,
            blue: 1.0 - heat * 0.9
        )
    }

    private func openDirections(to venue: CatalogVenue) {
        let coordinate = CLLocationCoordinate2D(
            latitude: venue.latitude,
            longitude: venue.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = venue.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
        ])
        DiagnosticLog.shared.append(
            category: "system",
            message: "Opened Apple Maps directions to \(venue.name)"
        )
    }
}
