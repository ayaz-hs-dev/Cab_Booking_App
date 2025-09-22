part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();
}

final class AuthInitial extends AuthState {
  @override
  List<Object> get props => [];
}

final class AuthLoading extends AuthState {
  @override
  List<Object> get props => [];
}

class AuthSignedUp extends AuthState {
  final String uid; // 🔹 add uid for creating user in Firestore

  const AuthSignedUp(this.uid);
  @override
  List<Object> get props => [uid];
}

class AuthSignedIn extends AuthState {
  final UserEntity? user;
  const AuthSignedIn(this.user);
  @override
  List<Object> get props => [user!];
}

class AuthSignedOut extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
