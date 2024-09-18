import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:randam_chat_app_b/screens/waiting_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({required this.chatId, required this.chatName});

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
      await _firestore.collection('users').doc(user.uid).update({'status': '2'}); // Set status to '2'
    }
  }

  Future<void> _getUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _myUserId = user.uid;

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
    }
  }

  void _sendMessage() async {
    User? user = _auth.currentUser;
    if (user != null && _messageController.text.isNotEmpty) {
      await _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
        'senderId': user.uid,
        'message': _messageController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false) // Messages in chronological order
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index];
                    bool isMe = messageData['senderId'] == _myUserId; // Check if the message is from the current user

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start, // Position based on user
                        children: [
                          if (!isMe) // Show the sender's name/avatar for received messages
                            CircleAvatar(
                              child: Text(_otherUserName[0].toUpperCase()), // Show first letter of the other user
                              backgroundColor: Colors.grey,
                            ),
                          if (!isMe) const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(10.0),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.cyan[100] : Colors.grey[200], // Color based on user
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              messageData['message'],
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                          if (isMe) const SizedBox(width: 8), // Space between message and avatar
                          if (isMe) // Show the user's own initials for sent messages
                            CircleAvatar(
                              child: Text(_myUserName[0].toUpperCase()),
                              backgroundColor: Colors.cyan,
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
