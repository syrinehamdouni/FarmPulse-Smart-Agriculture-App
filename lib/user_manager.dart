import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  String name;
  String email;
  String phone;
  String? imagePath;
  String cropYield;
  String irrigation;
  String soil;
  String languageCode;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.imagePath,
    this.cropYield = "--",
    this.irrigation = "--",
    this.soil = "--",
    this.languageCode = "fr",
  });
}

class UserManager extends ChangeNotifier {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal() {
    auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        fetchUserData();
      } else {
        _resetUser();
      }
    });
  }

  UserProfile _user = UserProfile(
    name: "Chargement...",
    email: "",
    phone: "",
    languageCode: "fr",
  );

  UserProfile get user => _user;

  void _resetUser() {
    _user = UserProfile(name: "Invité", email: "", phone: "", languageCode: "fr");
    notifyListeners();
  }

  Future<void> fetchUserData() async {
    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (doc.exists) {
          final data = doc.data();
          _user = UserProfile(
            name: data?['fullName'] ?? "Utilisateur",
            email: currentUser.email ?? "",
            phone: data?['phone'] ?? "",
            imagePath: data?['profileImageUrl'],
            cropYield: data?['cropYield'] ?? "0%",
            irrigation: data?['irrigation'] ?? "0%",
            soil: data?['soil'] ?? "Inconnu",
            languageCode: data?['languageCode'] ?? "fr",
          );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Erreur fetchUserData: $e");
    }
  }

  Future<void> changeLanguage(String code) async {
    _user.languageCode = code;
    notifyListeners();
    
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({'languageCode': code}, SetOptions(merge: true));
    }
  }

  Future<void> updateFirestoreUser({
    String? name, 
    String? phone, 
    String? imagePath,
    String? cropYield,
    String? irrigation,
    String? soil,
  }) async {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      Map<String, dynamic> updates = {};
      if (name != null) updates['fullName'] = name;
      if (phone != null) updates['phone'] = phone;
      if (imagePath != null) updates['profileImageUrl'] = imagePath;
      if (cropYield != null) updates['cropYield'] = cropYield;
      if (irrigation != null) updates['irrigation'] = irrigation;
      if (soil != null) updates['soil'] = soil;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(updates, SetOptions(merge: true));
          
      await fetchUserData();
    }
  }
}
