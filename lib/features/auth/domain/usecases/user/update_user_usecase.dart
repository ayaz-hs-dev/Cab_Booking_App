import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class UpdateUserUsecase {
  final UserRepository repository;

  UpdateUserUsecase({required this.repository});

  Future<void> call(UserEntity user) async {
    return await repository.updateUser(user);
  }
}
