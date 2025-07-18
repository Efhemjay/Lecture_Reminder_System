import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/model/lecture_model.dart';
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

      // Fix: handle AM/PM formats gracefully
      final timeString = widget.lectureToEdit!.time.trim();
      final is12HourFormat = timeString.contains(RegExp(r'[AaPp][Mm]'));

      try {
        TimeOfDay parsedTime;

        if (is12HourFormat) {
          final dateTime = DateFormat.jm().parse(timeString); // e.g. "6:30 PM"
          parsedTime = TimeOfDay.fromDateTime(dateTime);
        } else {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            parsedTime = TimeOfDay(hour: hour, minute: minute);
          } else {
            throw FormatException("Invalid time format");
          }
        }

        _selectedTime = parsedTime;
      } catch (e) {
        debugPrint('⚠️ Failed to parse lecture time: $e');
        _selectedTime = TimeOfDay.now(); // fallback
      }

      _locationController.text = widget.lectureToEdit!.location;
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Lecture Title',
                  prefixIcon: const Icon(Icons.book),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the lecture title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: InputDecoration(
                  labelText: 'Day of the Week',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _weekdays.map((day) {
                  return DropdownMenuItem(value: day, child: Text(day));
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
              const SizedBox(height: 16),
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
                  decoration: InputDecoration(
                    labelText: 'Time',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _selectedTime == null
                        ? 'Select time'
                        : _selectedTime!.format(context),
                    style: TextStyle(
                      color: _selectedTime == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      _selectedTime != null) {
                    final lecture = Lecture(
                      title: _titleController.text,
                      day: _selectedDay!,
                      time: _selectedTime!.format(context),
                      location: _locationController.text,
                    );
                    Navigator.pop(context, lecture);
                  } else if (_selectedTime == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a time')),
                    );
                  }
                },
                child: Text(
                  widget.lectureToEdit == null
                      ? 'Save Lecture'
                      : 'Update Lecture',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
