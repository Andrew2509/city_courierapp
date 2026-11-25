import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/models/chat/chat_models.dart';
import 'package:city_courierapp/providers/chat_provider.dart';
import 'package:city_courierapp/services/courier/courier_contact_helper.dart';
import 'package:city_courierapp/services/token_store.dart';

class ChatDetailScreen extends StatefulWidget {
  final ConversationModel conversation;
  final int? knownUserId;
  final String? authTokenOverride;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.knownUserId,
    this.authTokenOverride,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const Color _primaryOrange = Color(0xFFEC5B13);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  ChatProvider? _chatProvider;
  String? _authToken;
  int _lastRenderedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _authToken = widget.authTokenOverride;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadTokenAndEnter());
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = context.read<ChatProvider>();
  }

  Future<void> _loadTokenAndEnter() async {
    if (!mounted) return;
    if (_authToken == null) {
      unawaited(_loadTokenSilently());
    }

    final provider = context.read<ChatProvider>();
    await provider.enterConversation(
      widget.conversation.id,
      knownUserId: widget.knownUserId,
    );
    await provider.loadWhatsappStatus();
    _scrollToBottom(jump: true);
  }

  Future<void> _loadTokenSilently() async {
    try {
      final token = await TokenStore.read();
      if (mounted && token != null) {
        setState(() => _authToken = token);
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80) {
      unawaited(context.read<ChatProvider>().loadOlderMessages(widget.conversation.id));
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    final provider = _chatProvider;
    if (provider != null) {
      unawaited(provider.leaveConversation(widget.conversation.id));
    }
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    unawaited(context.read<ChatProvider>().notifyTyping(widget.conversation.id, false));

    await context.read<ChatProvider>().sendMessage(
          conversation: widget.conversation,
          body: text,
        );
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    await context.read<ChatProvider>().sendMessage(
          conversation: widget.conversation,
          body: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
          imagePath: picked.path,
        );
    _textController.clear();
    _scrollToBottom();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF4EC),
                  child: Icon(Icons.photo_library_rounded, color: _primaryOrange),
                ),
                title: const Text('Pilih Foto dari Galeri'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  unawaited(_pickAndSendImage(ImageSource.gallery));
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F7EE),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF16A34A)),
                ),
                title: const Text('Ambil Foto Kamera'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  unawaited(_pickAndSendImage(ImageSource.camera));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsappSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<ChatProvider>(
        builder: (ctx, provider, _) {
          final st = provider.whatsappStatus;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Integrasi WhatsApp Business Resmi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Jika diaktifkan, pesan pengiriman dapat diteruskan ke nomor WhatsApp Anda melalui akun resmi WhatsApp Business City Courier.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: const Color(0xFF16A34A),
                    title: const Text('Terima pesan via WhatsApp'),
                    subtitle: Text(
                      st?.phoneE164 != null
                          ? 'Nomor: ${st!.phoneE164}'
                          : 'Memerlukan nomor telepon terverifikasi',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: st?.isOptedIn ?? false,
                    onChanged: (next) async {
                      final ok = await provider.toggleWhatsappOptIn(
                        optIn: next,
                        conversationId: widget.conversation.id,
                      );
                      if (!ok && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Gagal mengubah status WhatsApp. Pastikan nomor terverifikasi.'),
                          ),
                        );
                      }
                    },
                  ),
                  if (st != null && st.whatsappCloudEnabled && !st.windowOpen)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Catatan Meta 24 Jam: Pesan luar jendela layanan 24 jam akan dikirim memakai template notifikasi resmi.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conv = widget.conversation;
    final counterpartyPhone = conv.counterparty.phone;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Consumer<ChatProvider>(
          builder: (_, provider, _) {
            final isTyping = provider.isCounterpartyTyping(conv.id);
            final subtitle = isTyping
                ? 'Sedang mengetik...'
                : 'Order #${conv.orderNumber ?? conv.orderId}';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conv.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isTyping ? FontWeight.w600 : FontWeight.w500,
                    color: isTyping ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          if (counterpartyPhone != null && counterpartyPhone.trim().isNotEmpty)
            IconButton(
              tooltip: 'Hubungi via Telepon/WA',
              onPressed: () => CourierContactHelper.callPhone(context, counterpartyPhone),
              icon: const Icon(Icons.phone_outlined, color: _primaryOrange),
            ),
          IconButton(
            tooltip: 'Pengaturan WhatsApp Bisnis',
            onPressed: _showWhatsappSettingsSheet,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _WhatsappBridgeBanner(
            conversation: conv,
            isDark: isDark,
            onOpenWhatsappDirect: (counterpartyPhone != null && counterpartyPhone.trim().isNotEmpty)
                ? () => CourierContactHelper.callPhone(context, counterpartyPhone)
                : null,
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, _) {
                final messages = provider.messagesFor(conv.id);
                final isLoading = provider.isLoadingMessages(conv.id);
                final hasMore = provider.hasMoreFor(conv.id);

                if (messages.length > _lastRenderedMessageCount) {
                  final nearBottom = !_scrollController.hasClients ||
                      _scrollController.position.pixels >=
                          _scrollController.position.maxScrollExtent - 160;
                  _lastRenderedMessageCount = messages.length;
                  if (nearBottom) {
                    _scrollToBottom();
                  }
                }

                if (isLoading && messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: _primaryOrange));
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 46,
                            color: _primaryOrange.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Mulai percakapan dengan ${conv.displayTitle}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: messages.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, idx) {
                    if (hasMore && idx == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : TextButton(
                                  onPressed: () => provider.loadOlderMessages(conv.id),
                                  child: const Text('Muat pesan sebelumnya'),
                                ),
                        ),
                      );
                    }

                    final msgIdx = hasMore ? idx - 1 : idx;
                    final msg = messages[msgIdx];
                    final prevMsg = msgIdx > 0 ? messages[msgIdx - 1] : null;
                    final showDateHeader = prevMsg == null ||
                        !_isSameCalendarDay(prevMsg.sortTimestamp, msg.sortTimestamp);

                    final isMine = msg.isFromViewer(
                      conv.viewerRole,
                      viewerUserId: provider.currentUserId,
                    );

                    return Column(
                      children: [
                        if (showDateHeader) _DateSeparatorPill(date: msg.sortTimestamp),
                        _MessageBubble(
                          message: msg,
                          isMine: isMine,
                          isDark: isDark,
                          authToken: _authToken,
                          onRetry: msg.deliveryStatus == ChatDeliveryStatus.failed &&
                                  msg.clientMessageId != null
                              ? () => provider.retryFailedMessage(conv.id, msg.clientMessageId!)
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildComposer(isDark, conv),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isDark, ConversationModel conv) {
    if (!conv.isActive) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: const Text(
            'Percakapan telah ditutup karena pengiriman selesai.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _showAttachmentMenu,
              tooltip: 'Kirim Foto',
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF64748B)),
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _textController,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (val) => unawaited(
                    context.read<ChatProvider>().notifyTyping(conv.id, val.trim().isNotEmpty),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _primaryOrange,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sendText,
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparatorPill extends StatelessWidget {
  final DateTime date;

  const _DateSeparatorPill({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      label = 'Hari Ini';
    } else {
      final yest = now.subtract(const Duration(days: 1));
      if (yest.year == date.year && yest.month == date.month && yest.day == date.day) {
        label = 'Kemarin';
      } else {
        label = DateFormat('dd MMM yyyy').format(date);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  final bool isDark;
  final String? authToken;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isDark,
    this.authToken,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? const Color(0xFFEC5B13)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F172A));
    final metaColor = isMine ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF94A3B8);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isWhatsAppChannel && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat, size: 11, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'via WhatsApp',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.localMediaPath != null || message.mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildImagePreview(context),
                ),
              if (message.body != null && message.body!.trim().isNotEmpty)
                Text(
                  message.body!,
                  style: TextStyle(fontSize: 14, color: textColor, height: 1.35),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.sortTimestamp),
                    style: TextStyle(fontSize: 10, color: metaColor),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(metaColor),
                  ],
                ],
              ),
              if (isMine && message.waStatus == 'failed' && message.waErrorCode != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'WA gagal (${message.waErrorCode})',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                ),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: onRetry,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Gagal terkirim • Ketuk kirim ulang',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final Widget imageWidget = message.localMediaPath != null
        ? Image.file(
            File(message.localMediaPath!),
            fit: BoxFit.cover,
            width: 220,
            height: 170,
          )
        : Image.network(
            message.mediaUrl!,
            headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
            fit: BoxFit.cover,
            width: 220,
            height: 170,
            errorBuilder: (_, _, _) => Container(
              width: 220,
              height: 120,
              color: Colors.black12,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: message.localMediaPath != null
                        ? Image.file(File(message.localMediaPath!))
                        : Image.network(
                            message.mediaUrl!,
                            headers: authToken != null
                                ? {'Authorization': 'Bearer $authToken'}
                                : null,
                          ),
                  ),
                ),
                Positioned(
                  top: 32,
                  right: 16,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageWidget,
      ),
    );
  }

  Widget _buildStatusIcon(Color defaultColor) {
    return switch (message.deliveryStatus) {
      ChatDeliveryStatus.sending => Icon(Icons.schedule_rounded, size: 13, color: defaultColor),
      ChatDeliveryStatus.sent => Icon(Icons.done_rounded, size: 14, color: defaultColor),
      ChatDeliveryStatus.delivered => Icon(Icons.done_all_rounded, size: 14, color: defaultColor),
      ChatDeliveryStatus.read =>
        const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF93C5FD)),
      ChatDeliveryStatus.failed =>
        const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFFEE2E2)),
    };
  }
}

