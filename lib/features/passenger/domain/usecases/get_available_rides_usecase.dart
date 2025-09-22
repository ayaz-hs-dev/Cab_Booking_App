import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class GetAvailableRidesUsecase {
  final RideRepository repository;

  GetAvailableRidesUsecase({required this.repository});

  Stream<List<RideEntity>> call() {
    return repository.getAvailableRides();
  }
}
