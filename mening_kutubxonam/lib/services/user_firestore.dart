import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFirestore {
  UserFirestore._();

  static final instance = UserFirestore._();

  DocumentReference<Map<String, dynamic>> get userDocument {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('user-not-signed-in');
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      userDocument.collection(name);

  WriteBatch batch() => FirebaseFirestore.instance.batch();
}

final userFirestore = UserFirestore.instance;
