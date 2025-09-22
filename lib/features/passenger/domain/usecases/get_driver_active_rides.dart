import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class GetDriverActiveRideUsecase {
  final RideRepository repository;

  GetDriverActiveRideUsecase({required this.repository});

  Stream<List<RideEntity>> call(String driverId) {
    return repository.getDriverActiveRide(driverId);
  }
}
