# API Reference

This document covers the Supabase API integration used in the Kerala Private Bus Tracker application.

> [!NOTE]
> All API calls use the Supabase Flutter client. Authentication tokens are automatically managed.

## Authentication (Demo Mode)

> [!NOTE]
> This is a demo application. It does NOT use Supabase Auth. User authentication is simulated using the `public.users` table directly.

### Demo Login Flow

```dart
// Check if user exists by phone
static Future<UserModel?> fetchUserByPhone(String phone) async {
  final response = await supabase
    .from('users')
    .select()
    .eq('phone', phone)
    .maybeSingle();
  return response != null ? UserModel.fromJson(response) : null;
}

// Create new user (auto-registration)
static Future<UserModel> createUser(String phone, String name) async {
  final response = await supabase
    .from('users')
    .insert({'phone': phone, 'name': name, 'role': 'user'})
    .select()
    .single();
  return UserModel.fromJson(response);
}
```

---

## Database Queries

### SupabaseQueries Class

Central service for all database operations.

### User Operations

```dart
// Fetch user by auth ID
static Future<UserModel?> fetchUserById(String id) async {
  final response = await supabase
    .from('users')
    .select()
    .eq('id', id)
    .maybeSingle();
  return response != null ? UserModel.fromJson(response) : null;
}

// Create new user
static Future<void> createUser(UserModel user) async {
  await supabase.from('users').insert(user.toJson());
}

// Update user
static Future<void> updateUser(String id, Map<String, dynamic> data) async {
  await supabase.from('users').update(data).eq('id', id);
}
```

### Bus Operations

```dart
// Fetch all buses with route info
static Future<List<BusModel>> fetchAllBuses() async {
  final response = await supabase
    .from('buses')
    .select('*, routes(*)')
    .order('name');
  return response.map((e) => BusModel.fromJson(e)).toList();
}

// Fetch available buses
static Future<List<BusModel>> fetchAvailableBuses() async {
  final response = await supabase
    .from('buses')
    .select('*, routes(*)')
    .eq('is_available', true);
  return response.map((e) => BusModel.fromJson(e)).toList();
}

// Update bus availability
static Future<void> updateBusAvailability(
  String busId, 
  bool isAvailable,
  {String? reason}
) async {
  await supabase.from('buses').update({
    'is_available': isAvailable,
    'unavailability_reason': reason,
  }).eq('id', busId);
}
```

### Route Operations

```dart
// Fetch all routes
static Future<List<RouteModel>> fetchAllRoutes() async {
  final response = await supabase
    .from('routes')
    .select()
    .order('name');
  return response.map((e) => RouteModel.fromJson(e)).toList();
}

// Create route
static Future<void> createRoute(RouteModel route) async {
  await supabase.from('routes').insert(route.toJson());
}

// Update route stops (JSONB)
static Future<void> updateRouteStops(
  String routeId, 
  List<StopModel> stops
) async {
  await supabase.from('routes').update({
    'stops': stops.map((s) => s.toJson()).toList(),
  }).eq('id', routeId);
}
```

### Location Updates

```dart
// Update vehicle state (conductor)
static Future<void> updateVehicleState({
  required String busId,
  required double lat,
  required double lng,
  required double speed,
  required double heading,
}) async {
  // Insert observation
  final obs = await supabase.from('vehicle_observations').insert({
    'bus_id': busId,
    'lat': lat,
    'lng': lng,
    'speed_mps': speed,
    'heading_deg': heading,
  }).select().single();

  // Update state
  await supabase.from('vehicle_state').upsert({
    'bus_id': busId,
    'lat': lat,
    'lng': lng,
    'speed_mps': speed,
    'heading_deg': heading,
    'observation_id': obs['id'],
  });
}

// Fetch vehicle state
static Future<VehicleStateModel?> getVehicleState(String busId) async {
  final response = await supabase
    .from('vehicle_state')
    .select()
    .eq('bus_id', busId)
    .maybeSingle();
  return response != null 
    ? VehicleStateModel.fromJson(response) 
    : null;
}
```

### SOS Alerts

```dart
// Create SOS alert
static Future<void> createSOSAlert(SOSAlertModel alert) async {
  await supabase.from('sos_alerts').insert(alert.toJson());
}

// Fetch active alerts (admin)
static Future<List<SOSAlertModel>> fetchActiveSOSAlerts() async {
  final response = await supabase
    .from('sos_alerts')
    .select('*, users(*), buses(*)')
    .eq('status', 'active')
    .order('created_at', ascending: false);
  return response.map((e) => SOSAlertModel.fromJson(e)).toList();
}

// Acknowledge alert
static Future<void> acknowledgeAlert(String alertId, String adminId) async {
  await supabase.from('sos_alerts').update({
    'status': 'acknowledged',
    'acknowledged_by': adminId,
    'acknowledged_at': DateTime.now().toIso8601String(),
  }).eq('id', alertId);
}
```

---

## Realtime Subscriptions

### Vehicle Location Updates

```dart
// Subscribe to bus location
supabase
  .from('vehicle_state')
  .stream(primaryKey: ['bus_id'])
  .eq('bus_id', busId)
  .listen((data) {
    if (data.isNotEmpty) {
      final state = VehicleStateModel.fromJson(data.first);
      // Update UI
    }
  });
```

### Conductor Assignment Changes

```dart
// Listen for bus assignment
supabase
  .from('buses')
  .stream(primaryKey: ['id'])
  .eq('conductor_id', conductorId)
  .listen((data) {
    // Handle assignment change
  });
```

### SOS Alert Notifications

```dart
// Admin: Listen for new alerts
supabase
  .from('sos_alerts')
  .stream(primaryKey: ['id'])
  .listen((data) {
    final activeAlerts = data.where((a) => a['status'] == 'active');
    // Update alert count
  });
```

---

## External APIs

### OSRM Routing Service

Used for route polyline generation.

```dart
// Fetch route path between stops
Future<List<LatLng>> fetchRoutePath(List<StopModel> stops) async {
  final coordinates = stops
    .map((s) => '${s.lng},${s.lat}')
    .join(';');
    
  final url = 'https://router.project-osrm.org/route/v1/driving/'
    '$coordinates?overview=full&geometries=polyline';
    
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  
  // Decode polyline
  final geometry = data['routes'][0]['geometry'];
  return decodePolyline(geometry)
    .map((p) => LatLng(p[0], p[1]))
    .toList();
}
```

### Geocoding Service

For landmark/place search.

```dart
// Search by place name
import 'package:geocoding/geocoding.dart';

Future<List<Location>> searchPlace(String query) async {
  return await locationFromAddress(query);
}

// Reverse geocode
Future<List<Placemark>> getPlaceName(double lat, double lng) async {
  return await placemarkFromCoordinates(lat, lng);
}
```

---

## Error Handling

All API calls should handle Supabase exceptions:

```dart
try {
  await SupabaseQueries.someOperation();
} on PostgrestException catch (e) {
  // Database error
  print('Database error: ${e.message}');
} on AuthException catch (e) {
  // Authentication error
  print('Auth error: ${e.message}');
} catch (e) {
  // Generic error
  print('Error: $e');
}
```

---

*For setup instructions, see [Setup Guide](./setup.md)*
