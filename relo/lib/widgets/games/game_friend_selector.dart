import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/service_locator.dart';
import '../../services/user_service.dart';
import '../../services/message_service.dart';
import '../../services/secure_storage_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class GameFriendSelector extends StatefulWidget {
  final String gameName;
  const GameFriendSelector({super.key, required this.gameName});

  @override
  State<GameFriendSelector> createState() => _GameFriendSelectorState();
}

class _GameFriendSelectorState extends State<GameFriendSelector> {
  final UserService _userService = ServiceLocator.userService;
  final MessageService _messageService = ServiceLocator.messageService;
  late Future<List<User>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _userService.getFriends();
  }

  void _selectFriend(User friend) async {
    try {
      final SecureStorageService secureStorage = const SecureStorageService();
      final currentUserId = await secureStorage.getUserId();

      final conversation = await _messageService.getOrCreateConversation(
        [currentUserId!, friend.id],
        false,
        null,
      );

      if (conversation.isNotEmpty && conversation['id'] != null) {
        if (mounted) {
          Navigator.pop(context, {
            'friend': friend,
            'conversationId': conversation['id'],
            'currentUserId': currentUserId,
            'participants': conversation['participants'],
          });
        }
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(msg: "Lỗi khi chọn bạn bè: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mời bạn bè chơi cùng",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: _friendsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Lỗi tải danh sách bạn bè"));
                }
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return const Center(child: Text("Bạn chưa có bạn bè để mời"));
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty
                            ? (friend.avatarUrl!.startsWith('assets/')
                                ? AssetImage(friend.avatarUrl!) as ImageProvider
                                : NetworkImage(friend.avatarUrl!))
                            : null,
                        child: friend.avatarUrl == null || friend.avatarUrl!.isEmpty
                            ? Text(friend.displayName[0].toUpperCase())
                            : null,
                      ),
                      title: Text(friend.displayName),
                      trailing: ElevatedButton(
                        onPressed: () => _selectFriend(friend),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7A2FC0),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Chọn"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
