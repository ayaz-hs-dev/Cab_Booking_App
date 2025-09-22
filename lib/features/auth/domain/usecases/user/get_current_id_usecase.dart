import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class GetCurrentIdUsecase {
  final UserRepository repository;

  GetCurrentIdUsecase({required this.repository});

  Future<String> call() async => await repository.getCurrentUserId();
}
