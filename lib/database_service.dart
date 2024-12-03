import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DatabaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send location to Firestore
  static Future<void> sendLocation(Position position) async {
    await _firestore.collection('locations').doc('current_location').set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Fetch locations from Firestore
  static Stream<List<Map<String, dynamic>>> fetchLocations() {
    return _firestore
        .collection('locations')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
