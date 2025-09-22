import 'package:flutter/material.dart';
import 'package:taxi_app/features/auth/presentation/pages/choice_page.dart';
import 'package:taxi_app/features/auth/presentation/pages/edit_profile_page.dart';
import 'package:taxi_app/features/auth/presentation/pages/login_page.dart';
import 'package:taxi_app/features/auth/presentation/pages/signup_page.dart';
import 'package:taxi_app/features/auth/presentation/pages/splash_screen.dart';
import 'package:taxi_app/features/home/home_page.dart';
import 'app_routes.dart';

// Temporary placeholder widget (so code runs without errors)
class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title Page Coming Soon...')),
    );
  }
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final name = settings.name;
    switch (name) {
      case AppRoutes.splash:
        return materialPageRoute(const SplashScreen());
      case AppRoutes.choicePage:
        return materialPageRoute(const ChoicePage());
      case AppRoutes.login:
        final role = args as String;
        return MaterialPageRoute(builder: (_) => LoginPage(role: role));
      case AppRoutes.signup:
        final role = args as String?;
        return MaterialPageRoute(builder: (_) => SignupPage(role: role!));
      case AppRoutes.homePage:
        final role = args as String;
        return MaterialPageRoute(builder: (_) => HomePage(role: role));
      case AppRoutes.editProfile:
        return materialPageRoute(const EditProfilePage());
      case AppRoutes.riderHome:
        return MaterialPageRoute(
          builder: (_) => const PlaceholderPage(title: 'Rider Home'),
        );
      case AppRoutes.driverHome:
        return MaterialPageRoute(
          builder: (_) => const PlaceholderPage(title: 'Driver Home'),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('No route defined'))),
        );
    }
  }

  static Route materialPageRoute(Widget child) {
    return MaterialPageRoute(builder: (context) => child);
  }
}
