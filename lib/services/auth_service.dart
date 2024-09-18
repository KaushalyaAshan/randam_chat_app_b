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
          'status': '0', // Set status to '0' on login
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
      } else {
        print("No available users to match.");
      }
    } catch (e) {
      print("Failed to match users: $e");
    }
  }

  Future<void> _createChatSession(String user1, String user2) async {
    DocumentReference chatRef = _firestore.collection('chats').doc();

    await chatRef.set({
      'users': [user1, user2],
      'createdAt': FieldValue.serverTimestamp(),
    });

    print("Chat session created between $user1 and $user2");
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Failed to sign out: $e");
    }
  }
}
