import 'package:latlong2/latlong.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';

class UpdateUserLocationUsecase {
  final UserRepository repository;

  UpdateUserLocationUsecase({required this.repository});

  Future<void> call(String uid, LatLng location) async {
    return await repository.updateUserLocation(uid, location);
  }
}
