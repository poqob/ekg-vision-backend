import 'package:test/test.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:ekg_vision_backend/user.dart';

void main() {
  late Db db;
  late DbCollection users;
  late UserRepository userRepository;

  setUp(() async {
    db = Db('mongodb://localhost:27017/ekg_vision_test');
    await db.open();
    users = db.collection('users');
    await users.remove({}); // Temiz başlangıç
    userRepository = UserRepository(users);
  });

  tearDown(() async {
    await db.close();
  });

  test('Kullanıcı başarıyla oluşturuluyor', () async {
    final user =
        await userRepository.createUser('test@example.com', 'password123');
    expect(user.email, 'test@example.com');
    final found = await userRepository.findByEmail('test@example.com');
    expect(found, isNotNull);
    expect(found!.email, 'test@example.com');
  });

  test('Aynı email ile tekrar kayıt olmuyor', () async {
    await userRepository.createUser('test@example.com', 'password123');
    final found = await userRepository.findByEmail('test@example.com');
    expect(found, isNotNull);
    // İkinci kez eklemeye çalışınca hata beklenir
    try {
      await userRepository.createUser('test@example.com', 'password123');
      fail('Aynı email ile ikinci kullanıcı oluşturuldu!');
    } catch (e) {
      expect(e, isNotNull);
    }
  });

  test('Doğru şifre ile giriş başarılı', () async {
    await userRepository.createUser('test@example.com', 'password123');
    final valid =
        await userRepository.validateUser('test@example.com', 'password123');
    expect(valid, isTrue);
  });

  test('Yanlış şifre ile giriş başarısız', () async {
    await userRepository.createUser('test@example.com', 'password123');
    final valid =
        await userRepository.validateUser('test@example.com', 'wrongpass');
    expect(valid, isFalse);
  });
}
