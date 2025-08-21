import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/model/lecture_model.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/presentation/screens/alarm_settings_screen/alarm_settings_screen.dart';
import 'package:intl/intl.dart';

class AddLecturePage extends StatefulWidget {
  final Lecture? lectureToEdit;
  final int? index;

  const AddLecturePage({super.key, this.lectureToEdit, this.index});

  @override
  _AddLecturePageState createState() => _AddLecturePageState();
}

class _AddLecturePageState extends State<AddLecturePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String? _selectedDay;
  TimeOfDay? _selectedTime;
  final _locationController = TextEditingController();
  AlarmSettings _alarmSettings = const AlarmSettings();

  final List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.lectureToEdit != null) {
      _titleController.text = widget.lectureToEdit!.title;
      _selectedDay = widget.lectureToEdit!.day;
      _locationController.text = widget.lectureToEdit!.location;

      try {
        final timeString = widget.lectureToEdit!.time.trim();
        final is12HourFormat = timeString.contains(
          RegExp(r'[AaPp][Mm]', caseSensitive: false),
        );

        TimeOfDay parsedTime;

        if (is12HourFormat) {
          final normalizedTimeString = timeString
              .replaceAll(RegExp(r'[\u202F\u00A0\s]+'), ' ')
              .replaceAllMapped(
                RegExp(r'(am|pm)', caseSensitive: false),
                (Match match) => match.group(0)!.toUpperCase(),
              )
              .trim();
          final dateTime = DateFormat(
            'h:mm a',
          ).parseStrict(normalizedTimeString);
          parsedTime = TimeOfDay.fromDateTime(dateTime);
        } else {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            parsedTime = TimeOfDay(hour: hour, minute: minute);
          } else {
            throw FormatException("Invalid time format: $timeString");
          }
        }

        _selectedTime = parsedTime;
      } catch (e) {
        debugPrint('⚠️ Failed to parse lecture time: $e');
        _selectedTime = TimeOfDay.now(); // Fallback
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lectureToEdit == null ? 'Add Lecture' : 'Edit Lecture',
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF6366F1).withOpacity(0.05), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 32,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.lectureToEdit == null
                              ? 'Add New Lecture'
                              : 'Edit Lecture',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fill in the details below',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Lecture Title',
                            prefixIcon: Icon(Icons.school_rounded),
                            hintText: 'Enter lecture title',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the lecture title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedDay,
                          decoration: const InputDecoration(
                            labelText: 'Day of Week',
                            prefixIcon: Icon(Icons.calendar_today_rounded),
                            hintText: 'Select day',
                          ),
                          items: _weekdays.map((day) {
                            return DropdownMenuItem(
                              value: day,
                              child: Text(day),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDay = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a day';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() {
                                _selectedTime = time;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Time',
                              prefixIcon: Icon(Icons.access_time_rounded),
                              hintText: 'Select time',
                            ),
                            child: Text(
                              _selectedTime == null
                                  ? 'Select time'
                                  : _selectedTime!.format(context),
                              style: TextStyle(
                                color: _selectedTime == null
                                    ? Colors.grey.shade500
                                    : const Color(0xFF1E293B),
                                fontWeight: _selectedTime == null
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location',
                            prefixIcon: Icon(Icons.location_on_rounded),
                            hintText: 'Enter location',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the location';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Alarm Settings Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.alarm_rounded,
                                color: Color(0xFF6366F1),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Alarm Settings',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlarmSettingsScreen(
                                    initialSettings: _alarmSettings,
                                    onSettingsChanged: (settings) {
                                      setState(() {
                                        _alarmSettings = settings;
                                      });
                                    },
                                  ),
                                ),
                              );
                              // If settings were changed, update the local state
                              if (result != null && result is AlarmSettings) {
                                setState(() {
                                  _alarmSettings = result;
                                });
                              }
                            },
                            icon: const Icon(Icons.settings_rounded),
                            label: const Text('Configure Alarm Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate() &&
                            _selectedTime != null) {
                          final alarm = Alarm(
                            title: _titleController.text,
                            day: _selectedDay!,
                            time: DateFormat('h:mm a').format(
                              DateTime(
                                2025,
                                1,
                                1,
                                _selectedTime!.hour,
                                _selectedTime!.minute,
                              ),
                            ),
                            location: _locationController.text,
                            settings: _alarmSettings,
                          );
                          Navigator.pop(context, alarm);
                        } else if (_selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Please select a time'),
                              backgroundColor: Colors.red.shade400,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        widget.lectureToEdit == null
                            ? 'Save Lecture'
                            : 'Update Lecture',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
