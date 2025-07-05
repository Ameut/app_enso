import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PageMeteo extends StatefulWidget {
  const PageMeteo({Key? key}) : super(key: key);

  @override
  State<PageMeteo> createState() => _PageMeteoState();
}

class _PageMeteoState extends State<PageMeteo> {
  Map<String, dynamic>? meteo;
  bool isLoading = true;
  String alert = "";
  FlutterLocalNotificationsPlugin? notificationsPlugin;

  @override
  void initState() {
    super.initState();
    notificationsPlugin = FlutterLocalNotificationsPlugin();
    _initNotifications();
    fetchMeteo();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await notificationsPlugin?.initialize(initSettings);
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'meteo_alerts',
      'Alertes météo',
      channelDescription: 'Alertes pluie/canicule',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await notificationsPlugin?.show(0, title, body, platformDetails);
  }

  Future<void> fetchMeteo() async {
    double lat = 43.4332; // Change ici pour ta ville
    double lon = 6.7370;

    final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&hourly=precipitation,temperature_2m&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&forecast_days=1');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        meteo = data['current_weather'];
        isLoading = false;
      });

      double pluie = data['current_weather']['precipitation'] ?? 0.0;
      double temp = data['current_weather']['temperature'] ?? 0.0;

      String alerte = '';
      if (pluie > 0.1) {
        alerte = "Alerte pluie 🌧️ : Prévoyez un parapluie !";
        showNotification("Alerte pluie", alerte);
      } else if (temp >= 35) {
        alerte = "Alerte canicule ☀️ : Pense à boire de l'eau !";
        showNotification("Alerte canicule", alerte);
      }
      setState(() => alert = alerte);
    } else {
      setState(() {
        isLoading = false;
        alert = "Erreur chargement météo";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Météo locale",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[900])),
                  SizedBox(height: 20),
                  if (meteo != null) ...[
                    Icon(Icons.cloud, color: Colors.blue, size: 80),
                    SizedBox(height: 20),
                    Text("Température : ${meteo!['temperature']}°C",
                        style: TextStyle(fontSize: 22)),
                    SizedBox(height: 10),
                    Text("Vent : ${meteo!['windspeed']} km/h",
                        style: TextStyle(fontSize: 20)),
                    SizedBox(height: 10),
                    Text("Précipitations : ${meteo!['precipitation'] ?? 0} mm",
                        style: TextStyle(fontSize: 20)),
                  ],
                  SizedBox(height: 24),
                  if (alert.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: alert.contains("canicule")
                              ? Colors.orange[200]
                              : Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.grey[200]!, blurRadius: 6)
                          ]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            alert.contains("canicule")
                                ? Icons.wb_sunny
                                : Icons.umbrella,
                            color: alert.contains("canicule")
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                          SizedBox(width: 10),
                          Flexible(
                              child: Text(alert,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text("Rafraîchir"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[900],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                    onPressed: fetchMeteo,
                  ),
                ],
              ),
            ),
    );
  }
}
