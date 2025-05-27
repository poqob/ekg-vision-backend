import 'package:mongo_dart/mongo_dart.dart';
import 'dart:math';

String generateTcNo(Random random) {
  // First digit cannot be 0
  String tc = (1 + random.nextInt(9)).toString();
  for (int i = 0; i < 10; i++) {
    tc += random.nextInt(10).toString();
  }
  return tc;
}

Future<void> main() async {
  final db = await Db.create('mongodb://localhost:27017/ekg_vision');
  await db.open();
  final patients = db.collection('patients');

  final random = Random();
  final List<Map<String, dynamic>> patientList = List.generate(
      10,
      (i) => {
            'username': [
              'AliYilmaz',
              'AyseKara',
              'MehmetDemir',
              'FatmaCelik',
              'AhmetSahin',
              'ElifAydin',
              'MustafaKurt',
              'ZeynepGunes',
              'EmrePolat',
              'HaticeOz'
            ][i],
            'email': 'mail@mail.com',
            'passwordHash': 'password',
            'tc_no': generateTcNo(random),
          });

  await patients.insertAll(patientList);
  print('10 patients inserted.');
  await db.close();
}
