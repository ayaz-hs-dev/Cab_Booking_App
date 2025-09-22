part of 'user_cubit.dart';

sealed class UserState extends Equatable {
  const UserState();
}

final class UserInitial extends UserState {
  @override
  List<Object> get props => [];
}

class UserLoading extends UserState {
  @override
  List<Object?> get props => [];
}

class UserCreated extends UserState {
  @override
  List<Object?> get props => [];
}

class UserUpdated extends UserState {
  @override
  @override
  List<Object?> get props => [];
}

class UserDeleted extends UserState {
  @override
  @override
  List<Object?> get props => [];
}

class UserLoaded extends UserState {
  final UserEntity user;
  const UserLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

class UserStatusUpdated extends UserState {
  final bool isOnline;
  const UserStatusUpdated(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class UserLocationUpdated extends UserState {
  final LatLng location;
  const UserLocationUpdated(this.location);

  @override
  List<Object?> get props => [location];
}

class OnlineDriversLoaded extends UserState {
  final List<UserEntity> drivers;
  const OnlineDriversLoaded(this.drivers);

  @override
  List<Object?> get props => [drivers];
}

class UserError extends UserState {
  final String message;
  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}
