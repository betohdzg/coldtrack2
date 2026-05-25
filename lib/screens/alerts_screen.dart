import 'dart:async'; // ✅ IMPORTANTE: Para Timer
import 'package:carnitrack2/models/alert.dart';
import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  final List<AppAlert> alerts;
  final VoidCallback? onAlertsUpdated;
  const AlertsScreen({super.key, required this.alerts, this.onAlertsUpdated});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {}); // Reconstruir para actualizar los tiempos
      }
    });
  }

  void _startAutoDeleteTimer(AppAlert alert) {
    Future.delayed(const Duration(minutes: 3), () {
      if (widget.alerts.contains(alert) && alert.isRead) {
        setState(() {
          widget.alerts.remove(alert);
        });
        if (widget.onAlertsUpdated != null) {
          widget.onAlertsUpdated!();
        }
        print('🗑️ Alerta eliminada automáticamente: ${alert.title}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: widget.alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay alertas por el momento'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.alerts.length,
              itemBuilder: (context, index) {
                final alert = widget.alerts[index];
                final isRead = alert.isRead;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isRead ? Colors.grey[100] : Colors.white,
                  elevation: isRead ? 1 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isRead
                        ? BorderSide.none
                        : const BorderSide(
                            color: Color(0xFF00ACC1),
                            width: 1,
                          ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: alert.color.withOpacity(0.15),
                      radius: 20,
                      child: Icon(
                        alert.icon,
                        color: alert.color,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isRead ? Colors.grey[700] : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      alert.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isRead ? Colors.grey[600] : Colors.black87,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            alert.timeAgo, // ✅ Usando el getter
                            style: TextStyle(
                              fontSize: 11,
                              color: isRead ? Colors.grey : Colors.grey[600],
                            ),
                            textAlign: TextAlign.right,
                          ),
                          if (!isRead)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NUEVA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    onTap: () {
                      if (!alert.isRead) {
                        setState(() {
                          alert.isRead = true;
                        });
                        _startAutoDeleteTimer(alert);
                        if (widget.onAlertsUpdated != null) {
                          widget.onAlertsUpdated!();
                        }
                      }

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Icon(alert.icon, color: alert.color, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alert.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.subtitle,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: alert.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      size: 18,
                                      color: alert.color,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hora: ${alert.timeAgo}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: alert.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF00ACC1),
                              ),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}