import 'package:taxi_app/features/auth/data/data_sources/user_data_source.dart';
import 'package:taxi_app/features/auth/data/data_sources/user_data_source_impl.dart';
import 'package:taxi_app/features/auth/data/repository/user_repository_impl.dart';
import 'package:taxi_app/features/auth/domain/repository/user_repository.dart';
import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_in_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_out_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/credintial/sign_up_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/create_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/delete_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_current_id_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_online_drivers_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/get_user_by_id_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_driver_status_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_user_location_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/update_user_usecase.dart';
import 'package:taxi_app/features/auth/domain/usecases/user/user_stream_usecases.dart';
import 'package:taxi_app/features/auth/presentation/cubit/auth/auth_cubit.dart';
import 'package:taxi_app/features/auth/presentation/cubit/user/user_cubit.dart';
import 'package:taxi_app/main_injection.dart';

Future<void> userInjection() async {
  ///*<=====User DataSource=====>

  sl.registerLazySingleton<UserDataSource>(
    () => UserDataSourceImpl(fireStore: sl.call(), auth: sl.call()),
  );

  ///*<=====User Repository=====>

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(datataSource: sl.call()),
  );

  ///*<=====User Usecases=====>
  ///* Auth Usecases *///
  sl.registerLazySingleton<SignInUsecase>(
    () => SignInUsecase(userRepository: sl.call()),
  );

  sl.registerLazySingleton<SignOutUsecase>(
    () => SignOutUsecase(repository: sl.call()),
  );

  sl.registerLazySingleton<SignUpUsecase>(
    () => SignUpUsecase(repository: sl.call()),
  );

  ///** User Usecases **/

  sl.registerLazySingleton<CreateUserUsecase>(
    () => CreateUserUsecase(repository: sl.call()),
  );

  sl.registerLazySingleton<DeleteUserUsecase>(
    () => DeleteUserUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<GetCurrentIdUsecase>(
    () => GetCurrentIdUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<GetOnlineDriversUsecase>(
    () => GetOnlineDriversUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<GetUserByIdUsecase>(
    () => GetUserByIdUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<UpdateDriverStatusUsecase>(
    () => UpdateDriverStatusUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<UpdateUserLocationUsecase>(
    () => UpdateUserLocationUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<UpdateUserUsecase>(
    () => UpdateUserUsecase(repository: sl.call()),
  );
  sl.registerLazySingleton<UserStreamUsecases>(
    () => UserStreamUsecases(repository: sl.call()),
  );

  ///*<=====Cubits=====>*///

  sl.registerFactory<AuthCubit>(
    () => AuthCubit(
      signInUsecase: sl.call(),
      signOutUsecase: sl.call(),
      signUpUsecase: sl.call(),
      getUserByIdUsecase: sl.call(),
    ),
  );
  sl.registerFactory<UserCubit>(
    () => UserCubit(
      createUserUsecase: sl.call(),
      deleteUserUsecase: sl.call(),
      getCurrentIdUsecase: sl.call(),
      getOnlineDriversUsecase: sl.call(),
      updateDriverStatusUsecase: sl.call(),
      updateUserLocationUsecase: sl.call(),
      updateUserUsecase: sl.call(),
      userStreamUsecases: sl.call(),
      getUserByIdUsecase: sl.call(),
    ),
  );
}
