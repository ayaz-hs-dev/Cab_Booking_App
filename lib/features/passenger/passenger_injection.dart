import 'package:taxi_app/features/passenger/data/data_sources/ride_data_source.dart';
import 'package:taxi_app/features/passenger/data/data_sources/ride_data_source_impl.dart';
import 'package:taxi_app/features/passenger/data/repository/ride_repository_impl.dart';
import 'package:taxi_app/features/passenger/domain/repository/ride_repository.dart';
import 'package:taxi_app/features/passenger/domain/usecases/assign_driver_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/cancel_ride_usecae.dart';
import 'package:taxi_app/features/passenger/domain/usecases/create_ride_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_available_rides_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_driver_active_rides.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_passenger_rides.dart';
import 'package:taxi_app/features/passenger/domain/usecases/get_ride_by_id_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/ride_stream_usecase.dart';
import 'package:taxi_app/features/passenger/domain/usecases/update_ride_status_usecase.dart';
import 'package:taxi_app/features/passenger/presentation/cubit/ride_cubit.dart';
import 'package:taxi_app/main_injection.dart';

Future<void> passengerInjection() async {
  ///*<=====User DataSource=====>

  sl.registerLazySingleton<RideDataSource>(
    () => RideDataSourceImpl(firestore: sl.call()),
  );

  ///*<=====User Repository=====>

  sl.registerLazySingleton<RideRepository>(
    () => RideRepositoryImpl(dataSource: sl.call()),
  );

  ///*<=====User Usecases=====>

  sl.registerLazySingleton<AssignDriverUsecase>(
    () => AssignDriverUsecase(rideRepository: sl.call()),
  );

  sl.registerLazySingleton<CancelRideUsecae>(
    () => CancelRideUsecae(rideRepository: sl.call()),
  );

  sl.registerLazySingleton<CreateRideUsecase>(
    () => CreateRideUsecase(rideRepository: sl.call()),
  );

  sl.registerLazySingleton<GetPassengerRides>(
    () => GetPassengerRides(repository: sl.call()),
  );

  sl.registerLazySingleton<GetRideByIdUsecase>(
    () => GetRideByIdUsecase(rideRepository: sl.call()),
  );
  sl.registerLazySingleton<UpdateRideStatusUsecase>(
    () => UpdateRideStatusUsecase(rideRepository: sl.call()),
  );

  sl.registerLazySingleton<RideStreamUsecase>(
    () => RideStreamUsecase(rideRepository: sl.call()),
  );

  sl.registerLazySingleton<GetAvailableRidesUsecase>(
    () => GetAvailableRidesUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<GetDriverActiveRideUsecase>(
    () => GetDriverActiveRideUsecase(repository: sl.call()),
  );

  ///*<=====Cubits=====>*///

  sl.registerFactory<RideCubit>(
    () => RideCubit(
      assignDriverUsecase: sl.call(),
      cancelRideUsecae: sl.call(),
      getPassengerRides: sl.call(),
      getRideByIdUsecase: sl.call(),
      rideStreamUsecase: sl.call(),
      updateRideStatusUsecase: sl.call(),
      createRideUsecase: sl.call(),
      getAvailableRidesUsecase: sl.call(),
      getDriverActiveRideUsecase: sl.call(),
    ),
  );
}
