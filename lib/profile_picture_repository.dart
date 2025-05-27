import 'package:mongo_dart/mongo_dart.dart';

class ProfilePictureRepository {
  final DbCollection collection;
  ProfilePictureRepository(this.collection);

  Future<void> saveProfilePicture(String userId, List<int> bytes) async {
    await collection.replaceOne({
      'userId': userId
    }, {
      'userId': userId,
      'picture': bytes,
    }, upsert: true);
  }

  Future<List<int>?> getProfilePicture(String userId) async {
    final doc = await collection.findOne({'userId': userId});
    if (doc == null) return null;
    return List<int>.from(doc['picture']);
  }
}
