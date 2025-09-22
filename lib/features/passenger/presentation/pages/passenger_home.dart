import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/data/model/user_model.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/presentation/cubit/auth/auth_cubit.dart';
import 'package:taxi_app/features/auth/presentation/cubit/user/user_cubit.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/presentation/cubit/ride_cubit.dart';
import 'package:taxi_app/routes/app_routes.dart';
import 'package:taxi_app/services/location_services.dart';
import 'package:taxi_app/services/places_services.dart';
import 'package:taxi_app/services/routing_services.dart';

class PassengerHome extends StatefulWidget {
  const PassengerHome({super.key});

  @override
  State<PassengerHome> createState() => _PassengerHomeState();
}

class _PassengerHomeState extends State<PassengerHome> {
  static const _timeoutDuration = Duration(seconds: 120);
  static const _driverRefreshInterval = Duration(seconds: 30);
  static const _locationRetryInterval = Duration(
    seconds: 10,
  ); // New: Retry location if failed

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  String? _selectedDestination;
  // ignore: unused_field
  bool _isDestinationSet = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _routes = [];
  int? _selectedRouteIndex;
  RideCubit? _rideCubit;
  bool _isBookingRide = false;
  bool _hasActiveRide = false;
  UserEntity? _activeDriver;
  RideEntity? _activeRide;
  int? _selectedDriverIndex;
  bool _showSearchContainer = false;
  Timer? _timeoutTimer;
  Timer? _driverRefreshTimer;
  Timer? _locationRetryTimer; // New: Timer for retrying location
  int _remainingSeconds = _timeoutDuration.inSeconds;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _rideCubitSubscription;
  StreamSubscription? _historySubscription;
  bool _isMapReady = false;
  List<UserEntity>? _drivers;
  String? _currentUserId;
  // ignore: unused_field
  String? _passengerName;

  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();

