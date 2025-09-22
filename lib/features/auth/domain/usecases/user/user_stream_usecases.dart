import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class UserStreamUsecases {
  final UserRepository repository;
  UserStreamUsecases({required this.repository});

  Stream<UserEntity> call(String uid) => repository.userStream(uid);
}
