import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/create_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/delete_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_current_id_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_online_drivers_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_user_by_id_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_driver_status_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_user_location_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/user_stream_usecases.dart';

part 'user_state.dart';

class UserCubit extends Cubit<UserState> {
  final CreateUserUsecase createUserUsecase;
  final DeleteUserUsecase deleteUserUsecase;
  final GetCurrentIdUsecase getCurrentIdUsecase;
  final GetOnlineDriversUsecase getOnlineDriversUsecase;
  final GetUserByIdUsecase getUserByIdUsecase;
  final UpdateDriverStatusUsecase updateDriverStatusUsecase;
  final UpdateUserUsecase updateUserUsecase;
  final UpdateUserLocationUsecase updateUserLocationUsecase;
  final UserStreamUsecases userStreamUsecases;

  UserCubit({
    required this.createUserUsecase,
    required this.deleteUserUsecase,
    required this.getCurrentIdUsecase,
    required this.getOnlineDriversUsecase,
    required this.getUserByIdUsecase,
    required this.updateDriverStatusUsecase,
    required this.updateUserUsecase,
    required this.updateUserLocationUsecase,
    required this.userStreamUsecases,
  }) : super(UserInitial());

  StreamSubscription<UserEntity>? _userSubscription;
  StreamSubscription<List<UserEntity>>? _driversSubscription;

  // ---------- USER CRUD ----------
  Future<void> createUser(UserEntity user) async {
    emit(UserLoading());
    try {
      await createUserUsecase.call(user);
      emit(UserCreated());
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<UserEntity> getUser() async {
    emit(UserLoading());
    try {
      final id = await getCurrentIdUsecase.call();
      streamUser(id);
      final user = await getUserByIdUsecase.call(id);
      if (user != null) {
        debugPrint('[UserCubit GetUser] ✅ User fetched: $user');
        emit(UserLoaded(user));
        return user;
      } else {
        emit(const UserError("User not found"));
        return UserEntity(name: '', email: '', phone: '');
      }
    } catch (e) {
      emit(UserError(e.toString()));
      return UserEntity(name: '', email: '', phone: '');
    }
  }

  Future<UserEntity> getUserById(String uid) async {
    try {
      final user = await getUserByIdUsecase.call(uid);
      if (user != null) {
        return user;
      } else {
        emit(const UserError("User not found"));
        return UserEntity(name: '', email: '', phone: '');
      }
    } catch (e) {
      emit(UserError(e.toString()));
      return UserEntity(name: '', email: '', phone: '');
    }
  }

  Future<String> getCurrentUserId() async => await getCurrentIdUsecase.call();

  Future<void> updateUser(UserEntity user) async {
    emit(UserLoading());
    try {
      await updateUserUsecase.call(user);
      emit(UserUpdated());
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<void> deleteUser() async {
    emit(UserLoading());
    try {
      final uid = await getCurrentIdUsecase.call();
      await deleteUserUsecase.call(uid);
      emit(UserDeleted());
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<void> updateUserRideStatus(String uid, bool isOnline) async {
    emit(UserLoading());
    try {
      final currentUser = await getUserByIdUsecase.call(uid);
      if (currentUser != null) {
        await updateDriverStatusUsecase.call(uid, isOnline);
        emit(UserStatusUpdated(isOnline));
      } else {
        emit(const UserError("User not found"));
      }
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<void> updateUserStatus(String uid, bool isOnline) async {
    try {
      await updateDriverStatusUsecase.call(uid, isOnline);
      emit(UserStatusUpdated(isOnline));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  Future<void> updateUserLocation(String uid, LatLng location) async {
    try {
      await updateUserLocationUsecase.call(uid, location);
      emit(UserLocationUpdated(location));
    } catch (e) {
      emit(UserError(e.toString()));
    }
  }

  void streamOnlineDrivers(LatLng center, double radiusInKm) {
    _driversSubscription?.cancel();
    emit(UserLoading());
    _driversSubscription = getOnlineDriversUsecase
        .call(center, radiusInKm)
        .listen(
          (drivers) {
            emit(OnlineDriversLoaded(drivers));
          },
          onError: (e) {
            emit(UserError(e.toString()));
          },
        );
  }

  void streamUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription = userStreamUsecases
        .call(uid)
        .listen(
          (user) {
            emit(UserLoaded(user));
          },
          onError: (e) {
            emit(UserError(e.toString()));
          },
        );
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    _driversSubscription?.cancel();
    return super.close();
  }
}
