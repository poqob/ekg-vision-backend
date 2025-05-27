import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ekg_vision_backend/user.dart' as user_repo;
import 'package:ekg_vision_backend/profile_picture_repository.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:mime/mime.dart';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final db = await Db.create('mongodb://localhost:27017/ekg_vision');
  await db.open();
  final userRepository = user_repo.UserRepository(db.collection('users'));
  final profilePictures = db.collection('profile_pictures');
  final profilePictureRepository = ProfilePictureRepository(profilePictures);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    if (request.url.path == 'register' && request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final email = data['email'];
      final username = data['username'];
      final password = data['password'];
      final profilePictureUrl = data['profilePictureUrl'];
      if (email == null || username == null || password == null) {
        return Response(400, body: 'Email, username and password required');
      }
      final existingEmail = await userRepository.findByEmail(email);
      final existingUsername = await userRepository.findByUsername(username);
      if (existingEmail != null || existingUsername != null) {
        return Response(409, body: 'User already exists');
      }
      await userRepository.createUser(email, username, password,
          profilePictureUrl: profilePictureUrl);
      return Response(201, body: 'User registered');
    }
    if (request.url.path == 'login' && request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final email = data['email'];
      final username = data['username'];
      final password = data['password'];
      if ((email == null && username == null) || password == null) {
        return Response(400, body: 'Email or username and password required');
      }
      final valid = await userRepository.validateUser(
          email: email, username: username, password: password);
      if (!valid) {
        return Response(401, body: 'Invalid credentials');
      }
      final user = email != null
          ? await userRepository.findByEmail(email)
          : await userRepository.findByUsername(username);
      if (user == null) {
        return Response(401, body: 'User not found');
      }
      final jwt = JWT({
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'profilePictureUrl': user.profilePictureUrl,
      });
      final token = jwt.sign(SecretKey('super_secret_key'),
          expiresIn: Duration(hours: 24));
      return Response.ok(jsonEncode({'token': token}),
          headers: {'Content-Type': 'application/json'});
    }
    if (request.url.path == 'update_profile' && request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final id = data['id'];
      final email = data['email'];
      final password = data['password'];
      final profilePictureUrl = data['profilePictureUrl'];
      if (id == null) {
        return Response(400, body: 'User id required');
      }
      try {
        final updatedUser = await userRepository.updateUser(
          id,
          email: email,
          password: password,
          profilePictureUrl: profilePictureUrl,
        );
        return Response(200,
            body: jsonEncode({
              'id': updatedUser.id,
              'email': updatedUser.email,
              'username': updatedUser.username,
              'profilePictureUrl': updatedUser.profilePictureUrl,
            }),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response(500, body: 'Update failed: \\${e.toString()}');
      }
    }
    if (request.url.path == 'upload_profile_picture' &&
        request.method == 'POST') {
      final userId = request.url.queryParameters['userId'];
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden(
            jsonEncode({
              'success': false,
              'message': 'Authorization header required.'
            }),
            headers: {'Content-Type': 'application/json'});
      }
      if (userId == null) {
        return Response(400,
            body: jsonEncode({'success': false, 'message': 'userId required.'}),
            headers: {'Content-Type': 'application/json'});
      }
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response(400,
            body: jsonEncode({
              'success': false,
              'message': 'Content-Type must be multipart/form-data.'
            }),
            headers: {'Content-Type': 'application/json'});
      }
      // Extract boundary
      final boundaryMatch = RegExp(r'boundary=(.*)').firstMatch(contentType);
      if (boundaryMatch == null) {
        return Response(400,
            body:
                jsonEncode({'success': false, 'message': 'No boundary found.'}),
            headers: {'Content-Type': 'application/json'});
      }
      final boundary = boundaryMatch.group(1)!;
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(request.read()).toList();
      List<int>? fileBytes;
      for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'] ?? '';
        if (contentDisposition.contains('name="file"')) {
          fileBytes =
              await part.fold<List<int>>(<int>[], (b, d) => b..addAll(d));
          break;
        }
      }
      if (fileBytes == null) {
        return Response(400,
            body: jsonEncode(
                {'success': false, 'message': 'No file field found.'}),
            headers: {'Content-Type': 'application/json'});
      }
      // Check file type (accept only JPEG or PNG)
      final isJpeg =
          fileBytes.length > 3 && fileBytes[0] == 0xFF && fileBytes[1] == 0xD8;
      final isPng =
          fileBytes.length > 3 && fileBytes[0] == 0x89 && fileBytes[1] == 0x50;
      if (!isJpeg && !isPng) {
        return Response(400,
            body:
                jsonEncode({'success': false, 'message': 'Invalid file type.'}),
            headers: {'Content-Type': 'application/json'});
      }
      await profilePictureRepository.saveProfilePicture(userId, fileBytes);
      await userRepository.updateUser(userId,
          profilePictureUrl: '/profile_picture/$userId');
      return Response.ok(
          jsonEncode({
            'success': true,
            'message': 'Profile picture uploaded successfully.'
          }),
          headers: {'Content-Type': 'application/json'});
    }
    if (request.url.pathSegments.length == 2 &&
        request.url.pathSegments[0] == 'profile_picture' &&
        request.method == 'GET') {
      final userId = request.url.pathSegments[1];
      final picture = await profilePictureRepository.getProfilePicture(userId);
      if (picture == null) {
        return Response.notFound('No profile picture');
      }
      // Try to detect image type (default to png)
      String contentType = 'image/png';
      if (picture.length > 3 && picture[0] == 0xFF && picture[1] == 0xD8) {
        contentType = 'image/jpeg';
      }
      return Response.ok(picture, headers: {'Content-Type': contentType});
    }
    if (request.url.path == 'me' && request.method == 'GET') {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401, body: 'Missing or invalid Authorization header');
      }
      final token = authHeader.substring(7);
      try {
        final jwt = JWT.verify(token, SecretKey('super_secret_key'));
        final userId = jwt.payload['id'] as String?;
        if (userId == null) {
          return Response(401, body: 'Invalid token payload');
        }
        final user = await userRepository.findByEmail(jwt.payload['email']);
        if (user == null) {
          return Response(404, body: 'User not found');
        }
        return Response.ok(
            jsonEncode({
              'id': user.id,
              'username': user.username,
              'email': user.email,
              'name': jwt.payload['name'] ?? '',
              'profilePictureUrl': user.profilePictureUrl,
            }),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response(401, body: 'Invalid or expired token');
      }
    }
    return Response.notFound('Not Found');
  });

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server listening on localhost:${server.port}');
}
