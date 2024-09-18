import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class WaitingScreen extends StatefulWidget {
  @override
  _WaitingScreenState createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late StreamSubscription _userSubscription;

  @override
  void initState() {
    super.initState();
    _updateStatusToWaiting();
    _listenForAvailableUsers();
  }

  Future<void> _updateStatusToWaiting() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'status': '1', // Set status to '1' for waiting
        'isMatched': false,
        'currentChatId': null,
      });
    }
  }

  void _listenForAvailableUsers() {
    _userSubscription = _firestore
        .collection('users')
        .where('status', isEqualTo: '1')
        .snapshots()
        .listen((QuerySnapshot snapshot) async {
      if (snapshot.docs.length >= 2) {
        var user1 = snapshot.docs[0];
        var user2 = snapshot.docs[1];

        String chatId = _createChatSession(user1.id, user2.id);

        await _firestore.collection('users').doc(user1.id).update({
          'status': '2',
          'isMatched': true,
          'currentChatId': chatId,
        });
        await _firestore.collection('users').doc(user2.id).update({
          'status': '2',
          'isMatched': true,
          'currentChatId': chatId,
        });

        User? currentUser = _auth.currentUser;
        if (currentUser != null &&
            (currentUser.uid == user1.id || currentUser.uid == user2.id)) {
          Navigator.pushReplacementNamed(context, '/chat', arguments: chatId);
        }
      }
    });
  }

  String _createChatSession(String userId1, String userId2) {
    DocumentReference chatRef = _firestore.collection('chats').doc();
    chatRef.set({
      'users': [userId1, userId2],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return chatRef.id;
  }

  Future<void> _goBackToLogin() async {
    User? user = _auth.currentUser;

    if (user != null) {
      String userId = user.uid;
      await _clearUserDatabaseDetails(userId);
      await user.delete();
      await _auth.signOut();
    }

    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _clearUserDatabaseDetails(String userId) async {
    await _firestore.collection('users').doc(userId).delete();

    QuerySnapshot chatSessions = await _firestore
        .collection('chats')
        .where('users', arrayContains: userId)
        .get();

    for (QueryDocumentSnapshot chat in chatSessions.docs) {
      await chat.reference.delete();
    }
  }

  @override
  void dispose() {
    _userSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Connecting...'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBackToLogin,
        ),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, Colors.cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/animations/waiting.json',
                    width: 250, height: 250),
                const SizedBox(height: 40),
                const Text(
                  'Waiting for another user to connect...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
