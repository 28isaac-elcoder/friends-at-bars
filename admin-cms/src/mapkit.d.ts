/**
 * Minimal MapKit JS types for init + Map + MarkerAnnotation.
 * Apple docs: https://developer.apple.com/documentation/mapkitjs
 */
export {};

declare global {
  interface MapKitMapOptions {
    region?: mapkit.CoordinateRegion;
  }

  namespace mapkit {
    function init(options: {
      authorizationCallback: (done: (token: string) => void) => void;
    }): void;

    class Coordinate {
      constructor(latitude: number, longitude: number);
      latitude: number;
      longitude: number;
    }

    class CoordinateRegion {
      constructor(center: Coordinate, span: CoordinateSpan);
    }

    class CoordinateSpan {
      constructor(latitudeDelta: number, longitudeDelta: number);
    }

    interface MapEvent {
      coordinate?: Coordinate;
      annotation?: Annotation;
      pointOnPage?: DOMPoint;
    }

    class Map {
      constructor(element: HTMLElement, options?: MapKitMapOptions);
      region: CoordinateRegion;
      addAnnotation(annotation: Annotation): void;
      removeAnnotation(annotation: Annotation): void;
      destroy(): void;
      selectedAnnotation: Annotation | null;
      annotations: Annotation[];
      convertPointOnPageToCoordinate(point: DOMPoint): Coordinate;
      addEventListener(
        type: string,
        listener: (event: MapEvent) => void
      ): void;
      removeEventListener(
        type: string,
        listener: (event: MapEvent) => void
      ): void;
    }

    class Annotation {
      coordinate: Coordinate;
      title: string;
      subtitle?: string;
      draggable?: boolean;
      data?: unknown;
      addEventListener(
        type: string,
        listener: (event: { target: Annotation }) => void
      ): void;
      removeEventListener(
        type: string,
        listener: (event: { target: Annotation }) => void
      ): void;
    }

    class MarkerAnnotation extends Annotation {
      constructor(
        coordinate: Coordinate,
        options?: {
          title?: string;
          subtitle?: string;
          color?: string;
          draggable?: boolean;
        }
      );
      color?: string;
    }
  }
}
