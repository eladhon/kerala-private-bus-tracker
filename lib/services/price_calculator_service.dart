import 'dart:math' show cos, sqrt, asin;

class PriceCalculatorService {
  // Constants for pricing
  static const double baseRateNormal = 10.0;
  static const double ratePerKmNormal = 1.5;

  /// Calculate Haversine distance between two points in km
  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Estimate ticket price
  /// [isStudent] applies the concession curve:
  /// Ranges from ₹1 (1km) to approx ₹50 (48km)
  double estimatePrice(double distanceKm, {bool isStudent = false}) {
    if (distanceKm <= 0) return 0;

    if (isStudent) {
      // Student Logic:
      // 1km -> ~1
      // 48km -> ~50
      // Linear approx: y = 1.05 * x
      // We clamp minimum to ₹1
      double price = distanceKm * 1.05;
      if (price < 1) price = 1;
      // Optional: Cap at some max if needed, but 48km -> 50.4 fits the request
      return double.parse(price.toStringAsFixed(1));
    } else {
      // Normal Logic: Base + Rate/km
      // Example: 10 + 1.5 * dist
      double price = baseRateNormal + (ratePerKmNormal * distanceKm);

      // Minimum fare
      if (price < 10) price = 10;

      return double.parse(price.toStringAsFixed(0)); // Round to whole number
    }
  }
}
