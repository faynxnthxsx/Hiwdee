import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/message.dart';
import 'chat_repository.dart';
import 'memory_chat_repository.dart';
import 'supabase_chat_repository.dart';

/// ต่อ Supabase อยู่ → ใช้ Realtime ของจริง ไม่งั้นใช้ตัวในหน่วยความจำ
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client != null) return SupabaseChatRepository(client);

  final repo = MemoryChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// ข้อความในห้องของออเดอร์หนึ่ง เด้งเองเมื่ออีกฝ่ายพิมพ์
final chatStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, orderId) {
  return ref.watch(chatRepositoryProvider).watch(orderId);
});

/// จำนวนข้อความที่คนอื่นส่งมา ใช้ขึ้นป้ายบนปุ่มแชท
final unreadChatCountProvider =
    Provider.family<int, ({String orderId, String myId})>((ref, args) {
  final messages = ref.watch(chatStreamProvider(args.orderId)).value;
  if (messages == null) return 0;

  return messages
      .where((m) => !m.isSystem && m.senderId != args.myId)
      .length;
});
