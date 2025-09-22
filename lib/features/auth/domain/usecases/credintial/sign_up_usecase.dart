import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class SignUpUsecase {
  final UserRepository repository;

  SignUpUsecase({required this.repository});

  Future<String> call(String email, String password) async {
    return await repository.signUpWithEmailAndPassword(email, password);
  }
}
