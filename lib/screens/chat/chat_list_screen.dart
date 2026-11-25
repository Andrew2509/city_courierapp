import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/screens/chat/chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int? knownUserId;

  const ChatListScreen({super.key, this.knownUserId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  static const Color _primaryOrange = Color(0xFFEC5B13);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<ChatProvider>();
      if (widget.knownUserId != null) {
        await provider.bindAuthenticatedUser(widget.knownUserId!);
      }
      await provider.loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Pesan Pengiriman',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: context.read<ChatProvider>().realtimeConnectedListenable,
            builder: (_, connected, _) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: connected
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFEDD5),
                side: BorderSide.none,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: connected ? const Color(0xFF16A34A) : _primaryOrange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      connected ? 'Realtime' : 'Sinkronisasi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: connected ? const Color(0xFF166534) : const Color(0xFF9A3412),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          final conversations = provider.conversations;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: _primaryOrange,
                  onRefresh: () => provider.loadConversations(),
                  child: _buildBody(context, provider, conversations, isDark),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ChatProvider provider,
    List<ConversationModel> conversations,
    bool isDark,
  ) {
    if (provider.loadingConversations && conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primaryOrange));
    }

    if (provider.conversationsError != null && conversations.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  provider.conversationsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => provider.loadConversations(),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange),
                  child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (conversations.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _primaryOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    size: 34,
                    color: _primaryOrange,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum Ada Percakapan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Percakapan dengan kurir atau customer akan muncul otomatis dari pesanan pengiriman Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 76,
        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
      ),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return _ConversationTile(
          conversation: conv,
          isDark: isDark,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  conversation: conv,
                  knownUserId: widget.knownUserId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final roleLabel = conversation.counterparty.role == 'courier' ? 'Kurir' : 'Customer';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFEC5B13).withValues(alpha: 0.14),
              child: Text(
                conversation.displayTitle.isNotEmpty
                    ? conversation.displayTitle[0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                  color: Color(0xFFEC5B13),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conversation.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$roleLabel • #${conversation.orderNumber ?? conversation.orderId}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessagePreview ?? 'Mulai percakapan pengiriman...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                      color: unread > 0
                          ? (isDark ? Colors.white70 : const Color(0xFF1E293B))
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(conversation.lastMessageAt ?? conversation.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: unread > 0 ? const Color(0xFFEC5B13) : const Color(0xFF94A3B8),
                    fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC5B13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (!conversation.isActive)
                  const Icon(Icons.lock_outline, size: 15, color: Color(0xFF94A3B8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    if (sameDay) {
      return DateFormat('HH:mm').format(dt);
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == dt.year && yesterday.month == dt.month && yesterday.day == dt.day) {
      return 'Kemarin';
    }
    return DateFormat('dd/MM').format(dt);
  }
}
