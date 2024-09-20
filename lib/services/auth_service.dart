import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Stream<User?> get user => _auth.authStateChanges();

  Future<String> _getDeviceId() async {
    AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
    return androidInfo.id;
  }

  Future<void> signInAnonymously({
    required String name,
    required String age,
    required String gender,
  }) async {
    try {
      String deviceId = await _getDeviceId();

      QuerySnapshot query = await _firestore.collection('users').where('deviceId', isEqualTo: deviceId).get();
      if (query.docs.isNotEmpty) {
        print("Another user is already logged in on this device.");
        return;
      }

      UserCredential userCredential = await _auth.signInAnonymously();
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'age': age,
          'gender': gender,
          'deviceId': deviceId,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'isMatched': false,
          //'status': '0', // Set status to '0' on login
        });

        print("User details saved: ${user.uid}");
      }
    } catch (e) {
      print("Failed to sign in anonymously: $e");
    }
  }

  Future<void> matchUsers() async {
    try {
      String currentUserId = _auth.currentUser!.uid;

      QuerySnapshot activeUsers = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('isMatched', isEqualTo: false)
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .limit(1)
          .get();

      if (activeUsers.docs.isNotEmpty) {
        String matchedUserId = activeUsers.docs.first.id;

        await _firestore.collection('users').doc(currentUserId).update({
          'isMatched': true,
        });

        await _firestore.collection('users').doc(matchedUserId).update({
          'isMatched': true,
        });

         await _createChatSession(currentUserId, matchedUserId);

        // Optionally, you can notify users or update UI here
      } else {
        print("No available users to match.");
      }
    } catch (e) {
      print("Failed to match users: $e");
    }
  }

  Future<void> _createChatSession(String user1, String user2) async {
    DocumentReference chatRef = await _firestore.collection('chats').add({
      'user1': user1,
      'user2': user2,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("Chat session created: ${chatRef.id}");

    // Notify users that they have been matched
    await _firestore.collection('users').doc(user1).update({
      'currentChatId': chatRef.id,
    });

    await _firestore.collection('users').doc(user2).update({
      'currentChatId': chatRef.id,
    });
  }

  Future<void> signOut() async {
    try {
      User? user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();
        await _deleteChatSession(user.uid);
        print("User data deleted: ${user.uid}");
      }

      await _auth.signOut();
      print("User signed out successfully.");
    } catch (e) {
      print("Failed to sign out: $e");
    }
  }
  Future<void> _deleteChatSession(String userId) async {
    QuerySnapshot userChats = await _firestore
        .collection('chats')
        .where('user1', isEqualTo: userId)
        .get();

    for (var doc in userChats.docs) {
      await doc.reference.delete();
    }

    QuerySnapshot userChats2 = await _firestore
        .collection('chats')
        .where('user2', isEqualTo: userId)
        .get();

    for (var doc in userChats2.docs) {
      await doc.reference.delete();
    }

    print("All chat sessions for user $userId deleted.");
  }
}
