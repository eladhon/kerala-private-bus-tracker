/// All Supabase database queries centralized - Facade Pattern
///
/// This file now acts as a facade that delegates to domain-specific query modules.
/// For backwards compatibility, all existing method signatures are preserved.
/// New code should prefer using the domain modules directly.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/bus_model.dart';
import '../models/bus_schedule_model.dart';
import '../models/route_model.dart';
import '../models/vehicle_state_model.dart';
import '../models/stop_model.dart';
import '../models/bus_trip_model.dart';
import '../models/user_preference_model.dart';
import '../models/conductor_review_model.dart';
import '../models/user_trip_history_model.dart';
import '../models/student_application_model.dart';
import '../models/conductor_report_model.dart';
import 'supabase_service.dart';
import 'queries/auth_queries.dart';
import 'queries/bus_queries.dart';
import 'queries/route_queries.dart';
import 'queries/user_queries.dart';
import 'queries/vehicle_queries.dart';
import 'queries/admin_queries.dart';

/// Facade for all Supabase queries
///
/// This class provides backward compatibility while delegating to
/// domain-specific query modules internally.
class SupabaseQueries {
  final SupabaseClient _client = SupabaseService().client;
  SupabaseClient get client => _client;

  // Domain-specific query modules
  final AuthQueries auth = AuthQueries();
  final BusQueries buses = BusQueries();
  final RouteQueries routes = RouteQueries();
  final UserQueries users = UserQueries();
  final VehicleQueries vehicles = VehicleQueries();
  final AdminQueries admin = AdminQueries();

  // ============================================
  // AUTH QUERIES (delegated to auth module)
  // ============================================

  Future<void> signInWithPhone(String phoneNumber) =>
      auth.signInWithPhone(phoneNumber);

  Future<AuthResponse> verifyOtp(String phoneNumber, String otpCode) =>
      auth.verifyOtp(phoneNumber, otpCode);

  Future<void> signOut() => auth.signOut();

  // ============================================
  // USER QUERIES (delegated to users module)
  // ============================================

  Future<UserModel?> getUserByPhone(String phoneNumber) =>
      users.getUserByPhone(phoneNumber);

  Future<UserModel?> getUserById(String userId) => users.getUserById(userId);

  Future<UserModel> createUser({
    required String phone,
    required String name,
    required String role,
    String? busId,
    bool isStudent = false,
  }) => users.createUser(
    phone: phone,
    name: name,
    role: role,
    busId: busId,
    isStudent: isStudent,
  );

  Future<void> updateUser(String userId, Map<String, dynamic> updates) =>
      users.updateUser(userId, updates);

  Future<void> updateUserStudentStatus(String userId, bool isStudent) =>
      users.updateUserStudentStatus(userId, isStudent);

  Future<String?> getUserRole(String phoneNumber) =>
      users.getUserRole(phoneNumber);

  Future<UserPreferenceModel?> getUserPreferences(String userId) =>
      users.getUserPreferences(userId);

  Future<void> upsertUserPreferences(UserPreferenceModel preferences) =>
      users.upsertUserPreferences(preferences);

  // ============================================
  // FAVORITES QUERIES (delegated to users module)
  // ============================================

  Future<bool> toggleFavorite(String busId, String userId) =>
      users.toggleFavorite(busId, userId);

  Future<bool> isBusFavorite(String busId, String userId) =>
      users.isBusFavorite(busId, userId);

  Future<List<BusModel>> getFavoriteBuses(String userId) =>
      admin.getFavoriteBuses(userId);

  // ============================================
  // BUS QUERIES (delegated to buses module)
  // ============================================

  Future<List<BusModel>> getAllBuses() => buses.getAllBuses();

  Future<List<BusModel>> getBusesByRoute(String routeId) =>
      buses.getBusesByRoute(routeId);

  Future<List<BusModel>> getAvailableBuses() => buses.getAvailableBuses();

  Future<BusModel?> getBusById(String busId) => buses.getBusById(busId);

  Future<List<BusModel>> getBusesByIds(List<String> ids) =>
      buses.getBusesByIds(ids);

  Future<BusModel?> getBusByConductorId(String conductorId) =>
      buses.getBusByConductorId(conductorId);

  Future<void> setBusAvailability(
    String busId,
    bool isAvailable, {
    String? reason,
  }) => buses.setBusAvailability(busId, isAvailable, reason: reason);

  Future<List<BusModel>> searchBuses(String query) => buses.searchBuses(query);

  Future<void> updateBus(String busId, Map<String, dynamic> updates) =>
      buses.updateBus(busId, updates);

