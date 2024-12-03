import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:location_tracker/database_service.dart';
import 'package:location_tracker/location_service.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp();
      final position = await LocationService.getCurrentLocation();
      await DatabaseService.sendLocation(position);
      return Future.value(true);
    } catch (e) {
      print('Background execution error: $e');
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LocationTrackerScreen(),
    );
  }
}

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocationTrackerScreenState createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  bool _isTracking = false;
  Timer? _locationUpdateTimer;
  List<Map<String, dynamic>> _locations = [];

  // Fetch locations
  Stream<List<Map<String, dynamic>>> _fetchLocations() {
    return DatabaseService.fetchLocations();
  }

  // Start tracking
  void _startTracking() {
    setState(() {
      _isTracking = true;
    });

    // Register periodic background task
    Workmanager().registerPeriodicTask(
      "locationTracking",
      "locationTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateLocation();
    });

    _updateLocation();
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
    });
    Workmanager().cancelAll();
  }

  void _updateLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      await DatabaseService.sendLocation(position);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        centerTitle: true,
        leading: const Icon(Icons.arrow_back_outlined),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
          ),
          if (_isTracking)
            ElevatedButton(
              onPressed: _updateLocation,
              child: const Text('Update Location Now'),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fetchLocations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No locations found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final location = snapshot.data![index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        child: ListTile(
                          title: Text(
                            'Lat: ${location['latitude']}, Lon: ${location['longitude']}',
                          ),
                          subtitle: Text(
                            'Time: ${location['timestamp'].toDate()}',
                          ),
                          tileColor: const Color.fromARGB(255, 229, 229, 229),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
