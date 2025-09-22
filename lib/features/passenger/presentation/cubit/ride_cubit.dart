import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/usecases/assign_driver_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/cancel_ride_usecae.dart';
import 'package:taxi_app/features/passenger/domain/usecases/create_ride_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_available_rides_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_driver_active_rides.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_passenger_rides.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_ride_by_id_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/update_ride_status_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/ride_stream_usecase.dart';

part 'ride_state.dart';

class RideCubit extends Cubit<RideState> {
  final AssignDriverUsecase assignDriverUsecase;
  final CreateRideUsecase createRideUsecase;
  final CancelRideUsecae cancelRideUsecae;
  final GetPassengerRides getPassengerRides;
  final GetRideByIdUsecase getRideByIdUsecase;
  final UpdateRideStatusUsecase updateRideStatusUsecase;
  final RideStreamUsecase rideStreamUsecase;
  final GetAvailableRidesUsecase getAvailableRidesUsecase;
  final GetDriverActiveRideUsecase getDriverActiveRideUsecase;

  StreamSubscription? _rideSubscription;
  StreamSubscription? _availableRidesSubscription;
  StreamSubscription? _activeRidesSubscription;

  RideCubit({
    required this.assignDriverUsecase,
    required this.createRideUsecase,
    required this.cancelRideUsecae,
    required this.getPassengerRides,
    required this.getRideByIdUsecase,
    required this.updateRideStatusUsecase,
    required this.rideStreamUsecase,
    required this.getAvailableRidesUsecase,
    required this.getDriverActiveRideUsecase,
  }) : super(RideInitial());

  /// Request a new ride (for passengers)
  Future<void> requestRide(RideEntity ride) async {
    try {
      emit(RideLoading());
      final rideId = await createRideUsecase(ride);
      final newRide = await getRideByIdUsecase(rideId);
      if (newRide != null) {
        emit(RideRequested(newRide));
        _rideSubscription?.cancel();
        _rideSubscription = rideStream(rideId).listen((ride) {
          if (ride != null) emit(RideUpdated(ride));
        });
      }
    } catch (e) {
      emit(RideError(e.toString()));
    }
  }

  /// Cancel current ride (for passengers)
  Future<void> cancelRide(String rideId) async {
    try {
      emit(RideLoading());
      await updateRideStatusUsecase(rideId, 'canceled');
      final ride = await getRideByIdUsecase(rideId);
      debugPrint("[RideCubit] Ride canceled: $ride");
      if (ride?.status == 'canceled') {
        // emit(RideUpdated(ride!));
        emit(RideCancelled());
      }
    } catch (e) {
      emit(RideError(e.toString()));
    }
  }

  Future<void> cancelRideForDriver(String rideId) async {
    try {
      emit(RideLoading());
      await cancelRideUsecae(rideId);
      final ride = await getRideByIdUsecase(rideId);
      await updateRideStatusUsecase(rideId, 'canceled');
      debugPrint("[RideCubit] Ride canceled: $ride");
      if (ride?.status == 'canceled') {
        emit(RideUpdated(ride!));
        emit(RideCancelled());
        emit(RideDriverCancelled(rideId));
      }
    } catch (e) {
      emit(RideError(e.toString()));
    }
  }

  /// Load ride history for passenger
  Future<void> loadRideHistory(String passengerId) async {
    try {
      emit(RideLoading());
      final rides = await getPassengerRides(passengerId);
      emit(RideHistoryLoaded(rides));
    } catch (e) {
      emit(RideError(e.toString()));
    }
  }

  /// Stream available ride requests for drivers
  void streamAvailableRides() {
    _availableRidesSubscription?.cancel();
    _availableRidesSubscription = getAvailableRidesUsecase().listen(
      (rides) {
        emit(AvailableRidesLoaded(rides));
      },
      onError: (e) {
        emit(RideError(e.toString()));
      },
    );
  }

  /// Stream driver's active rides
  void streamDriverActiveRides(String driverId) {
    debugPrint(
      "[RideCubit] Subscribing to active rides for driverId: $driverId",
    );
    _activeRidesSubscription?.cancel();
    _activeRidesSubscription = getDriverActiveRideUsecase(driverId).listen(
      (rides) {
        debugPrint("[RideCubit] Active rides: $rides");
        emit(ActiveRidesLoaded(rides));
      },
      onError: (e) {
        emit(RideError(e.toString()));
      },
    );
  }

  /// Accept a ride request
  Future<void> acceptRide(String rideId) async {
    try {
      emit(RideLoading());
      await updateRideStatusUsecase(rideId, 'accepted');
      final ride = await getRideByIdUsecase(rideId);
      debugPrint("[RideCubit] Ride accepted: $ride");
      if (ride != null) {
        emit(RideAccepted(ride));
      }
    } catch (e) {
      emit(RideError(e.toString()));
    }
  }

  Stream<RideEntity?> rideStream(String rideId) {
    try {
      debugPrint("[RideCubit] Subscribing to ride stream for rideId: $rideId");
      return rideStreamUsecase(rideId);
    } catch (e) {
      debugPrint("[RideCubit] Error subscribing to ride stream: $e");
      emit(RideError(e.toString()));
      return Stream.value(null);
    }
  }

  @override
  Future<void> close() {
    _rideSubscription?.cancel();
    _availableRidesSubscription?.cancel();
    _activeRidesSubscription?.cancel();
    return super.close();
  }
}
