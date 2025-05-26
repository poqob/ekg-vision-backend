import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'dart:convert';
import 'user.dart';

Future<Db> connectToDatabase(String uri) async {
  final db = Db(uri);
  await db.open();
  return db;
}

Future<void> main() async {
  final db = await connectToDatabase('mongodb://localhost:27017/ekg_vision');
  final usersCollection = db.collection('users');
  final userRepository = UserRepository(usersCollection);

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(
    (Request request) async {
      if (request.url.path == 'register' && request.method == 'POST') {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final email = data['email'];
        final username = data['username'];
        final password = data['password'];
        if (email == null || username == null || password == null) {
          return Response(400, body: 'Email, username and password required');
        }
        final existingEmail = await userRepository.findByEmail(email);
        final existingUsername = await userRepository.findByUsername(username);
        if (existingEmail != null || existingUsername != null) {
          return Response(409, body: 'User already exists');
        }
        await userRepository.createUser(email, username, password);
        return Response(201, body: 'User registered');
      }
      if (request.url.path == 'login' && request.method == 'POST') {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
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
        return Response(200, body: 'Login successful');
      }
      return Response.notFound('Not Found');
    },
  );

  final server = await io.serve(handler, 'localhost', 8080);
  print('Server listening on localhost:[1m${server.port}[0m');
}
