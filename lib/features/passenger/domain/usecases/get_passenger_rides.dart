import 'package:taxi_app/features/passenger/domain/entities/ride_entity.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';

class GetPassengerRides {
  final RideRepository repository;
  GetPassengerRides({required this.repository});

  Future<List<RideEntity>> call(String passengerId) async =>
      await repository.getPassengerRides(passengerId);
}
