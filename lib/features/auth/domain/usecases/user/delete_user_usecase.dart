import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class DeleteUserUsecase {
  final UserRepository repository;

  DeleteUserUsecase({required this.repository});
  Future<void> call(String uid) async {
    return await repository.deleteUser(uid);
  }
}
