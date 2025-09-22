import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';

import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_in_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_out_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_up_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_user_by_id_usecase.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final SignInUsecase signInUsecase;
  final SignUpUsecase signUpUsecase;
  final SignOutUsecase signOutUsecase;

  final GetUserByIdUsecase getUserByIdUsecase;

  AuthCubit({
    required this.signInUsecase,
    required this.signUpUsecase,
    required this.signOutUsecase,
    required this.getUserByIdUsecase,
  }) : super(AuthInitial());
  Future<void> checkAuthStatus() async {
    try {
      emit(AuthLoading());
      debugPrint("🔵 [AuthCubit] Checking auth status...");

      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        debugPrint(
          "✅ [AuthCubit] FirebaseAuth user exists: ${currentUser.uid}",
        );

        final user = await getUserByIdUsecase.call(currentUser.uid);

        if (user != null) {
          debugPrint("✅ [AuthCubit] Firestore user loaded: $user");
          emit(AuthSignedIn(user));
        } else {
          debugPrint("❌ [AuthCubit] User profile not found in Firestore");
          emit(const AuthError("User profile not found in Firestore"));
        }
      } else {
        debugPrint("❌ [AuthCubit] No FirebaseAuth user");
        emit(AuthSignedOut());
      }
    } catch (e, stack) {
      debugPrint("🔥 [AuthCubit] checkAuthStatus failed: $e");
      debugPrint("$stack");
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signIn(String email, String password, String role) async {
    try {
      emit(AuthLoading());
      debugPrint("🔵 [AuthCubit] Attempting sign in with: $email, role: $role");

      final user = await signInUsecase.call(email, password, role);

      if (user != null) {
        debugPrint("✅ [AuthCubit] Signed in: ${user.uid}, role: ${user.role}");
        emit(AuthSignedIn(user));
      } else {
        debugPrint(
          "❌ [AuthCubit] User returned null (Firestore missing or role mismatch)",
        );
        emit(const AuthError("User not found in Firestore or role mismatch"));
      }
    } catch (e, stack) {
      debugPrint("🔥 [AuthCubit] Sign in failed: $e");
      debugPrint("$stack");
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      emit(AuthLoading());
      final uid = await signUpUsecase.call(email, password); // must return uid
      emit(AuthSignedUp(uid));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signOut() async {
    try {
      await signOutUsecase.call();
      emit(AuthSignedOut());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
