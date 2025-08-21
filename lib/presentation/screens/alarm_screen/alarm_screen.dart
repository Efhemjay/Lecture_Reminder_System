import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/core/services/alarm_service.dart';
import 'package:intl/intl.dart';

class AlarmScreen extends StatefulWidget {
  final Alarm alarm;

  const AlarmScreen({super.key, required this.alarm});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  final AlarmService _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    // Start animations
    _pulseController.repeat(reverse: true);
    _slideController.forward();

    // Start the alarm
    _alarmService.startAlarm(widget.alarm);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top section with time and date
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Current time
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Text(
                                  DateFormat('HH:mm').format(DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Middle section with alarm info
                  Expanded(
                    flex: 3,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Alarm icon
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 3),
                              ),
                              child: const Icon(
                                Icons.alarm,
                                size: 50,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Alarm title
                            Text(
                              widget.alarm.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            // Alarm details
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(
                                    Icons.access_time,
                                    'Time',
                                    widget.alarm.time,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.location_on,
                                    'Location',
                                    widget.alarm.location,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Day',
                                    widget.alarm.day,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom section with controls
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Snooze button
                          if (widget.alarm.canSnooze)
                            _buildControlButton(
                              icon: Icons.snooze,
                              label:
                                  'Snooze\n${widget.alarm.settings.snoozeInterval.minutes}m',
                              color: Colors.orange,
                              onPressed: () async {
                                await _alarmService.snoozeAlarm();
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                            ),

                          // Stop button
                          _buildControlButton(
                            icon: Icons.stop,
                            label: 'Stop\nAlarm',
                            color: Colors.red,
                            onPressed: () async {
                              await _alarmService.stopAlarm();
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
