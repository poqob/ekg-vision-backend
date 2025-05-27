import 'package:mongo_dart/mongo_dart.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class User {
  final String id;
  final String email;
  final String username;
  final String passwordHash;
  final String? profilePictureUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.passwordHash,
    this.profilePictureUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'email': email,
      'username': username,
      'passwordHash': passwordHash,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  static User fromMap(Map<String, dynamic> map) {
    return User(
      id: map['_id'].toString(),
      email: map['email'],
      username: map['username'],
      passwordHash: map['passwordHash'],
      profilePictureUrl: map['profilePictureUrl'],
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

  Future<User> createUser(String email, String username, String password,
      {String? profilePictureUrl}) async {
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    final user = User(
        id: ObjectId().toHexString(),
        email: email,
        username: username,
        passwordHash: passwordHash,
        profilePictureUrl: profilePictureUrl);
    await users.insert(user.toMap());
    return user;
  }

  Future<User> updateUser(String id,
      {String? email, String? password, String? profilePictureUrl}) async {
    final update = <String, dynamic>{};
    if (email != null) update['email'] = email;
    if (password != null) {
      update['passwordHash'] = sha256.convert(utf8.encode(password)).toString();
    }
    if (profilePictureUrl != null) {
      update['profilePictureUrl'] = profilePictureUrl;
    }
    await users.updateOne({'_id': id}, {r'$set': update});
    final userMap = await users.findOne({'_id': id});
    return User.fromMap(userMap!);
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
