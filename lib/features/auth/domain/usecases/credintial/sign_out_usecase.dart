import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class SignOutUsecase {
  final UserRepository repository;
  SignOutUsecase({required this.repository});

  Future<void> call() async => await repository.signOut();
}
