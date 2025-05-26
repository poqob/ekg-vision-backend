import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ekg_vision_backend/user.dart' as user_repo;

Future<void> main(List<String> arguments) async {
  final db = await Db.create('mongodb://localhost:27017/ekg_vision');
  await db.open();
  final userRepository = user_repo.UserRepository(db.collection('users'));

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    if (request.url.path == 'register' && request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final email = data['email'];
      final password = data['password'];
      if (email == null || password == null) {
        return Response(400, body: 'Email and password required');
      }
      final existing = await userRepository.findByEmail(email);
      if (existing != null) {
        return Response(409, body: 'User already exists');
      }
      await userRepository.createUser(email, password);
      return Response(201, body: 'User registered');
    }
    if (request.url.path == 'login' && request.method == 'POST') {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final email = data['email'];
      final password = data['password'];
      if (email == null || password == null) {
        return Response(400, body: 'Email and password required');
      }
      final valid = await userRepository.validateUser(email, password);
      if (!valid) {
        return Response(401, body: 'Invalid credentials');
      }
      return Response(200, body: 'Login successful');
    }
    return Response.notFound('Not Found');
  });

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server listening on localhost:[1m${server.port}[0m');
}
