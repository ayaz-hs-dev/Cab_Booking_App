import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:taxi_app/app/theme.dart';
import 'package:taxi_app/features/auth/presentation/cubit/auth/auth_cubit.dart';
import 'package:taxi_app/features/auth/presentation/cubit/user/user_cubit.dart';
import 'package:taxi_app/features/auth/presentation/pages/choice_page.dart';
import 'package:taxi_app/features/auth/presentation/pages/splash_screen.dart';
import 'package:taxi_app/features/home/home_page.dart';
import 'package:taxi_app/features/passenger/presentation/cubit/ride_cubit.dart';
import 'package:taxi_app/firebase_options.dart';
import 'package:taxi_app/main_injection.dart' as di;
import 'package:taxi_app/routes/app_router.dart';
import 'package:taxi_app/services/notification/firebase_message_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  di.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    requestPermission();
    super.initState();
  }

  void requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => di.sl<AuthCubit>()..checkAuthStatus(),
        ),
        BlocProvider(create: (context) => di.sl<UserCubit>()),
        BlocProvider(create: (context) => di.sl<RideCubit>()),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Taxi App',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: ThemeMode.system,
            home: BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state is AuthLoading) {
                  return const SplashScreen();
                } else if (state is AuthSignedIn) {
                  debugPrint("🔵 [MyApp] Auth state: $state  SignIn");
                  return HomePage(role: state.user!.role!);
                } else if (state is AuthSignedOut) {
                  debugPrint("🔵 [MyApp] Auth state: $state  SignOut");
                  return const ChoicePage();
                }
                debugPrint("🔵 [MyApp] Auth state: $state");
                return const SplashScreen();
              },
            ),
            onGenerateRoute: AppRouter.generateRoute,
          );
        },
      ),
    );
  }
}
