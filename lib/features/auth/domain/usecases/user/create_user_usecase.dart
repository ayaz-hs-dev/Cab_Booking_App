import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class CreateUserUsecase {
  final UserRepository repository;

  CreateUserUsecase({required this.repository});
  Future<void> call(UserEntity user) async {
    return await repository.createUser(user);
  }
}
