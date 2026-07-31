import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ⚠️ DOIT être une fonction top-level (hors de la classe)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Notification reçue en arrière-plan: ${message.messageId}");
}

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // 👈 Enregistrer le background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Demande des permissions de notification
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permission notification accordée');
    }

    // 2. Écouter les notifications quand l'application est OUVERTE (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Notification reçue en premier plan: ${message.notification?.title}');
      
      final context = navigatorKey.currentContext;
      if (context != null && message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification?.title}\n${message.notification?.body}'),
            backgroundColor: const Color(0xFFFF5722),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VOIR',
              textColor: Colors.white,
              onPressed: () => _handleNotificationClick(message, navigatorKey),
            ),
          ),
        );
      }
    });

    // 3. Écouter les clics sur notification (application en arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message, navigatorKey);
    });

    // 4. Écouter le clic si l'application était COMPLÈTEMENT fermée
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage, navigatorKey);
    }
  }

  static Future<String?> getToken() async {
    try {
      String? token = await _fcm.getToken();
      debugPrint("FCM Token Chauffeur: $token");
      return token;
    } catch (e) {
      debugPrint("Erreur lors de la récupération du token FCM: $e");
      return null;
    }
  }

  static void _handleNotificationClick(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    final status = message.data['status'];

    if (status == 'approved') {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    } else if (status == 'rejected') {
      navigatorKey.currentState?.pushNamed('/driver_register');
    }
  }
}