  Future<BusModel> createBus({
    required String name,
    required String registrationNumber,
    required String routeId,
    String? conductorId,
    bool isAvailable = false,
    String? departureTime,
    List<BusScheduleModel> schedule = const [],
  }) => buses.createBus(
    name: name,
    registrationNumber: registrationNumber,
    routeId: routeId,
    conductorId: conductorId,
    isAvailable: isAvailable,
    departureTime: departureTime,
    schedule: schedule,
  );

  Future<void> deleteBus(String busId) => buses.deleteBus(busId);

  Future<List<Map<String, dynamic>>> getBusesWithLocations(String routeId) =>
      buses.getBusesWithLocations(routeId);

  Future<int> getAvailableBusCount() => buses.getAvailableBusCount();

  Future<int> getTotalBusCount() => buses.getTotalBusCount();

  // ============================================
  // ROUTE QUERIES (delegated to routes module)
  // ============================================

  Future<List<RouteModel>> getAllRoutes() => routes.getAllRoutes();

  Future<RouteModel?> getRouteById(String routeId) =>
      routes.getRouteById(routeId);

  Future<List<RouteModel>> searchRoutes(String query) =>
      routes.searchRoutes(query);

  Future<List<RouteModel>> getPopularRoutes({int limit = 5}) =>
      routes.getPopularRoutes(limit: limit);

  Future<RouteModel> createRoute({
    required String name,
    required String startLocation,
    required String endLocation,
    double? distance,
    bool isPopular = false,
    List<StopModel> stops = const [],
  }) => routes.createRoute(
    name: name,
    startLocation: startLocation,
    endLocation: endLocation,
    distance: distance,
    isPopular: isPopular,
    stops: stops,
  );

  Future<void> updateRoute(String routeId, Map<String, dynamic> updates) =>
      routes.updateRoute(routeId, updates);

  Future<void> deleteRoute(String routeId) => routes.deleteRoute(routeId);

  // ============================================
  // BUS STOP QUERIES (delegated to routes module)
  // ============================================

  Future<List<StopModel>> getAllBusStops() => routes.getAllBusStops();

  Future<void> createBusStop({
    required String name,
    required double latitude,
    required double longitude,
    String? routeId,
    int? orderIndex,
    int? minutesFromStart,
  }) => routes.createBusStop(
    name: name,
    latitude: latitude,
    longitude: longitude,
    routeId: routeId,
    orderIndex: orderIndex,
    minutesFromStart: minutesFromStart,
  );

  Future<void> updateBusStop(String stopId, Map<String, dynamic> updates) =>
      routes.updateBusStop(stopId, updates);

  Future<void> deleteBusStop(String stopId, String? routeId) =>
      routes.deleteBusStop(stopId, routeId);

  Future<List<StopModel>> getNearestBusStops(
    double latitude,
    double longitude, {
    int limit = 5,
  }) => routes.getNearestBusStops(latitude, longitude, limit: limit);

  // ============================================
  // VEHICLE QUERIES (delegated to vehicles module)
  // ============================================

  Future<void> insertVehicleObservation({
    required String busId,
    required double lat,
    required double lng,
    double? accuracyM,
    double? speedMps,
    double? headingDeg,
  }) => vehicles.insertVehicleObservation(
    busId: busId,
    lat: lat,
    lng: lng,
    accuracyM: accuracyM,
    speedMps: speedMps,
    headingDeg: headingDeg,
  );

  Future<List<VehicleStateModel>> getAllVehicleStates() =>
      vehicles.getAllVehicleStates();

  Future<VehicleStateModel?> getVehicleState(String busId) =>
      vehicles.getVehicleState(busId);

  Stream<VehicleStateModel?> streamVehicleState(String busId) =>
      vehicles.streamVehicleState(busId);

  Stream<List<VehicleStateModel>> streamAllVehicleStates() =>
      vehicles.streamAllVehicleStates();

  Future<List<VehicleStateModel>> getVehicleStatesOnRoute(
    String routeId,
  ) async {
    final busList = await buses.getBusesByRoute(routeId);
    final busIds = busList.map((b) => b.id).toList();
    return vehicles.getVehicleStatesOnRoute(routeId, busIds);
  }

  // ============================================
  // TRIP QUERIES (delegated to vehicles module)
  // ============================================

  Future<BusTripModel> startTrip({
    required String busId,
    required String routeId,
  }) => vehicles.startTrip(busId: busId, routeId: routeId);

  Future<void> endTrip(String tripId) => vehicles.endTrip(tripId);

  Future<BusTripModel?> getActiveTripForBus(String busId) =>
      vehicles.getActiveTripForBus(busId);

