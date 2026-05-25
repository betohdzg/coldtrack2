import 'package:flutter/material.dart';
import 'dart:async';

class AppAlert {
  final String id;
  final String refrigeradorId;   // ahora opcional, pero lo dejamos
  final String title;
  final String subtitle;
  final String priority;
  final IconData icon;
  final Color color;
  bool isRead;
  final DateTime timestamp;
  final String tipoFalla;

  AppAlert({
    required this.id,
    this.refrigeradorId = 'ref01',   // ← valor por defecto
    required this.title,
    required this.subtitle,
    required this.priority,
    required this.icon,
    required this.color,
    this.isRead = false,
    required this.timestamp,
    this.tipoFalla = '',
  });

  String get timeAgo {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  // Fábrica: ahora refId es opcional (por defecto 'ref01')
  factory AppAlert.fromFirebase(Map<String, dynamic> data, String id, [String refId = 'ref01']) {
    String tipoFalla = data['tipo_falla'] ?? 'desconocida';

    DateTime timestamp;
    try {
      timestamp = DateTime.parse(data['timestamp']);
    } catch (e) {
      timestamp = DateTime.now();
    }

    IconData icono;
    Color color;
    switch (tipoFalla) {
      case 'sobrecalentamiento':
        icono = Icons.thermostat;
        color = Colors.red;
        break;
      case 'vibracion':
        icono = Icons.vibration;
        color = Colors.orange;
        break;
      case 'consumo':
        icono = Icons.electric_bolt;
        color = Colors.amber;
        break;
      case 'puerta_abierta':
        icono = Icons.door_back_door;
        color = Colors.blue;
        break;
      case 'humedad':
        icono = Icons.water_drop;
        color = Colors.cyan;
        break;
      default:
        icono = Icons.warning;
        color = Colors.grey;
    }

    return AppAlert(
      id: id,
      refrigeradorId: refId,
      title: data['titulo'] ?? '⚠️ Alerta',
      subtitle: data['mensaje'] ?? 'Se detectó una falla',
      priority: 'Alta',
      icon: icono,
      color: color,
      isRead: data['leida'] ?? false,
      timestamp: timestamp,
      tipoFalla: tipoFalla,
    );
  }
}