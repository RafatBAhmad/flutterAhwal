/*
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/checkpoint.dart';

class NavigationService {
  static NavigationService? _instance;
  static NavigationService get instance => _instance ??= NavigationService._();
  NavigationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  StreamController<Position>? _positionController;
  Stream<Position>? _positionStream;
  
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  List<Checkpoint> _nearbyCheckpoints = [];
  Timer? _proximityTimer;
  
  final double _proximityRadius = 1000; // 1km radius for notifications
  bool _isNavigating = false;

  // Getters
  LatLng? get currentLocation => _currentLocation;
  LatLng? get destination => _destination;
  List<LatLng> get routePoints => _routePoints;
  List<Checkpoint> get nearbyCheckpoints => _nearbyCheckpoints;
  bool get isNavigating => _isNavigating;

  // Initialize the service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _requestLocationPermission();
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notificationsPlugin.initialize(settings);
  }

  // Request location permission
  Future<bool> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  // Get current location
  Future<LatLng?> getCurrentLocation() async {
    try {
      bool hasPermission = await _requestLocationPermission();
      if (!hasPermission) return null;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      return _currentLocation;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Start location tracking
  Stream<Position> startLocationTracking() {
    if (_positionStream != null) return _positionStream!;
    
    _positionController = StreamController<Position>.broadcast();
    
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );
    
    _positionStream!.listen((position) {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _positionController?.add(position);
      
      // Check proximity to checkpoints if navigating
      if (_isNavigating) {
        _checkCheckpointProximity();
      }
    });
    
    return _positionStream!;
  }

  // Stop location tracking
  void stopLocationTracking() {
    _positionController?.close();
    _positionController = null;
    _positionStream = null;
    _proximityTimer?.cancel();
  }

  // Start navigation to destination
  Future<bool> startNavigation(LatLng destination, List<Checkpoint> allCheckpoints) async {
    try {
      _destination = destination;
      _isNavigating = true;
      
      // Get current location if not available
      if (_currentLocation == null) {
        await getCurrentLocation();
      }
      
      if (_currentLocation == null) return false;
      
      // Calculate route
      await _calculateRoute(_currentLocation!, destination);
      
      // Find checkpoints along the route
      _findCheckpointsAlongRoute(allCheckpoints);
      
      // Start proximity monitoring
      _startProximityMonitoring();
      
      return true;
    } catch (e) {
      print('Error starting navigation: $e');
      return false;
    }
  }

  // Stop navigation
  void stopNavigation() {
    _isNavigating = false;
    _destination = null;
    _routePoints.clear();
    _nearbyCheckpoints.clear();
    _proximityTimer?.cancel();
  }

  // Calculate route between two points
  Future<void> _calculateRoute(LatLng start, LatLng end) async {
    try {
      // For now, create a simple straight line route
      // In production, you would use a routing service like OpenRouteService
      _routePoints = [start, end];
      
      // You can integrate with OpenRouteService API here for real routing
      // const String apiKey = 'YOUR_OPENROUTE_SERVICE_KEY';
      // final response = await http.get(Uri.parse(
      //   'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}'
      // ));
      
    } catch (e) {
      print('Error calculating route: $e');
      _routePoints = [start, end]; // Fallback to straight line
    }
  }

  // Find checkpoints along the route
  void _findCheckpointsAlongRoute(List<Checkpoint> allCheckpoints) {
    _nearbyCheckpoints.clear();
    
    if (_routePoints.isEmpty) return;
    
    for (final checkpoint in allCheckpoints) {
      if (checkpoint.latitude == null || checkpoint.longitude == null) continue;
      
      final checkpointLocation = LatLng(checkpoint.latitude!, checkpoint.longitude!);
      
      // Check if checkpoint is within proximity of the route
      bool isNearRoute = false;
      for (int i = 0; i < _routePoints.length - 1; i++) {
        final segmentStart = _routePoints[i];
        final segmentEnd = _routePoints[i + 1];
        
        final distanceToSegment = _distanceToLineSegment(
          checkpointLocation, segmentStart, segmentEnd
        );
        
        if (distanceToSegment <= _proximityRadius) {
          isNearRoute = true;
          break;
        }
      }
      
      if (isNearRoute) {
        _nearbyCheckpoints.add(checkpoint);
      }
    }
    
    // Sort by distance from current location
    if (_currentLocation != null) {
      _nearbyCheckpoints.sort((a, b) {
        final distanceA = _calculateDistance(
          _currentLocation!,
          LatLng(a.latitude!, a.longitude!)
        );
        final distanceB = _calculateDistance(
          _currentLocation!,
          LatLng(b.latitude!, b.longitude!)
        );
        return distanceA.compareTo(distanceB);
      });
    }
  }

  // Start proximity monitoring
  void _startProximityMonitoring() {
    _proximityTimer?.cancel();
    _proximityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkCheckpointProximity();
    });
  }

  // Check proximity to checkpoints
  void _checkCheckpointProximity() {
    if (_currentLocation == null || _nearbyCheckpoints.isEmpty) return;
    
    for (final checkpoint in _nearbyCheckpoints) {
      if (checkpoint.latitude == null || checkpoint.longitude == null) continue;
      
      final checkpointLocation = LatLng(checkpoint.latitude!, checkpoint.longitude!);
      final distance = _calculateDistance(_currentLocation!, checkpointLocation);
      
      // If within 1km, send notification
      if (distance <= _proximityRadius) {
        _sendCheckpointNotification(checkpoint, distance);
      }
    }
  }

  // Send checkpoint notification
  Future<void> _sendCheckpointNotification(Checkpoint checkpoint, double distance) async {
    final distanceKm = (distance / 1000).toStringAsFixed(1);
    
    String statusEmoji = '🟡';
    String statusColor = 'أصفر';
    
    switch (checkpoint.status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        statusEmoji = '🟢';
        statusColor = 'أخضر';
        break;
      case 'مغلق':
        statusEmoji = '🔴';
        statusColor = 'أحمر';
        break;
      case 'ازدحام':
        statusEmoji = '🟠';
        statusColor = 'برتقالي';
        break;
    }
    
    const androidDetails = AndroidNotificationDetails(
      'checkpoint_alerts',
      'تنبيهات الحواجز',
      channelDescription: 'تنبيهات عند الاقتراب من الحواجز',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'حاجز قريب',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notificationsPlugin.show(
      checkpoint.id.hashCode,
      '$statusEmoji حاجز قريب - ${checkpoint.name}',
      'المسافة: ${distanceKm}كم | الحالة: ${checkpoint.status}',
      details,
    );
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Calculate distance from point to line segment
  double _distanceToLineSegment(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final Distance distance = Distance();
    
    // Convert to meters for calculation
    final lineLength = distance.as(LengthUnit.Meter, lineStart, lineEnd);
    
    if (lineLength == 0) {
      return distance.as(LengthUnit.Meter, point, lineStart);
    }
    
    // Calculate the projection of the point onto the line
    final t = ((point.latitude - lineStart.latitude) * (lineEnd.latitude - lineStart.latitude) +
              (point.longitude - lineStart.longitude) * (lineEnd.longitude - lineStart.longitude)) /
             (pow(lineEnd.latitude - lineStart.latitude, 2) + pow(lineEnd.longitude - lineStart.longitude, 2));
    
    final tClamped = t.clamp(0.0, 1.0);
    
    final projection = LatLng(
      lineStart.latitude + tClamped * (lineEnd.latitude - lineStart.latitude),
      lineStart.longitude + tClamped * (lineEnd.longitude - lineStart.longitude),
    );
    
    return distance.as(LengthUnit.Meter, point, projection);
  }

  // Get popular destinations
  List<LatLng> getPopularDestinations() {
    return [
      const LatLng(32.2211, 35.2544), // نابلس
      const LatLng(31.9074, 35.2033), // القدس
      const LatLng(31.5326, 35.0998), // الخليل
      const LatLng(32.5055, 35.2969), // جنين
      const LatLng(31.4065, 35.0390), // بيت لحم
      const LatLng(32.0181, 34.7713), // يافا
      const LatLng(32.9408, 35.3033), // حيفا
      const LatLng(32.7940, 35.2044), // طولكرم
    ];
  }

  // Get destination name by coordinates
  String getDestinationName(LatLng destination) {
    final destinations = {
      const LatLng(32.2211, 35.2544): 'نابلس',
      const LatLng(31.9074, 35.2033): 'القدس',
      const LatLng(31.5326, 35.0998): 'الخليل',
      const LatLng(32.5055, 35.2969): 'جنين',
      const LatLng(31.4065, 35.0390): 'بيت لحم',
      const LatLng(32.0181, 34.7713): 'يافا',
      const LatLng(32.9408, 35.3033): 'حيفا',
      const LatLng(32.7940, 35.2044): 'طولكرم',
    };
    
    // Find closest match
    double minDistance = double.infinity;
    String closestName = 'وجهة غير معروفة';
    
    for (final entry in destinations.entries) {
      final distance = _calculateDistance(destination, entry.key);
      if (distance < minDistance && distance < 5000) { // Within 5km
        minDistance = distance;
        closestName = entry.value;
      }
    }
    
    return closestName;
  }

  // Dispose resources
  void dispose() {
    stopLocationTracking();
    stopNavigation();
  }
}*/