  Future<List<BusTripModel>> getTripHistory(String busId) =>
      vehicles.getTripHistory(busId);

  // ============================================
  // ADMIN QUERIES (delegated to admin module)
  // ============================================

  Future<Map<String, dynamic>?> authenticateAdmin(
    String username,
    String password,
  ) => admin.authenticateAdmin(username, password);

  Future<List<Map<String, dynamic>>> getAllAdmins() => admin.getAllAdmins();

  Future<Map<String, dynamic>> createAdmin({
    required String username,
    required String password,
    String? name,
  }) => admin.createAdmin(username: username, password: password, name: name);

  Future<void> updateAdmin(String adminId, Map<String, dynamic> updates) =>
      admin.updateAdmin(adminId, updates);

  Future<void> deleteAdmin(String adminId) => admin.deleteAdmin(adminId);

  // ============================================
  // CONDUCTOR QUERIES (delegated to users module)
  // ============================================

  Future<List<UserModel>> getAllConductors() => users.getAllConductors();

  Future<void> assignBusToConductor(String conductorId, String? busId) =>
      users.assignBusToConductor(conductorId, busId);

  Future<UserModel> createConductor({
    required String phone,
    required String name,
    String? busId,
  }) => users.createConductor(phone: phone, name: name, busId: busId);

  Future<void> updateConductor(
    String conductorId,
    Map<String, dynamic> updates,
  ) => users.updateConductor(conductorId, updates);

  Future<void> deleteConductor(String conductorId) =>
      users.deleteConductor(conductorId);

  // ============================================
  // REVIEWS QUERIES (delegated to admin module)
  // ============================================

  Future<List<ConductorReviewModel>> getConductorReviews(String conductorId) =>
      admin.getConductorReviews(conductorId);

  Future<List<ConductorReviewModel>> getAllReviews() => admin.getAllReviews();

  Future<void> deleteReview(String reviewId) => admin.deleteReview(reviewId);

  Future<void> addConductorReview(ConductorReviewModel review) =>
      admin.addConductorReview(review);

  Future<ConductorReviewModel?> getConductorReview(
    String conductorId, {
    String? userId,
  }) => admin.getConductorReview(conductorId, userId: userId);

  Future<void> upsertConductorReview({
    required String conductorId,
    required int rating,
    String? reviewText,
    String? existingReviewId,
    String? userId,
  }) => admin.upsertConductorReview(
    conductorId: conductorId,
    rating: rating,
    reviewText: reviewText,
    existingReviewId: existingReviewId,
    userId: userId,
  );

  // ============================================
  // MODERATION QUERIES (delegated to admin module)
  // ============================================

  Future<List<String>> getModerationFilters() => admin.getModerationFilters();

  Future<void> addModerationFilter(String phrase) =>
      admin.addModerationFilter(phrase);

  Future<void> deleteModerationFilter(String phrase) =>
      admin.deleteModerationFilter(phrase);

  // ============================================
  // USER HISTORY QUERIES (delegated to users module)
  // ============================================

  Future<List<UserTripHistoryModel>> getUserTripHistory(String userId) =>
      users.getUserTripHistory(userId);

  Future<void> addUserTripToHistory({
    required String userId,
    required String busId,
    String? routeId,
  }) => users.addUserTripToHistory(
    userId: userId,
    busId: busId,
    routeId: routeId,
  );

  // ============================================
  // STUDENT APPLICATION QUERIES (delegated to users module)
  // ============================================

  Future<void> createStudentApplication({
    required String userId,
    required String userName,
    required String schoolName,
    required String idCardUrl,
  }) => users.createStudentApplication(
    userId: userId,
    userName: userName,
    schoolName: schoolName,
    idCardUrl: idCardUrl,
  );

  Future<StudentApplicationModel?> getUserApplication(String userId) =>
      users.getUserApplication(userId);

  Future<List<StudentApplicationModel>> getPendingApplications() =>
      users.getPendingApplications();

  Future<void> updateApplicationStatus(String appId, String status) =>
      users.updateApplicationStatus(appId, status);

  // ============================================
  // CONDUCTOR REPORTS (delegated to admin module)
  // ============================================

  Future<void> submitConductorReport(ConductorReportModel report) =>
      admin.submitConductorReport(report);

  Future<List<ConductorReportModel>> getConductorReports({
    required String userId,
    required String type,
  }) => admin.getConductorReports(userId: userId, type: type);

  Future<List<ConductorReportModel>> getAllConductorReports(String type) =>
      admin.getAllConductorReports(type);
}
