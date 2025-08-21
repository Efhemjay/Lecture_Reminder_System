import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/core/services/overlay_alarm_service.dart';

class OverlayPermissionRequest extends StatefulWidget {
  final VoidCallback? onPermissionGranted;

  const OverlayPermissionRequest({super.key, this.onPermissionGranted});

  @override
  State<OverlayPermissionRequest> createState() =>
      _OverlayPermissionRequestState();
}

class _OverlayPermissionRequestState extends State<OverlayPermissionRequest> {
  final OverlayAlarmService _overlayAlarmService = OverlayAlarmService();
  bool _isChecking = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Permission Required'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To show alarm overlays over other apps, we need the "Display over other apps" permission.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'This allows the alarm to appear even when you\'re using other apps, just like a system alarm.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isChecking ? null : _requestPermission,
          child: _isChecking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Grant Permission'),
        ),
      ],
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final granted = await _overlayAlarmService.requestOverlayPermission();

      if (mounted) {
        Navigator.of(context).pop();

        if (granted) {
          widget.onPermissionGranted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Overlay permission granted!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Permission denied. Alarms will work normally but won\'t appear over other apps.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }
}
