import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class GetUserByIdUsecase {
  final UserRepository repository;

  GetUserByIdUsecase({required this.repository});
  Future<UserEntity?> call(String uid) async {
    return await repository.getUserById(uid);
  }
}
