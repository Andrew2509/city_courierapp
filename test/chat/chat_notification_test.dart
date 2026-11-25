import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/chat/chat_notification_service.dart';

void main() {
  group('ChatNotificationCoordinator', () {
    test('deduplicates same message_id across WebSocket and FCM', () {
      final coordinator = ChatNotificationCoordinator(maxTrackedIds: 10);

      final first = coordinator.shouldDisplay(
        conversationId: 12,
        activeConversationId: null,
        messageId: 901,
        clientMessageId: 'uuid-901',
        senderUserId: 2,
        currentUserId: 1,
        isAppInForeground: true,
      );
      expect(first, true);

      // Same message arriving again via FCM/WS must NOT notify twice
      final duplicateById = coordinator.shouldDisplay(
        conversationId: 12,
        activeConversationId: null,
        messageId: 901,
        clientMessageId: null,
        senderUserId: 2,
        currentUserId: 1,
        isAppInForeground: true,
      );
      expect(duplicateById, false);

      final duplicateByClientUuid = coordinator.shouldDisplay(
        conversationId: 12,
        activeConversationId: null,
        messageId: 902,
        clientMessageId: 'uuid-901',
        senderUserId: 2,
        currentUserId: 1,
        isAppInForeground: true,
      );
      expect(duplicateByClientUuid, false);
    });

    test('suppresses foreground notification when active conversation is currently open', () {
      final coordinator = ChatNotificationCoordinator();

      final shouldShow = coordinator.shouldDisplay(
        conversationId: 44,
        activeConversationId: 44,
        messageId: 300,
        clientMessageId: 'uuid-300',
        senderUserId: 5,
        currentUserId: 1,
        isAppInForeground: true,
      );
      expect(shouldShow, false);

      // Even if FCM arrives milliseconds later after closing room, same message stays suppressed
      final delayedDuplicate = coordinator.shouldDisplay(
        conversationId: 44,
        activeConversationId: null,
        messageId: 300,
        clientMessageId: 'uuid-300',
        senderUserId: 5,
        currentUserId: 1,
        isAppInForeground: true,
      );
      expect(delayedDuplicate, false);
    });

    test('suppresses self-authored messages and evicts old IDs cleanly beyond max limit', () {
      final coordinator = ChatNotificationCoordinator(maxTrackedIds: 2);

      expect(
        coordinator.shouldDisplay(
          conversationId: 10,
          activeConversationId: null,
          messageId: 1,
          senderUserId: 7,
          currentUserId: 7,
        ),
        false,
      );

      expect(
        coordinator.shouldDisplay(
          conversationId: 10,
          activeConversationId: null,
          messageId: 101,
          senderUserId: 2,
          currentUserId: 1,
        ),
        true,
      );
      expect(
        coordinator.shouldDisplay(
          conversationId: 10,
          activeConversationId: null,
          messageId: 102,
          senderUserId: 2,
          currentUserId: 1,
        ),
        true,
      );
      expect(
        coordinator.shouldDisplay(
          conversationId: 10,
          activeConversationId: null,
          messageId: 103,
          senderUserId: 2,
          currentUserId: 1,
        ),
        true,
      );
      // 101 was evicted when maxTrackedIds == 2; 103 remains tracked
      expect(
        coordinator.shouldDisplay(
          conversationId: 10,
          activeConversationId: null,
          messageId: 103,
          senderUserId: 2,
          currentUserId: 1,
        ),
        false,
      );
    });
  });
}
