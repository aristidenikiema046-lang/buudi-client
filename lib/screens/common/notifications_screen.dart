import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _orange = Color(0xFFFF5722);

  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token') ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await NotificationService.fetchNotifications(_token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _notifications = result['notifications'] as List<AppNotification>;
        _error = null;
      } else {
        _error = result['message'] as String?;
      }
    });
  }

  Future<void> _markAllAsRead() async {
    final now = DateTime.now();
    setState(() {
      _notifications = _notifications
          .map((n) => n.isUnread
              ? AppNotification(
                  id: n.id,
                  userId: n.userId,
                  type: n.type,
                  title: n.title,
                  body: n.body,
                  data: n.data,
                  readAt: now,
                  createdAt: n.createdAt,
                )
              : n)
          .toList();
    });
    final result = await NotificationService.markAllAsRead(_token);
    if (result['success'] != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Impossible de tout marquer comme lu.")),
      );
      _load();
    }
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (notification.isUnread) {
      final now = DateTime.now();
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = AppNotification(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            body: notification.body,
            data: notification.data,
            readAt: now,
            createdAt: notification.createdAt,
          );
        }
      });
      NotificationService.markAsRead(notification.id, _token);
    }

    if (notification.type == 'new_message') {
      final rideId = notification.data?['ride_id']?.toString();
      if (rideId != null && rideId.isNotEmpty && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(rideId: rideId)));
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ride_status_changed':
        return Icons.local_taxi_rounded;
      case 'new_message':
        return Icons.chat_bubble_outline_rounded;
      case 'wallet_transaction':
        return Icons.account_balance_wallet_outlined;
      case 'account_status_changed':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _notifications.any((n) => n.isUnread) ? _markAllAsRead : null,
            child: Text(
              "Tout marquer comme lu",
              style: TextStyle(
                color: _notifications.any((n) => n.isUnread) ? _orange : Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null && _notifications.isEmpty) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Center(child: Text("Aucune notification.", style: TextStyle(color: Colors.grey[600]))),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _orange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        itemBuilder: (context, index) => _buildTile(_notifications[index]),
      ),
    );
  }

  Widget _buildTile(AppNotification notification) {
    final isUnread = notification.isUnread;
    return InkWell(
      onTap: () => _handleTap(notification),
      child: Container(
        color: isUnread ? const Color(0xFFFFF0EE) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFF1F3F5), shape: BoxShape.circle),
              child: Icon(_iconForType(notification.type), color: Colors.black54, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(color: _orange, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatShortDate(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
