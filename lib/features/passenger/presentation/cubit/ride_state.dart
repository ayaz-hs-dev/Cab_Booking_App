part of 'ride_cubit.dart';

sealed class RideState extends Equatable {
  const RideState();
}

final class RideInitial extends RideState {
  @override
  List<Object> get props => [];
}

class RideLoading extends RideState {
  @override
  List<Object?> get props => [];
}

class RideRequested extends RideState {
  final RideEntity ride;
  const RideRequested(this.ride);

  @override
  List<Object?> get props => [ride];
}

class RideUpdated extends RideState {
  final RideEntity ride;
  const RideUpdated(this.ride);

  @override
  List<Object?> get props => [ride];
}

class RideCancelled extends RideState {
  @override
  List<Object?> get props => [];
}

class RideDriverCancelled extends RideState {
  final String rideId;
  const RideDriverCancelled(this.rideId);

  @override
  List<Object?> get props => [rideId];
}

class RideError extends RideState {
  final String message;
  const RideError(this.message);

  @override
  List<Object?> get props => [message];
}

class RideHistoryLoaded extends RideState {
  final List<RideEntity> rides;
  const RideHistoryLoaded(this.rides);

  @override
  List<Object?> get props => [rides];
}

class AvailableRidesLoaded extends RideState {
  final List<RideEntity> rides;
  const AvailableRidesLoaded(this.rides);

  @override
  List<Object?> get props => [rides];
}

class ActiveRidesLoaded extends RideState {
  final List<RideEntity> rides;
  const ActiveRidesLoaded(this.rides);

  @override
  List<Object?> get props => [rides];
}

class RideAccepted extends RideState {
  final RideEntity ride;
  const RideAccepted(this.ride);

  @override
  List<Object?> get props => [ride];
}
