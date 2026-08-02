import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/media_store.dart';
import '../../../core/storage/photo_picker.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order_status.dart';
import '../data/chat_providers.dart';
import '../domain/message.dart';

/// ห้องแชทของออเดอร์หนึ่งใบ
///
/// ผูกกับออเดอร์ไม่ใช่ผูกกับคู่สนทนา เพราะคนคู่เดิมอาจทำหลายออเดอร์พร้อมกัน
/// และตอนเปิดข้อพิพาทต้องอ้างอิงได้ว่าคุยเรื่องของชิ้นไหน
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String get _myId => ref.read(currentUserProvider)?.id ?? 'guest';
  String get _myName => ref.read(currentUserProvider)?.displayName ?? 'คุณ';

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    _inputCtrl.clear();
    setState(() => _sending = true);

    await ref.read(chatRepositoryProvider).send(
          Message(
            id: 'm${DateTime.now().microsecondsSinceEpoch}',
            orderId: widget.orderId,
            senderId: _myId,
            senderName: _myName,
            sentAt: DateTime.now(),
            text: text,
          ),
        );

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendPhoto() async {
    final photo = await PhotoPicker.pick(ImageOrigin.gallery);
    if (photo == null || !mounted) return;

    setState(() => _sending = true);

    final url = await ref.read(mediaStoreProvider).upload(
          bytes: photo.bytes,
          path: 'orders/${widget.orderId}/chat/'
              '${DateTime.now().microsecondsSinceEpoch}-${photo.name}',
        );

    await ref.read(chatRepositoryProvider).send(
          Message(
            id: 'm${DateTime.now().microsecondsSinceEpoch}',
            orderId: widget.orderId,
            senderId: _myId,
            senderName: _myName,
            sentAt: DateTime.now(),
            kind: MessageKind.image,
            imageUrl: url,
          ),
        );

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderByIdProvider(widget.orderId));
    final messages = ref.watch(chatStreamProvider(widget.orderId));
    final online = ref.watch(isOnlineProvider);

    final other = order == null
        ? 'แชท'
        : order.myRole == OrderActor.requester
            ? order.carrierName
            : order.requesterName;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(other, style: const TextStyle(fontSize: 16)),
            if (order != null)
              Text(
                order.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.inkMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                online ? 'เรียลไทม์' : 'ออฟไลน์',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: online ? AppColors.success : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (order != null) _escrowStrip(order.status),
          Expanded(
            child: messages.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'โหลดข้อความไม่ได้\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text(
                        'ยังไม่มีข้อความ — ทักไปก่อนได้เลย',
                        style: TextStyle(color: AppColors.inkMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _Bubble(
                        message: list[i],
                        isMine: list[i].senderId == _myId,
                      ),
                    ),
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  /// เตือนไว้ตลอดว่าอย่าโอนนอกแอป — จุดที่ผู้ใช้มักโดนหลอกที่สุด
  Widget _escrowStrip(OrderStatus status) => Container(
        width: double.infinity,
        color: AppColors.brandSoft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 15, color: AppColors.brandDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'สถานะ: ${status.text} · '
                'อย่าโอนเงินนอกแอป จะไม่ได้รับความคุ้มครอง',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.brandDark,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'ส่งรูป',
                onPressed: _sending ? null : _sendPhoto,
                icon: const Icon(Icons.image_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'พิมพ์ข้อความ',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _inputCtrl.text.trim().isEmpty || _sending
                    ? null
                    : _send,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brand,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.line.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                message.senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: Container(
              padding: message.hasImage
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isMine ? AppColors.brand : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: isMine ? null : Border.all(color: AppColors.line),
              ),
              child: message.hasImage
                  ? AppImage(
                      url: message.imageUrl!,
                      borderRadius: BorderRadius.circular(10),
                    )
                  : Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isMine ? Colors.white : AppColors.ink,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              Fmt.ago(message.sentAt),
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