    _getCurrentId();
    final userCubit = context.read<UserCubit>();
    userCubit.getUser();
    _rideCubit = context.read<RideCubit>();
    _streamPassengerRides();
    _listenToRideCubit();
    _startDriverRefreshTimer();
    _startLocationRetryTimer(); // New: Start location retry timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentLocation != null && !_isMapReady) {
        _isMapReady = true;
        _mapController.move(_currentLocation!, 15);
      }
    });
  }

  void _startDriverRefreshTimer() {
    _driverRefreshTimer?.cancel();
    _driverRefreshTimer = Timer.periodic(_driverRefreshInterval, (timer) {
      if (mounted && !_hasActiveRide && _currentLocation != null) {
        debugPrint('🔄 Refreshing nearby drivers...');
        _streamNearbyDrivers();
      }
    });
  }

  void _startLocationRetryTimer() {
    _locationRetryTimer?.cancel();
    _locationRetryTimer = Timer.periodic(_locationRetryInterval, (timer) {
      if (mounted && _currentLocation == null && !_hasActiveRide) {
        debugPrint('🔄 Retrying to load current location...');
        _loadCurrentLocation();
      }
    });
  }

  void _listenToRideCubit() {
    _rideCubitSubscription?.cancel();
    _rideCubitSubscription = context.read<RideCubit>().stream.listen((state) {
      if (state is RideRequested && mounted) {
        setState(() {
          _hasActiveRide = true;
          _activeRide = state.ride;
        });
        _startTimeoutTimer();
        _showRideConfirmedDialog();
      } else if (state is RideUpdated &&
          mounted &&
          state.ride.status == 'accepted') {
        setState(() {
          _activeRide = state.ride;
          _activeDriver = _drivers?.firstWhere(
            (driver) => driver.uid == state.ride.driverId,
            orElse: () => UserModel(
              uid: state.ride.driverId!,
              name: 'Unknown Driver',
              email: '',
              role: 'driver',
              isOnline: true,
              phone: '',
              token: state.ride.driverToken!,
            ),
          );
          _timeoutTimer?.cancel();
        });
      } else if (state is RideUpdated &&
          mounted &&
          state.ride.status == 'canceled') {
        debugPrint("[PassengerHome] Ride canceled: ${state.ride}");
        setState(() {
          _hasActiveRide = false;
          _activeRide = state.ride;
          _isBookingRide = false;

          _activeDriver = null;
          _selectedDriverIndex = null;
          _timeoutTimer?.cancel();
          _remainingSeconds = _timeoutDuration.inSeconds;
          _driverRefreshTimer?.cancel();
        });
        debugPrint('🔄 Ride cancelled by driver, refreshing nearby drivers...');
        _streamNearbyDrivers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Your ride was declined. Please try booking again.",
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _selectedDriverIndex = null;
                  // Optionally keep destination for retry
                  _destinationLocation = null;
                  _selectedDestination = null;
                  _searchController.clear();
                  _routes = [];
                  _selectedRouteIndex = null;
                });
                _streamNearbyDrivers();
              },
            ),
          ),
        );
      } else if (state is RideCancelled && mounted) {
        // Handle any additional cleanup if needed
        setState(() {
          _hasActiveRide = false;
          _activeRide = null;
          _activeDriver = null;
          _isBookingRide = false;
          _selectedDriverIndex = null;
          _timeoutTimer?.cancel();
          _remainingSeconds = _timeoutDuration.inSeconds;
        });
        debugPrint('🔄 Ride cancelled, refreshing nearby drivers...');
        _streamNearbyDrivers();
      } else if (state is RideError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _streamPassengerRides() async {
    try {
      final userCubit = context.read<UserCubit>();
      final currentUid = await userCubit.getCurrentUserId();
      _historySubscription?.cancel();

      _rideCubit!.loadRideHistory(currentUid);
      _streamRide();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to stream rides: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _streamRide() {
    try {
      final rideId = _activeRide?.rideId;
      if (rideId != null) {
        debugPrint('📡 Streaming ride updates for rideId: $rideId');
        _activeRide = _rideCubit!.rideStream(rideId) as RideEntity?;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to stream ride: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _streamNearbyDrivers() {
    if (_currentLocation == null) {
      debugPrint('⚠️ Cannot stream drivers: currentLocation is null');
      return;
    }
    try {
      debugPrint(
        '📡 Streaming nearby drivers at ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
      );
      final userCubit = context.read<UserCubit>();
      userCubit.streamOnlineDrivers(_currentLocation!, 10);
    } catch (e) {
      debugPrint('❌ Error streaming drivers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to stream drivers: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentId() async {
    final userCubit = context.read<UserCubit>();
    _currentUserId = await userCubit.getCurrentUserId();
    debugPrint('🔵 Current user ID: $_currentUserId');
  }

  @override
  void dispose() {
    if (_hasActiveRide && _activeRide != null) {
      _rideCubit!.cancelRide(_activeRide!.rideId!);
    }
    _searchController.dispose();
    _mapController.dispose();
    _timeoutTimer?.cancel();
    _driverRefreshTimer?.cancel();
    _locationRetryTimer?.cancel(); // New: Cancel location retry timer
    _locationSubscription?.cancel();
    _rideCubitSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      debugPrint('🔵 Loading current location...');
      final position = await LocationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isMapReady = true; // Move this here to ensure map is ready
          debugPrint(
            '✅ Current location set: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
          );
        });
        // Move map only after confirming _isMapReady
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isMapReady && _currentLocation != null) {
            setState(() => _isMapReady = true);
            _mapController.move(_currentLocation!, 15);
          }
        });
        _streamNearbyDrivers();

        _locationSubscription?.cancel();
        _locationSubscription = LocationService.getLocationStream().listen(
          (position) {
            if (mounted) {
              setState(() {
                _currentLocation = LatLng(
                  position.latitude,
                  position.longitude,
                );
                debugPrint(
                  '📍 Location updated: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
                );
                context.read<UserCubit>().updateUserLocation(
                  _currentUserId!,
                  _currentLocation!,
                );
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isMapReady && _currentLocation != null) {
                  setState(() => _isMapReady = true);
                  _mapController.move(_currentLocation!, 15);
                }
              });
              _streamNearbyDrivers();
            }
          },
          onError: (e) {
            debugPrint('❌ Location stream error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Location stream error: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      } else {
        debugPrint('⚠️ No position returned from LocationService');
        // Fallback to user's stored location from Firestore
        final userCubit = context.read<UserCubit>();
        final user = (userCubit.state is UserLoaded)
            ? (userCubit.state as UserLoaded).user
            : null;
        if (user != null && user.currentLocation != null) {
          setState(() {
            _currentLocation = user.currentLocation!;
            _passengerName = user.name;
            debugPrint(
              '✅ Fallback to Firestore location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
            );
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to load location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load location: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleMapLongPress(
    TapPosition tapPosition,
    LatLng point,
  ) async {
    if (_hasActiveRide) return;
    try {
      final place = await PlaceService.reverseGeocode(point);
      if (mounted) {
        setState(() {
          _destinationLocation = point;
          _selectedDestination = place['displayName'] ?? 'Selected Location';
          _isDestinationSet = true;
          _searchController.text = _selectedDestination!;
          _searchResults = [];
          _showSearchContainer = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isMapReady && _currentLocation != null) {
            setState(() => _isMapReady = true);
            _mapController.move(point, 15);
          }
        });
        await _fetchRoutes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to set destination: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchContainer = false;
        });
      }
      return;
    }
    if (!_showSearchContainer && mounted) {
      setState(() => _showSearchContainer = true);
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await PlaceService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Place search failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchRoutes() async {
    if (_currentLocation == null || _destinationLocation == null) return;
    try {
      final routes = await RoutingService.getRoutes(
        _currentLocation!,
        _destinationLocation!,
      );
      if (mounted) {
        setState(() {
          _routes = routes;
          _selectedRouteIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to fetch routes: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    if (mounted) setState(() => _remainingSeconds = _timeoutDuration.inSeconds);
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0 || _activeDriver != null) {
        timer.cancel();
        if (_remainingSeconds <= 0 &&
            _hasActiveRide &&
            _activeDriver == null &&
            mounted) {
          _rideCubit!.cancelRide(_activeRide!.rideId!);
          setState(() {
            _hasActiveRide = false;
            _activeRide = null;
            _isBookingRide = false;
            _remainingSeconds = 0;
          });
        }
      }
    });
  }

  void _bookRide() async {
    if (_hasActiveRide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You already have an active ride"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedDriverIndex == null || _drivers == null || _drivers!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a driver"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedRouteIndex == null || _routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a route"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_destinationLocation == null || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Missing location data"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedDriver = _drivers![_selectedDriverIndex!];
    if (!selectedDriver.isOnline!) {
      if (mounted) {
        setState(() => _isBookingRide = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Selected driver is not available"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isBookingRide = true);
    try {
      final passengerId = await context.read<UserCubit>().getCurrentUserId();
      final selectedRoute = _routes[_selectedRouteIndex!];
      final distance = selectedRoute['distance'];
      // ignore: unused_local_variable
      final duration = selectedRoute['duration'];
      final polyline = selectedRoute['polyline'] as List<LatLng>;

      final fare = RoutingService.calculateFare(distance);
      final passenger = await context.read<UserCubit>().getUser();
      final driver = await context.read<UserCubit>().getUserById(
        selectedDriver.uid!,
      );
      final token = driver.token!;
      debugPrint("[PassengerHome]  Driver : $driver");
      debugPrint("[PassengerHome]  Driver Token: $token");
      debugPrint("[PassengerHome] Passenger Name: ${passenger.name}");
      final ride = RideEntity(
        driverId: selectedDriver.uid,
        driverToken: token,
        passengerId: passengerId,
        pickupLocation: _currentLocation!,
        destinationLocation: _destinationLocation!,
        status: 'pending',
        createdAt: DateTime.now(),
        fare: fare,
        polyline: polyline,
        distance: distance.toString(),
        passengerName: passenger.name,
      );

      _rideCubit!.requestRide(ride);
    } catch (e) {
      if (mounted) {
        setState(() => _isBookingRide = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRideConfirmedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ride Confirmed!'),
        content: const Text(
          'Your ride has been requested. Waiting for a driver to accept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _cancelRide() {
    if (_activeRide == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel your ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rideCubit!.cancelRide(_activeRide!.rideId!);
              setState(() {
                _hasActiveRide = false;
                _activeDriver = null;
                _activeRide = null;
                _isBookingRide = false;
                _remainingSeconds = 0;
                _timeoutTimer?.cancel();
              });
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom == 0;

    return BlocConsumer<UserCubit, UserState>(
      listener: (context, state) {
        if (state is UserLoaded && mounted) {
          setState(() {
            _currentUserId = state.user.uid;
            debugPrint('✅ User loaded: ${state.user.uid}, ${state.user.name}');
          });
        } else if (state is OnlineDriversLoaded && mounted) {
          setState(() {
            _drivers = state.drivers;
            debugPrint('✅ Drivers loaded: ${_drivers?.length ?? 0} drivers');
            if (_drivers!.isEmpty) {
              debugPrint('⚠️ No drivers found within 10km');
            }
          });
        } else if (state is UserError && mounted) {
          debugPrint('❌ UserCubit error: ${state.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, userState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isMapReady && _currentLocation != null) {
            setState(() => _isMapReady = true);
            _mapController.move(_currentLocation!, 15);
          }
        });
        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildDrawer(),
          body: Stack(
            children: [
              _currentLocation == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentLocation!,
                        initialZoom: 15,
                        onLongPress: _hasActiveRide
                            ? null
                            : _handleMapLongPress,
                        onMapReady: () {
                          if (mounted && !_isMapReady) {
                            setState(() {
                              _isMapReady = true;
                              debugPrint('✅ Map is ready');
                              if (_currentLocation != null) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted &&
                                      !_isMapReady &&
                                      _currentLocation != null) {
                                    setState(() => _isMapReady = true);
                                    _mapController.move(_currentLocation!, 15);
                                  }
                                });
                                _streamNearbyDrivers();
                              }
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: "com.example.taxi_app",
                        ),
                        PolylineLayer(
                          polylines: [
                            if (_hasActiveRide &&
                                _activeRide != null &&
                                _activeRide!.polyline != null)
                              Polyline(
                                points: _activeRide!.polyline!,
                                strokeWidth: 6.0,
                                color: Colors.blue,
                              )
                            else
                              ..._routes.asMap().entries.map((entry) {
                                final index = entry.key;
                                final route = entry.value;
                                return Polyline(
                                  points: route['polyline'],
                                  strokeWidth: _selectedRouteIndex == index
                                      ? 6.0
                                      : 4.0,
                                  color: _selectedRouteIndex == index
                                      ? Colors.blue
                                      : Colors.grey.withOpacity(0.5),
                                );
                              }),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (_currentLocation != null)
                              Marker(
                                point: _currentLocation!,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                  size: 50,
                                ),
                              ),
                            if (_destinationLocation != null)
                              Marker(
                                point: _destinationLocation!,
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 50,
                                ),
                              ),
                            if (_drivers != null)
                              ..._drivers!.asMap().entries.map((entry) {
                                final index = entry.key;
                                final driver = entry.value;
                                if (driver.currentLocation == null) {
                                  return null;
                                }
                                return Marker(
                                  point: driver.currentLocation!,
                                  width: 50,
                                  height: 50,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (mounted) {
                                        setState(() {
                                          _selectedDriverIndex = index;
                                          debugPrint(
                                            '🚗 Selected driver: ${driver.name} at index $index',
                                          );
                                        });
                                      }
                                    },
                                    child: Icon(
                                      Icons.directions_car,
                                      color: _selectedDriverIndex == index
                                          ? Colors.blue
                                          : Colors.green,
                                      size: 50,
                                    ),
                                  ),
                                );
                              }).whereType<Marker>(),
                          ],
                        ),
                      ],
                    ),
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
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
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Where to?',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              enabled: !_hasActiveRide,
                              onChanged: _hasActiveRide ? null : _searchPlaces,
                              onSubmitted: (value) {
                                if (value.isNotEmpty &&
                                    !_hasActiveRide &&
                                    mounted) {
                                  setState(() {
                                    _isDestinationSet = true;
                                    _selectedDestination = value;
                                    _searchController.text = value;
                                    _searchResults = [];
                                    _showSearchContainer = false;
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (_currentLocation != null && _isMapReady) {
                                _mapController.move(_currentLocation!, 15);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_showSearchContainer)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: _isSearching
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final place = _searchResults[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.location_on,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      place["displayName"] ?? "",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      if (mounted) {
                                        setState(() {
                                          _selectedDestination =
                                              place["displayName"];
                                          _destinationLocation = LatLng(
                                            place["lat"],
                                            place["lon"],
                                          );
                                          _isDestinationSet = true;
                                          _searchController.text =
                                              place["displayName"];
                                          _searchResults = [];
                                          _showSearchContainer = false;
                                        });
                                        if (_isMapReady) {
                                          _mapController.move(
                                            _destinationLocation!,
                                            15,
                                          );
                                        }
                                        _fetchRoutes();
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
              if (isKeyboardVisible)
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.3,
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
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
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
                            const SizedBox(height: 15),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 60),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedDestination ??
                                          'Select a destination',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_routes.isNotEmpty && !_hasActiveRide) ...[
                              const Text(
                                "Available Routes",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _routes.length,
                                  itemBuilder: (context, index) {
                                    final route = _routes[index];
                                    final isSelected =
                                        _selectedRouteIndex == index;
                                    return GestureDetector(
                                      onTap: () {
                                        if (mounted) {
                                          setState(
                                            () => _selectedRouteIndex = index,
                                          );
                                          if (_isMapReady &&
                                              _destinationLocation != null) {
                                            _mapController.move(
                                              _destinationLocation!,
                                              15,
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.grey[800],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              "Route ${index + 1}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "${route['duration'].toStringAsFixed(1)} min • ${route['distance'].toStringAsFixed(1)} km",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (_hasActiveRide) ...[
                              const Text(
                                "Active Ride Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_activeRide != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Ride Status: ${_activeRide!.status}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Fare: ${_activeRide!.fare?.toStringAsFixed(2)} currency",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Pickup: (${_activeRide!.pickupLocation.latitude.toStringAsFixed(4)}, ${_activeRide!.pickupLocation.longitude.toStringAsFixed(4)})",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Destination: (${_activeRide!.destinationLocation.latitude.toStringAsFixed(4)}, ${_activeRide!.destinationLocation.longitude.toStringAsFixed(4)})",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Created At: ${_activeRide!.createdAt.toString().substring(0, 16)}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              if (_activeDriver != null) ...[
                                InkWell(
                                  onTap: _showDriverOptions,
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.black,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _activeDriver!.name,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 5),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: Text(
                                              "Waiting for a driver to accept your ride... ($_remainingSeconds seconds remaining)",
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          _rideCubit!.cancelRide(
                                            _activeRide!.rideId!,
                                          );
                                          if (mounted) {
                                            setState(() {
                                              _hasActiveRide = false;
                                              _activeRide = null;
                                              _activeDriver = null;
                                              _timeoutTimer?.cancel();
                                              _remainingSeconds =
                                                  _timeoutDuration.inSeconds;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Ride request cancelled. Please try again.",
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Retry Booking',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _cancelRide,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel Ride',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                "Available Drivers",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _drivers == null || _drivers!.isEmpty
                                  ? const Text(
                                      "No drivers available",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    )
                                  : ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                            0.3,
                                      ),
                                      child: ListView.builder(
                                        controller: scrollController,
                                        itemCount: _drivers!.length,
                                        itemBuilder: (context, index) =>
                                            _buildDriverCard(
                                              _drivers![index],
                                              index,
                                            ),
                                      ),
                                    ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isBookingRide || _hasActiveRide
                                      ? null
                                      : _bookRide,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isBookingRide
                                      ? const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        )
                                      : const Text(
                                          'Confirm Ride',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverCard(UserEntity driver, int index) {
    final isSelected = _selectedDriverIndex == index;
    final isOnline = driver.isOnline;
    final distance = _currentLocation != null && driver.currentLocation != null
        ? _calculateDistance(
            _currentLocation!,
            driver.currentLocation!,
          ).toStringAsFixed(1)
        : 'N/A';

    return InkWell(
      onTap: () {
        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("This driver is not available"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (mounted) {
          setState(() => _selectedDriverIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isOnline! ? Colors.grey[300]! : Colors.red),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car,
                color: isSelected ? Colors.blue : Colors.black,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        driver.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        isOnline! ? Icons.circle : Icons.circle_outlined,
                        color: isOnline ? Colors.green : Colors.red,
                        size: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 5),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$distance km away',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverOptions() {
    if (_activeDriver == null) return;
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
              _activeDriver!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  color: _activeDriver!.isOnline! ? Colors.green : Colors.red,
                  size: 12,
                ),
                const SizedBox(width: 5),
                Text(
                  _activeDriver!.isOnline! ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _activeDriver!.isOnline! ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDriverAction(Icons.call, "Call", Colors.green, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Calling driver")),
                  );
                }),
                _buildDriverAction(Icons.message, "Message", Colors.blue, () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Opening messaging app")),
                  );
                }),
                _buildDriverAction(
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

  Widget _buildDriverAction(
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
        if (state is AuthSignedOut && mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.choicePage,
            (route) => false,
          );
        } else if (state is AuthError && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      builder: (context, state) {
        return BlocBuilder<UserCubit, UserState>(
          builder: (context, state) {
            if (state is UserLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is UserLoaded) {
              return Drawer(
                child: Container(
                  color: Colors.black,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.editProfile),
                        child: UserAccountsDrawerHeader(
                          accountName: Text(
                            state.user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          accountEmail: Text(
                            state.user.email,
                            style: const TextStyle(color: Colors.white70),
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
                      _buildDrawerItem(Icons.history, 'Ride History', () {
                        Navigator.pop(context);
                      }),
                      _buildDrawerItem(
                        Icons.payment,
                        'Payment',
                        () => Navigator.pop(context),
                      ),
                      _buildDrawerItem(
                        Icons.notifications,
                        'Notifications',
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
              return Center(
                child: Container(
                  color: Colors.black,
                  child: Text(
                    state.message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            }
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
              context.read<UserCubit>().updateUserStatus(
                _currentUserId!,
                false,
              );
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.choicePage,
                  (_) => false,
                );
                setState(() {
                  _hasActiveRide = false;
                  _activeRide = null;
                  _activeDriver = null;
                  _timeoutTimer?.cancel();
                  _remainingSeconds = _timeoutDuration.inSeconds;
                  _selectedDriverIndex = -1;
                  _selectedRouteIndex = -1;
                  _drivers = null;
                  _currentUserId = null;
                  _isBookingRide = false;
                  _isMapReady = false;
                  _currentLocation = null;
                  _rideCubit = null;

                  _destinationLocation = null;
                  _routes.clear();
                  _searchResults.clear();
                  _searchController.clear();
                  _showSearchContainer = false;
                  _isSearching = false;
                  _isDestinationSet = false;
                  _selectedDestination = null;
                  _remainingSeconds = _timeoutDuration.inSeconds;
                  _timeoutTimer?.cancel();
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
