import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Configuración para Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  // Mostrar notificación local (VERSIÓN CORREGIDA - SIN SONIDO PERSONALIZADO)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // 🔧 CORREGIDO: Eliminé el sonido personalizado que causaba el error
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'coldtrack_channel',
          'Alertas ColdTrack',
          channelDescription: 'Notificaciones de alertas del refrigerador',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true, // ✅ Usa sonido por defecto del sistema
          enableVibration: true, // ✅ Vibración activada
          styleInformation: BigTextStyleInformation(''),
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();


    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Escuchar mensajes FCM cuando la app está en primer plano
  static Future<void> setupFirebaseListeners({
    required Function(Map<String, dynamic>) onMessage,
    required Function(RemoteMessage) onMessageOpenedApp,
  }) async {
    // Notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;

      if (notification != null) {
        showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title ?? 'Alerta',
          body: notification.body ?? '',
          payload: data['alertId'],
        );
      }
      onMessage(data);
    });

    // Cuando se abre la app desde la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      onMessageOpenedApp(message);
    });

    // Si la app se abre desde una notificación cuando estaba cerrada
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      onMessageOpenedApp(initialMessage);
    }
  }

  // Solicitar permisos (Android 13+ e iOS)
  static Future<void> requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // Obtener token FCM (útil para depuración)
  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}
