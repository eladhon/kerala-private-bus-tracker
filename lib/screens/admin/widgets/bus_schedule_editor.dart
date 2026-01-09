import 'package:flutter/material.dart';
import '../../../models/bus_schedule_model.dart';
import '../../../models/route_model.dart';

class BusScheduleEditor extends StatefulWidget {
  final List<RouteModel> routes;
  final List<BusScheduleModel> initialSchedule;
  final ValueChanged<List<BusScheduleModel>> onScheduleChanged;

  const BusScheduleEditor({
    super.key,
    required this.routes,
    required this.initialSchedule,
    required this.onScheduleChanged,
  });

  @override
  State<BusScheduleEditor> createState() => _BusScheduleEditorState();
}

class _BusScheduleEditorState extends State<BusScheduleEditor> {
  late List<BusScheduleModel> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = List.from(widget.initialSchedule);
  }

  void _addScheduleItem() async {
    String? selectedRouteId = widget.routes.firstOrNull?.id;
    final timeController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Trip'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRouteId,
                  decoration: const InputDecoration(labelText: 'Route'),
                  items: widget.routes
                      .map(
                        (r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedRouteId = v),
                ),
                TextField(
                  controller: timeController,
                  decoration: InputDecoration(
                    labelText: 'Departure Time',
                    hintText: 'HH:MM (24h)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final now = TimeOfDay.now();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: now,
                        );
                        if (picked != null && context.mounted) {
                          timeController.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedRouteId != null &&
                      timeController.text.isNotEmpty) {
                    Navigator.pop(context, {
                      'routeId': selectedRouteId,
                      'time': timeController.text,
                    });
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _schedule.add(
            BusScheduleModel(
              routeId: result['routeId'],
              departureTime: result['time'],
            ),
          );
          widget.onScheduleChanged(_schedule);
        });
      }
    });
  }

  void _removeScheduleItem(int index) {
    setState(() {
      _schedule.removeAt(index);
      widget.onScheduleChanged(_schedule);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: _addScheduleItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Trip'),
            ),
          ],
        ),
        if (_schedule.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'No trips scheduled.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ..._schedule.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final routeName = widget.routes
              .firstWhere(
                (r) => r.id == item.routeId,
                orElse: () => RouteModel(
                  id: '',
                  name: 'Unknown Route',
                  busStops: [],
                  startLocation: '',
                  endLocation: '',
                ),
              )
              .name;

          return ListTile(
            dense: true,
            title: Text(routeName),
            subtitle: Text('Departs: ${item.departureTime}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeScheduleItem(index),
            ),
          );
        }),
      ],
    );
  }
}
