import 'package:flutter/foundation.dart';
import '../models/bus_model.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  // List of buses with active reminders
  final ValueNotifier<List<BusModel>> activeReminders = ValueNotifier([]);

  void addReminder(BusModel bus) {
    if (isReminderSet(bus.id)) return;

    final currentList = List<BusModel>.from(activeReminders.value);
    currentList.add(bus);
    activeReminders.value = currentList;

    debugPrint("Reminder added for bus: ${bus.name}");
  }

  void removeReminder(String busId) {
    final currentList = List<BusModel>.from(activeReminders.value);
    currentList.removeWhere((b) => b.id == busId);
    activeReminders.value = currentList;

    // Also cancel any pending notification ID if we were using scheduled ones
    // NotificationService().cancel(busId.hashCode);

    debugPrint("Reminder removed for bus ID: $busId");
  }

  bool isReminderSet(String busId) {
    return activeReminders.value.any((b) => b.id == busId);
  }
}