class _WhatsappBridgeBanner extends StatelessWidget {
  final ConversationModel conversation;
  final bool isDark;
  final VoidCallback? onOpenWhatsappDirect;

  const _WhatsappBridgeBanner({
    required this.conversation,
    required this.isDark,
    this.onOpenWhatsappDirect,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final st = provider.whatsappStatus;
        if (st == null || !st.whatsappCloudEnabled) {
          return const SizedBox.shrink();
        }

        if (!st.isOptedIn) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.45) : const Color(0xFFECFDF5),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFA7F3D0),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_chat_unread_outlined, size: 18, color: Color(0xFF15803D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    st.phoneVerified
                        ? 'Aktifkan notifikasi WhatsApp agar balasan chat masuk ke WA Anda.'
                        : 'Verifikasi nomor HP akun Anda dulu agar pesan bisa masuk ke WA Anda.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF14532D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final ok = await provider.toggleWhatsappOptIn(
                      optIn: true,
                      conversationId: conversation.id,
                    );
                    if (!context.mounted) return;
                    final msg = ok
                        ? 'Notifikasi WhatsApp diaktifkan untuk akun Anda.'
                        : (provider.lastWhatsappError ??
                            'Nomor HP harus terverifikasi OTP terlebih dahulu.');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Aktifkan',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }

        if (!conversation.counterparty.waOptedIn) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFFDE68A),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${conversation.displayTitle} belum mengaktifkan notif WA di aplikasinya.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                    ),
                  ),
                ),
                if (onOpenWhatsappDirect != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: const Size(0, 26),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onOpenWhatsappDirect,
                    child: const Text(
                      'Chat WA',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
