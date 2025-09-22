import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class UpdateDriverStatusUsecase {
  final UserRepository repository;
  UpdateDriverStatusUsecase({required this.repository});

  Future<void> call(String uid, bool isOnline) async {
    return await repository.updateDriverStatus(uid, isOnline);
  }
}
