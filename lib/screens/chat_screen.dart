import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:randam_chat_app_b/screens/waiting_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

   ChatScreen({required this.chatId, required this.chatName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _myUserId = '';
  String _otherUserName = 'Other User';
  String _myUserName = 'My Name';
  String _otherUserId = '';

  @override
  void initState() {
    super.initState();
    _updateStatusToChat();
    _getUserDetails();
  }

  Future<void> _updateStatusToChat() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({'status': '2'}); // Set status to '2'
      } catch (e) {
        print("Failed to update status: $e");
      }
    }
  }

  Future<void> _getUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _myUserId = user.uid;

      try {
        // Get current user details
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_myUserId).get();
        setState(() {
          _myUserName = userDoc['name'] ?? 'My Name';
        });

        // Get the other user's details based on the chat ID
        DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(widget.chatId).get();
        List<dynamic> userIds = chatDoc['users'];
        _otherUserId = userIds.firstWhere((id) => id != _myUserId);

        DocumentSnapshot otherUserDoc = await _firestore.collection('users').doc(_otherUserId).get();
        setState(() {
          _otherUserName = otherUserDoc['name'] ?? 'Other User';
        });
      } catch (e) {
        print("Failed to get user details: $e");
      }
    }
  }

  void _sendMessage() async {
    try {
      if (_messageController.text.isNotEmpty) {
        final String? userId = _auth.currentUser?.uid;

        if (userId != null) {
          await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
            'text': _messageController.text,
            'createdAt': FieldValue.serverTimestamp(),
            'senderId': userId,
          });
          _messageController.clear();
          _scrollToBottom();
        } else {
          _showError('User is not logged in. Please log in to send messages.');
        }
      }
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _removeChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => WaitingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUserName),
        backgroundColor: Colors.cyan,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _removeChat,
            tooltip: 'Remove Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('chats').doc(widget.chatId).collection('messages').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var message = snapshot.data!.docs[index];
                    print(message);
                    bool isMe = message['senderId'] == _auth.currentUser?.uid;

                    return Container(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (isMe)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4.0),
                              child: CircleAvatar(
                                child: Text('Me'),
                                backgroundColor: Colors.cyan,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.cyan[100] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['text'],
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                          if (!isMe)
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: CircleAvatar(
                                child: Text('user'),
                                backgroundColor: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.cyan),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
