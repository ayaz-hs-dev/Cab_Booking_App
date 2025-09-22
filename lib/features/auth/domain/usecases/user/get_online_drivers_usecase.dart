import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/domain/entities/user_entity.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class GetOnlineDriversUsecase {
  final UserRepository repository;

  GetOnlineDriversUsecase({required this.repository});
  Stream<List<UserEntity>> call(LatLng center, double radiusInKm) {
    return repository.getOnlineDrivers(center, radiusInKm);
  }
}
