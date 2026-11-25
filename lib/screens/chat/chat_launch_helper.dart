import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/screens/chat/chat_detail_screen.dart';
import 'package:city_courierapp/screens/chat/chat_list_screen.dart';

class ChatLaunchHelper {
  ChatLaunchHelper._();

  static String? extractOrderIdentifier(Map<String, dynamic>? order) {
    if (order == null) return null;
    final nested = order['shipment'] is Map ? order['shipment'] as Map : null;
    for (final candidate in [
      order['order_id'],
      nested?['order_id'],
      order['order_number'],
      order['tracking_number'],
      order['shipment_number'],
      nested?['tracking_number'],
      nested?['shipment_number'],
      order['id'],
    ]) {
      final text = candidate?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null' && text != '0') {
        return text;
      }
    }
    return null;
  }

  static Future<void> openInbox(
    BuildContext context, {
    int? knownUserId,
  }) async {
    if (knownUserId != null) {
      await context.read<ChatProvider>().bindAuthenticatedUser(knownUserId);
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatListScreen(knownUserId: knownUserId),
      ),
    );
  }

  static Future<void> openOrderChat(
    BuildContext context, {
    required String? orderIdentifier,
    int? knownUserId,
  }) async {
    final cleanId = orderIdentifier?.trim();
    if (cleanId == null || cleanId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ID pesanan tidak ditemukan untuk membuka ruang chat.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final chatProvider = context.read<ChatProvider>();
    if (knownUserId != null) {
      await chatProvider.bindAuthenticatedUser(knownUserId);
    }

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Color(0xFFEC5B13)),
          ),
        ),
      ),
    );

    try {
      final conv = await chatProvider.openOrderConversation(cleanId);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChatDetailScreen(conversation: conv, knownUserId: knownUserId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Compact circular/rounded button to open in-app internal realtime chat for an order.
class ChatOrderIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final double iconSize;
  final bool isCircular;

  const ChatOrderIconButton({
    super.key,
    required this.onTap,
    this.tooltip = 'Chat Dalam Aplikasi',
    this.size = 36,
    this.iconSize = 17,
    this.isCircular = true,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEC5B13);
    const bg = Color(0xFFFFF4EC);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isCircular ? size / 2 : 12),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular ? null : BorderRadius.circular(12),
              border: Border.all(color: accent, width: 1.2),
            ),
            child: Center(
              child: Icon(
                Icons.chat_bubble_rounded,
                size: iconSize,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inbox icon button with live unread counter badge backed by ChatProvider.
class ChatInboxIconButton extends StatelessWidget {
  final int? knownUserId;
  final Color iconColor;
  final Color backgroundColor;

  const ChatInboxIconButton({
    super.key,
    this.knownUserId,
    this.iconColor = const Color(0xFF0F172A),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // Graceful degradation: HomeHeader may render in contexts without the
    // app-wide ChatProvider (isolated widget tests, secondary routes).
    ChatProvider? chatProvider;
    try {
      chatProvider = Provider.of<ChatProvider>(context, listen: false);
    } on ProviderNotFoundException {
      chatProvider = null;
    }

    if (chatProvider == null) {
      return _inboxButton(
        unreadCount: 0,
        onTap: () =>
            ChatLaunchHelper.openInbox(context, knownUserId: knownUserId),
      );
    }

    return Selector<ChatProvider, int>(
      selector: (_, p) => p.totalUnreadCount,
      builder: (context, unreadCount, _) {
        return _inboxButton(
          unreadCount: unreadCount,
          onTap: () =>
              ChatLaunchHelper.openInbox(context, knownUserId: knownUserId),
        );
      },
    );
  }

  Widget _inboxButton({required int unreadCount, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: iconColor,
                size: 20,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
