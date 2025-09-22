import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/presentation/cubit/auth/auth_cubit.dart';
import 'package:taxi_app/features/auth/presentation/cubit/user/user_cubit.dart';
import 'package:taxi_app/features/passenger/presentation/cubit/ride_cubit.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/routes/app_routes.dart';
import 'package:taxi_app/services/location_services.dart';
import 'package:taxi_app/services/routing_services.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  String? currentId;
  final List<String> _declinedRideIds = []; // Track declined rides locally
  List<LatLng> polyline = [];

  // Navigation state variables
  bool _isNavigating = false;
  LatLng? _navigationTarget;
  List<LatLng> _navigationPolyline = [];
  String _navigationStatus = "Not navigating";
  List<RideEntity> availableRides = [];
  List<RideEntity> activeRides = [];

  StreamSubscription? _rideCubitSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentId();
    _loadCurrentLocation();
    _listenToRideCubit();
    initFlutterNotification();

    context.read<RideCubit>().streamAvailableRides();
    if (currentId != null) {
      context.read<RideCubit>().streamDriverActiveRides(currentId!);
    }
    context.read<UserCubit>().getUser();
  }

  Future<void> _loadCurrentId() async {
    final uid = await context.read<UserCubit>().getCurrentUserId();
    setState(() {
      debugPrint('🔵 [DriverHome] Current user ID: $uid');
      currentId = uid;
    });
    context.read<RideCubit>().streamAvailableRides();
    context.read<RideCubit>().streamDriverActiveRides(uid);
  }

  Future<void> _loadCurrentLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    }
    LocationService.getLocationStream().listen((position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (currentId != null) {
          context.read<UserCubit>().updateUserLocation(
            currentId!,
            _currentLocation!,
          );
        }
      });
    });
  }

  void _listenToRideCubit() {
    _rideCubitSubscription?.cancel();
    _rideCubitSubscription = context.read<RideCubit>().stream.listen((state) {
      if (state is RideAccepted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _showRideAccepted();
        });
      } else if (state is RideUpdated && state.ride.status == 'accepted') {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _showRideAccepted();
        });
      } else if (state is ActiveRidesLoaded && mounted) {
        activeRides = state.rides;
        debugPrint('🔵 [DriverHome] Active rides: $activeRides');
        if (activeRides.isNotEmpty) {
          _updateNavigationStatus(state.rides.first);
        }
      } else if (state is RideDriverCancelled) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          activeRides.removeWhere((ride) => ride.rideId == state.rideId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ride cancelled"),
              backgroundColor: Colors.red,
            ),
          );
        });
      } else if (state is RideError) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(" RideError: ${state.message}"),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    });
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Show custom notification
        notificationsPlugin.show(
          0,
          message.notification!.title,
          message.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',
              'channel_name',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _rideCubitSubscription?.cancel();
    super.dispose();
  }

  Future<void> initFlutterNotification() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await notificationsPlugin.initialize(initializationSettings);
  }

  void _fitMapToRoute() {
    if (_navigationPolyline.isEmpty) return;

    // Calculate bounds
    double minLat = _navigationPolyline[0].latitude;
    double maxLat = _navigationPolyline[0].latitude;
    double minLng = _navigationPolyline[0].longitude;
    double maxLng = _navigationPolyline[0].longitude;

    for (final point in _navigationPolyline) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add padding
    final padding = 0.05; // Adjust as needed
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    // Create bounds and fit map
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
  }

  Future<void> _startNavigationToTarget(LatLng target, String status) async {
    if (_currentLocation == null) return;

    try {
      final route = await RoutingService.getRoutes(_currentLocation!, target);

      if (route.isNotEmpty) {
        setState(() {
          _navigationTarget = target;
          _navigationPolyline = route[0]['polyline'];
          _navigationStatus = status;
          polyline = _navigationPolyline;
        });

        _fitMapToRoute();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Navigation update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateNavigationStatus(RideEntity activeRide) {
    if (!_isNavigating) return;

    if (activeRide.status == 'in_progress' &&
        _navigationTarget != activeRide.destinationLocation) {
      // Update navigation to destination
      _startNavigationToTarget(
        activeRide.destinationLocation,
        "Navigating to destination",
      );
    } else if (activeRide.status == 'completed') {
      // Stop navigation
      setState(() {
        _isNavigating = false;
        _navigationTarget = null;
        _navigationPolyline = [];
        _navigationStatus = "Ride completed";
        polyline = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ride completed!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: BlocBuilder<UserCubit, UserState>(
        builder: (context, userState) {
          bool isOnline = false;
          if (userState is UserLoaded) {
            debugPrint('🔵 [DriverHome] User loaded: $userState');
            currentId = userState.user.uid;
            isOnline = userState.user.isOnline ?? false;
          } else if (userState is UserStatusUpdated) {
            debugPrint('🔵 [DriverHome] User status updated: $userState');
            isOnline = userState.isOnline;
          } else if (userState is UserError) {
            debugPrint('🔵 [DriverHome] User error: ${userState.message}');
            return Center(child: Text(" UserError:  ${userState.message}"));
          } else if (userState is UserLocationUpdated) {
            debugPrint('🔵 [DriverHome] User location updated: $userState');
            context.read<UserCubit>().getUser();
            _currentLocation = userState.location;
          } else {
            debugPrint('🔵 [DriverHome] User state: $userState');
            return const Center(child: CircularProgressIndicator());
          }
          return BlocBuilder<RideCubit, RideState>(
            builder: (context, rideState) {
              // ignore: unused_local_variable

              if (rideState is AvailableRidesLoaded) {
                availableRides = rideState.rides
                    .where((ride) => !_declinedRideIds.contains(ride.rideId))
                    .toList();
              } else if (rideState is ActiveRidesLoaded) {
                activeRides = rideState.rides;
                debugPrint('🔵 [DriverHome] Active rides: $activeRides');
                if (activeRides.isNotEmpty) {
                  _updateNavigationStatus(activeRides.first);
                }
              } else if (rideState is RideAccepted) {
                activeRides = [rideState.ride];
                _updateNavigationStatus(rideState.ride);
              } else if (rideState is RideError) {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(" RideError: ${rideState.message}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              }
              return Stack(
                children: [
                  // Map
                  _currentLocation == null
                      ? const Center(child: CircularProgressIndicator())
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentLocation!,
                            initialZoom: 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                              userAgentPackageName: "com.example.taxi_app",
                            ),
                            if (polyline.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: polyline,
                                    strokeWidth: 4.0,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                if (_currentLocation != null)
                                  Marker(
                                    point: _currentLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.local_taxi,
                                      color: Colors.black,
                                      size: 40,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                  // Navigation Status Indicator
                  if (_isNavigating)
                    Positioned(
                      top: 120,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.navigation, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _navigationStatus,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isNavigating = false;
                                  _navigationTarget = null;
                                  _navigationPolyline = [];
                                  _navigationStatus = "Navigation stopped";
                                  polyline = [];
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Online/Offline Toggle
                  Positioned(
                    top: 40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () {
                              _scaffoldKey.currentState?.openDrawer();
                              context.read<UserCubit>().getUser();
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 50,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: isOnline ? Colors.green : Colors.red,
                              ),
                              child: Text(
                                isOnline ? 'You\'re Online' : 'You\'re Offline',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Switch(
                            value: isOnline,
                            onChanged: (value) {
                              if (currentId != null) {
                                context.read<UserCubit>().updateUserStatus(
                                  currentId!,
                                  value,
                                );
                              }
                              if (value) _showOnlineSuccess();
                            },
                            activeThumbColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Sheet
                  DraggableScrollableSheet(
                    initialChildSize: 0.4,
                    minChildSize: 0.4,
                    maxChildSize: 0.7,
                    builder: (context, scrollController) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag Handle
                            Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Status Section
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 100),
                              child: _buildStatusSection(isOnline),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: _buildRideRequestsView(
                                scrollController,
                                isOnline,
                                activeRides,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.online_prediction : Icons.offline_bolt,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isOnline
                      ? 'Ready to accept rides'
                      : 'Go online to start earning',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideRequestsView(
    ScrollController scrollController,
    bool isOnline,
    List<RideEntity> rideRequests,
  ) {
    if (!isOnline) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.offline_bolt, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 20),
              const Text(
                'Go online to receive ride requests',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    if (rideRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_crash, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 20),
            const Text(
              'No ride requests available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: rideRequests.length,
      itemBuilder: (context, index) {
        final request = rideRequests[index];
        if (request.status == 'accepted') {
          return _buildActiveRideView(request);
        }
        return _buildRideRequestCard(request);
      },
    );
  }

  Widget _buildRideRequestCard(RideEntity request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger Info
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.black,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.passengerName ?? 'Passenger',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Omit rating since it's not in RideEntity
                    Text(
                      request.passengerId,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${request.fare?.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    request.distance ?? 'N/A',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          // Route Info
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(height: 30, width: 2, color: Colors.grey[400]),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup: (${request.pickupLocation.latitude.toStringAsFixed(4)}, ${request.pickupLocation.longitude.toStringAsFixed(4)})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Destination: (${request.destinationLocation.latitude.toStringAsFixed(4)}, ${request.destinationLocation.longitude.toStringAsFixed(4)})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _declinedRideIds.add(request.rideId!);
                      context.read<RideCubit>().cancelRideForDriver(
                        request.rideId!,
                      );
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (currentId != null) {
                      context.read<RideCubit>().acceptRide(request.rideId!);
                      _showRideAccepted();
                      context.read<RideCubit>();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRideView(RideEntity activeRide) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ride Status
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.green, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Active Ride: ${activeRide.rideId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              _showPaassengerInformation(activeRide);
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      activeRide.passengerName ?? 'Passenger',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${activeRide.fare?.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        activeRide.distance ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Navigation Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (mounted && activeRide.status == 'accepted') {
                  // Determine navigation target based on ride status
                  LatLng target = activeRide.pickupLocation;
                  String status = "Navigating to pickup location";

                  // If ride is in progress, navigate to destination
                  if (activeRide.status == 'in_progress') {
                    target = activeRide.destinationLocation;
                    status = "Navigating to destination";
                  }

                  try {
                    // Get route from current location to target
                    if (_currentLocation != null) {
                      final route = await RoutingService.getRoutes(
                        _currentLocation!,
                        target,
                      );

                      if (route.isNotEmpty) {
                        setState(() {
                          _isNavigating = true;
                          _navigationTarget = target;
                          _navigationPolyline = route[0]['polyline'];
                          _navigationStatus = status;
                          polyline = _navigationPolyline;
                          debugPrint('Navigation started: $status');
                          debugPrint('Polyline updated: $polyline');
                        });

                        // Fit map to show the entire route
                        _fitMapToRoute();

                        // Show navigation started message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(status),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to start navigation: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isNavigating ? 'Navigation in Progress' : 'Start Navigation',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPaassengerInformation(RideEntity activeRide) async {
    final passenger = await context.read<UserCubit>().getUserById(
      activeRide.passengerId,
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              passenger.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
             
            ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPassengerAction(Icons.call, "Call", Colors.green, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Calling driver")),
                  );
                }),
                _buildPassengerAction(
                  Icons.message,
                  "Message",
                  Colors.blue,
                  () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Opening messaging app")),
                    );
                  },
                ),
                _buildPassengerAction(
                  Icons.share_location,
                  "Share",
                  Colors.purple,
                  () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Sharing ride status")),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSignedOut) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.choicePage,
            (_) => false,
          );
        } else if (state is AuthError) {
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(" Auth Error  ${state.message}"),
                backgroundColor: Colors.red,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        return BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              debugPrint('🔵 [UserCubit] User loading...');
              return const Center(child: CircularProgressIndicator());
            } else if (state is UserLoaded) {
              debugPrint('🔵 [UserCubit Driver Home] User loaded: $state');
              return Drawer(
                child: Container(
                  color: Colors.black,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () async {
                          Navigator.pushNamed(context, AppRoutes.editProfile);
                        },
                        child: UserAccountsDrawerHeader(
                          accountName: Text(
                            state.user.name,
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          accountEmail: Text(
                            state.user.email,
                            style: TextStyle(color: Colors.white70),
                          ),
                          currentAccountPicture: const CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              color: Colors.black,
                              size: 30,
                            ),
                          ),
                          decoration: BoxDecoration(color: Colors.grey[900]),
                        ),
                      ),
                      _buildDrawerItem(
                        Icons.home,
                        'Home',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.history,
                        'Ride History',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.attach_money,
                        'Earnings',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.star,
                        'Ratings',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.car_repair,
                        'Vehicle Info',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.document_scanner,
                        'Documents',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.support_agent,
                        'Support',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.settings,
                        'Settings',
                        () => Navigator.pop(context),
                      ),
                      const Divider(color: Colors.white30),
                      _buildDrawerItem(Icons.logout, 'Logout', _logout),
                    ],
                  ),
                ),
              );
            } else if (state is UserError) {
              debugPrint('🔵 [UserCubit] User error: ${state.message}');
              return Center(
                child: Container(
                  color: Colors.black,
                  child: Text(" UserError: ${state.message}"),
                ),
              );
            }
            debugPrint('🔵 [UserCubit] User state: $state');
            return Container();
          },
        );
      },
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  void _showOnlineSuccess() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are now online and ready to receive rides!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  void _showRideAccepted() {
    debugPrint('Ride accepted!');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride accepted! Navigate to pickup location.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthCubit>().signOut();
              context.read<UserCubit>().updateUserStatus(currentId!, false);
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.choicePage,
                  (_) => false,
                );
                setState(() {
                  _declinedRideIds.clear();
                  _isNavigating = false;
                  _navigationTarget = null;
                  _navigationPolyline = [];
                  _navigationStatus = "Navigation stopped";
                  polyline = [];
                  activeRides.clear();
                  availableRides.clear();
                  _currentLocation = null;
                });
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
