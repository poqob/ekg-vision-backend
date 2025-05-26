import 'package:mongo_dart/mongo_dart.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class User {
  final String id;
  final String email;
  final String username;
  final String passwordHash;

  User(
      {required this.id,
      required this.email,
      required this.username,
      required this.passwordHash});

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'email': email,
      'username': username,
      'passwordHash': passwordHash,
    };
  }

  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id'].toString(),
      email: map['email'],
      username: map['username'],
      passwordHash: map['passwordHash'],
    );
  }
}

class UserRepository {
  final DbCollection users;
  UserRepository(this.users);

  Future<User?> findByEmail(String email) async {
    final userMap = await users.findOne({'email': email});
    if (userMap == null) return null;
    return User.fromMap(userMap);
  }

  Future<User?> findByUsername(String username) async {
    final userMap = await users.findOne({'username': username});
    if (userMap == null) return null;
    return User.fromMap(userMap);
  }

  Future<User> createUser(
      String email, String username, String password) async {
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    final user = User(
        id: ObjectId().toHexString(),
        email: email,
        username: username,
        passwordHash: passwordHash);
    await users.insert(user.toMap());
    return user;
  }

  Future<bool> validateUser(
      {String? email, String? username, required String password}) async {
    User? user;
    if (email != null) {
      user = await findByEmail(email);
    } else if (username != null) {
      user = await findByUsername(username);
    }
    if (user == null) return false;
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    return user.passwordHash == passwordHash;
  }
}
