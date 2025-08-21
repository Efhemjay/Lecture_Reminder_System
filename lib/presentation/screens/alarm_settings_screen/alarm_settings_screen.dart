import 'package:flutter/material.dart';
import 'package:lecture_reminder_system/model/alarm_model.dart';
import 'package:lecture_reminder_system/core/services/alarm_service.dart';

class AlarmSettingsScreen extends StatefulWidget {
  final AlarmSettings initialSettings;
  final Function(AlarmSettings) onSettingsChanged;

  const AlarmSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  late AlarmSettings _settings;
  final AlarmService _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              widget.onSettingsChanged(_settings);
              Navigator.pop(context, _settings);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ringtone Section
          _buildSection(
            title: 'Ringtone',
            icon: Icons.music_note,
            children: [_buildRingtoneSelector()],
          ),

          const SizedBox(height: 24),

          // Snooze Settings Section
          _buildSection(
            title: 'Snooze Settings',
            icon: Icons.snooze,
            children: [
              _buildSnoozeIntervalSelector(),
              const SizedBox(height: 16),
              _buildMaxSnoozeSelector(),
            ],
          ),

          const SizedBox(height: 24),

          // Vibration & Volume Section
          _buildSection(
            title: 'Vibration & Volume',
            icon: Icons.vibration,
            children: [
              _buildVibrationToggle(),
              const SizedBox(height: 16),
              _buildVolumeSlider(),
            ],
          ),

          const SizedBox(height: 24),

          // Auto-stop Section
          _buildSection(
            title: 'Auto-stop',
            icon: Icons.timer,
            children: [_buildAutoStopToggle()],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF6366F1), size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingtoneSelector() {
    final ringtones = AlarmService.getAvailableRingtones();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Ringtone',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ...ringtones.entries.map((entry) {
          final isSelected = _settings.ringtonePath == entry.key;
          return ListTile(
            leading: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
            ),
            title: Text(entry.value),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _alarmService.previewRingtone(entry.key),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              setState(() {
                _settings = _settings.copyWith(ringtonePath: entry.key);
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSnoozeIntervalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Snooze Interval',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<SnoozeInterval>(
          value: _settings.snoozeInterval,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: SnoozeInterval.values.map((interval) {
            return DropdownMenuItem(
              value: interval,
              child: Text('${interval.minutes} minutes'),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(snoozeInterval: value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildMaxSnoozeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Maximum Snooze Count',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _settings.maxSnoozeCount,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: List.generate(5, (index) => index + 1).map((count) {
            return DropdownMenuItem(value: count, child: Text('$count times'));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _settings = _settings.copyWith(maxSnoozeCount: value);
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildVibrationToggle() {
    return SwitchListTile(
      title: const Text('Vibration'),
      subtitle: const Text('Vibrate when alarm rings'),
      value: _settings.vibrate,
      onChanged: (value) {
        setState(() {
          _settings = _settings.copyWith(vibrate: value);
        });
      },
    );
  }

  Widget _buildVolumeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Volume',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text('${_settings.volume}%'),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _settings.volume.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          label: '${_settings.volume}%',
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(volume: value.round());
            });
          },
        ),
      ],
    );
  }

  Widget _buildAutoStopToggle() {
    return SwitchListTile(
      title: const Text('Auto-stop'),
      subtitle: const Text('Automatically stop alarm after 5 minutes'),
      value: _settings.autoStop,
      onChanged: (value) {
        setState(() {
          _settings = _settings.copyWith(autoStop: value);
        });
      },
    );
  }
}
