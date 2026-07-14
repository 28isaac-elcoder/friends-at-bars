import MapKit
import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.002, longitude: -83.008),
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(appModel.venues) { venue in
                    Annotation(venue.name, coordinate: CLLocationCoordinate2D(
                        latitude: venue.latitude,
                        longitude: venue.longitude
                    )) {
                        VStack(spacing: 2) {
                            if let count = appModel.venueCounts[venue.name], count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .padding(4)
                                    .background(.green.opacity(0.9))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                        }
                    }
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appModel.refreshCatalog() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await appModel.refreshCatalog() }
        }
    }
}
