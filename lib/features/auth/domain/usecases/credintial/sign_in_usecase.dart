import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class SignInUsecase {
  final UserRepository userRepository;

  SignInUsecase({required this.userRepository});
  Future<UserEntity?> call(String email, String password, String role) async {
    return await userRepository.signInWithEmailAndPassword(
      email,
      password,
      role,
    );
  }
}
