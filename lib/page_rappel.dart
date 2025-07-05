import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;

class Reminder {
  String id;
  String title;
  DateTime dateTime;
  bool isActive;
  String? description;

  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.isActive = true,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'isActive': isActive,
        'description': description,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        title: json['title'],
        dateTime: DateTime.parse(json['dateTime']),
        isActive: json['isActive'] ?? true,
        description: json['description'],
      );
}

class PageRappel extends StatefulWidget {
  @override
  State<PageRappel> createState() => _PageRappelState();
}

class _PageRappelState extends State<PageRappel> {
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late AudioPlayer _audioPlayer;
  Timer? _reminderTimer;
  List<Reminder> _reminders = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(minutes: 1));

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initializeNotifications();
    _audioPlayer = AudioPlayer();
    _loadReminders();
    _startReminderCheck();
  }

  void _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _startReminderCheck() {
    _reminderTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final now = DateTime.now();
    for (var reminder in _reminders) {
      if (reminder.isActive &&
          reminder.dateTime.isBefore(now.add(const Duration(seconds: 15))) &&
          reminder.dateTime
              .isAfter(now.subtract(const Duration(seconds: 15)))) {
        _triggerReminder(reminder);
      }
    }
  }

  void _triggerReminder(Reminder reminder) async {
    await _playNotificationSound();
    _showReminderDialog(reminder);
    setState(() {
      reminder.isActive = false;
    });
    _saveReminders();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification_beep.mp3'));
    } catch (_) {}
  }

  // PLANIFICATION DE LA NOTIFICATION SYSTÈME
  Future<void> _scheduleSystemNotification(Reminder reminder) async {
    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Rappels',
      channelDescription: 'Notifications pour les rappels programmés',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification_beep'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
    );
    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_beep.aiff',
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    String notificationBody = reminder.title;
    if (reminder.description != null && reminder.description!.isNotEmpty) {
      notificationBody += '\n${reminder.description}';
    }
    notificationBody += '\n🕐 ${_formatDateTime(reminder.dateTime)}';

    final scheduledDate = tz.TZDateTime.from(reminder.dateTime, tz.local);

    // Bloc Android : androidScheduleMode OBLIGATOIRE, PAS sur web/iOS/desktop
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _notificationsPlugin.zonedSchedule(
        reminder.id.hashCode,
        '🔔 Rappel Important',
        notificationBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    } else {
      await _notificationsPlugin.zonedSchedule(
        reminder.id.hashCode,
        '🔔 Rappel Important',
        notificationBody,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Optionnel: Action sur tap
  }

  void _showReminderDialog(Reminder reminder) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red.shade300, width: 2),
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active,
                  color: Colors.red, size: 30),
              const SizedBox(width: 10),
              Text(
                '🔔 RAPPEL',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reminder.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              if (reminder.description != null &&
                  reminder.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(reminder.description!,
                    style: const TextStyle(fontSize: 16)),
              ],
              const SizedBox(height: 12),
              Text("Pour : ${_formatDateTime(reminder.dateTime)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.indigo)),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade100,
              ),
              onPressed: () {
                _audioPlayer.stop();
                Navigator.of(context).pop();
              },
              child: Text(
                'COMPRIS ✓',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> encodedReminders =
        _reminders.map((reminder) => jsonEncode(reminder.toJson())).toList();
    await prefs.setStringList('reminders', encodedReminders);
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encodedReminders = prefs.getStringList('reminders');
    if (encodedReminders != null) {
      setState(() {
        _reminders = encodedReminders.map((reminderStr) {
          final Map<String, dynamic> data = jsonDecode(reminderStr);
          return Reminder.fromJson(data);
        }).toList();
      });
    }
  }

  void _addReminder() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Titre du rappel obligatoire.")),
      );
      return;
    }
    if (_selectedDateTime
        .isBefore(DateTime.now().add(const Duration(seconds: 10)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("La date et l'heure doivent être dans le futur."),
          backgroundColor: Colors.red[300],
        ),
      );
      return;
    }

    Reminder newReminder = Reminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      dateTime: _selectedDateTime,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
    );
    setState(() {
      _reminders.add(newReminder);
    });
    _saveReminders();
    _scheduleSystemNotification(newReminder);
    _titleController.clear();
    _descriptionController.clear();
    _selectedDateTime = DateTime.now().add(const Duration(minutes: 1));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rappel ajouté avec succès !")),
    );
  }

  void _deleteReminder(String id) {
    setState(() {
      _reminders.removeWhere((reminder) => reminder.id == id);
    });
    _saveReminders();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Rappel supprimé.")),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _audioPlayer.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rappels'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajouter un rappel',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre du rappel',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Date et heure: ${_formatDateTime(_selectedDateTime)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateTime,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          final TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime:
                                TimeOfDay.fromDateTime(_selectedDateTime),
                            builder: (context, child) {
                              return MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            DateTime chosen = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                            if (chosen.isBefore(DateTime.now())) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Choisis une date/heure future uniquement !"),
                                  backgroundColor: Colors.red[300],
                                ),
                              );
                            } else {
                              setState(() {
                                _selectedDateTime = chosen;
                              });
                            }
                          }
                        }
                      },
                      child: const Text('Modifier'),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addReminder,
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Ajouter le rappel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _reminders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text('Aucun rappel programmé',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const Text(
                            "Ajoute un rappel avec le formulaire ci-dessus !",
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _reminders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                reminder.isActive ? Colors.green : Colors.grey,
                            child: Icon(
                                reminder.isActive
                                    ? Icons.alarm
                                    : Icons.alarm_off,
                                color: Colors.white),
                          ),
                          title: Text(reminder.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: reminder.isActive
                                      ? TextDecoration.none
                                      : TextDecoration.lineThrough)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDateTime(reminder.dateTime)),
                              if (reminder.description != null)
                                Text(reminder.description!,
                                    style: const TextStyle(
                                        fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteReminder(reminder.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
