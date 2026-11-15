import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _errorMessage;
  String _role = '';
  String _uid = '';
  String _name = '';
  String _roomId = '';
  String _roomName = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Bạn chưa đăng nhập.');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw Exception('Không tìm thấy thông tin tài khoản.');
      }

      final data = userDoc.data() ?? {};

      if (data['isActive'] != true) {
        throw Exception('Tài khoản của bạn chưa được kích hoạt.');
      }

      final role = (data['role'] ?? '').toString().toLowerCase();

      if (role != 'manager' && role != 'tenant') {
        throw Exception('Tài khoản không có quyền sử dụng chức năng này.');
      }

      final roomId = (data['roomId'] ?? '').toString();

      if (role == 'tenant' && roomId.isEmpty) {
        throw Exception('Tài khoản người thuê chưa được gán phòng.');
      }

      if (!mounted) return;

      setState(() {
        _uid = user.uid;
        _role = role;
        _name = (data['name'] ?? user.displayName ?? 'Người dùng').toString();
        _roomId = roomId;
        _roomName = (data['roomName'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _openChat({
    required String tenantUid,
    required String tenantName,
    required String roomId,
    required String roomName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          currentUid: _uid,
          currentName: _name,
          currentRole: _role,
          tenantUid: tenantUid,
          tenantName: tenantName,
          roomId: roomId,
          roomName: roomName,
        ),
      ),
    );
  }

  Future<void> _openTenantConversation() async {
    _openChat(
      tenantUid: _uid,
      tenantName: _name,
      roomId: _roomId,
      roomName: _roomName,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadUser,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _role == 'manager' ? _buildManagerScreen() : _buildTenantScreen(),
    );
  }

  Widget _buildTenantScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trao đổi với quản lý',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn có thể gửi tin nhắn cho quản lý về tiền phòng, hóa đơn, '
              'sự cố hoặc các vấn đề liên quan đến phòng thuê.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _openTenantConversation,
                icon: const Icon(Icons.message),
                label: const Text(
                  'Mở cuộc trò chuyện',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _roomName.isEmpty ? 'Phòng: $_roomId' : 'Phòng: $_roomName',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerScreen() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('conversations')
          .orderBy('lastMessageAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không thể tải danh sách tin nhắn.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final conversations = snapshot.data?.docs ?? [];

        if (conversations.isEmpty) {
          return _emptyConversation();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final doc = conversations[index];
            final data = doc.data();

            final tenantUid = (data['tenantUid'] ?? doc.id).toString();
            final tenantName = (data['tenantName'] ?? 'Người thuê').toString();
            final roomName = (data['roomName'] ?? data['roomId'] ?? '')
                .toString();
            final lastMessage = (data['lastMessage'] ?? 'Chưa có tin nhắn')
                .toString();
            final unread = (data['managerUnread'] as num?)?.toInt() ?? 0;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      tenantName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Phòng: $roomName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0 ? Colors.black87 : Colors.grey,
                      fontWeight: unread > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _openChat(
                  tenantUid: tenantUid,
                  tenantName: tenantName,
                  roomId: (data['roomId'] ?? '').toString(),
                  roomName: roomName,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyConversation() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có cuộc trò chuyện nào',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tin nhắn của người thuê sẽ xuất hiện tại đây.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String currentUid;
  final String currentName;
  final String currentRole;
  final String tenantUid;
  final String tenantName;
  final String roomId;
  final String roomName;

  const ChatRoomScreen({
    super.key,
    required this.currentUid,
    required this.currentName,
    required this.currentRole,
    required this.tenantUid,
    required this.tenantName,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _sending = false;

  DocumentReference<Map<String, dynamic>> get _conversationRef =>
      _firestore.collection('conversations').doc(widget.tenantUid);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _conversationRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      final unreadField = widget.currentRole == 'manager'
          ? 'managerUnread'
          : 'tenantUnread';

      await _conversationRef.set({
        'tenantUid': widget.tenantUid,
        'tenantName': widget.tenantName,
        'roomId': widget.roomId,
        'roomName': widget.roomName,
        unreadField: 0,
      }, SetOptions(merge: true));

      final unreadMessages = await _messagesRef
          .where('senderUid', isNotEqualTo: widget.currentUid)
          .get();

      final batch = _firestore.batch();

      for (final message in unreadMessages.docs) {
        final readBy = List<String>.from(message.data()['readBy'] ?? []);

        if (!readBy.contains(widget.currentUid)) {
          batch.update(message.reference, {
            'readBy': FieldValue.arrayUnion([widget.currentUid]),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Lỗi đánh dấu tin nhắn đã đọc: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final conversationSnapshot = await _conversationRef.get();
      final conversationData = conversationSnapshot.data() ?? {};

      final currentUnreadField = widget.currentRole == 'manager'
          ? 'tenantUnread'
          : 'managerUnread';

      final currentUnread =
          (conversationData[currentUnreadField] as num?)?.toInt() ?? 0;

      final messageRef = _messagesRef.doc();

      final batch = _firestore.batch();

      batch.set(_conversationRef, {
        'tenantUid': widget.tenantUid,
        'tenantName': widget.tenantName,
        'roomId': widget.roomId,
        'roomName': widget.roomName,
        'lastMessage': content,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderUid': widget.currentUid,
        'lastSenderRole': widget.currentRole,
        currentUnreadField: currentUnread + 1,
      }, SetOptions(merge: true));

      batch.set(messageRef, {
        'senderUid': widget.currentUid,
        'senderName': widget.currentName,
        'senderRole': widget.currentRole,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [widget.currentUid],
      });

      await batch.commit();

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi tin nhắn thất bại: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '';
  }

  Widget _buildMessage(QueryDocumentSnapshot<Map<String, dynamic>> message) {
    final data = message.data();
    final isMe = data['senderUid'] == widget.currentUid;
    final content = (data['content'] ?? '').toString();
    final senderName = (data['senderName'] ?? '').toString();
    final time = _formatTime(data['createdAt']);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe && senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.currentRole == 'manager'
        ? widget.tenantName
        : 'Quản lý';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.roomName.isEmpty
                  ? 'Trao đổi tin nhắn'
                  : 'Phòng ${widget.roomName}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Không thể tải tin nhắn.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có tin nhắn',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Hãy gửi lời nhắn đầu tiên.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessage(messages[index]);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: IconButton.filled(
                      onPressed: _sending ? null : _sendMessage,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
