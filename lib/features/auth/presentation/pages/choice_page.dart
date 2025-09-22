import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taxi_app/routes/app_routes.dart';

class ChoicePage extends StatefulWidget {
  const ChoicePage({super.key});

  @override
  State<ChoicePage> createState() => _ChoicePageState();
}

class _ChoicePageState extends State<ChoicePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          // Navigator.pop(context);
                        },
                      ),
                      Text(
                        'Choose Your Role',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Opacity(
                        opacity: 0,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 25.0,
                      vertical: 30.0,
                    ),
                    child: Column(
                      children: [
                        // App Logo
                        Center(
                          child: Column(
                            children: [
                              Image.asset('assets/logos/path.png', height: 80),
                              SizedBox(height: 20),
                              Text(
                                'How will you use our app?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Select your primary role to get started',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 50),

                        // Choice Cards
                        Column(
                          children: [
                            // Passenger Card
                            _buildChoiceCard(
                              title: 'I\'m a Passenger',
                              description:
                                  'Book rides and travel to your destination safely and comfortably',
                              icon: Icons.airline_seat_recline_normal,
                              onTap: () => _selectRole('passenger'),
                            ),
                            SizedBox(height: 30),

                            // Driver Card
                            _buildChoiceCard(
                              title: 'I\'m a Driver',
                              description:
                                  'Earn money by driving passengers to their destinations',
                              icon: Icons.drive_eta,
                              onTap: () => _selectRole('driver'),
                            ),
                          ],
                        ),

                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.black),
            ),
            SizedBox(height: 20),

            // Title
            Text(
              title,
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),

            // Description
            Text(
              description,
              style: TextStyle(color: Colors.black54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Arrow Icon
            Icon(Icons.arrow_forward, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  void _selectRole(String role) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );

    // Simulate API call
    Future.delayed(Duration(seconds: 1), () {
      Navigator.pop(context); // Close loading dialog

      if (role == 'passenger') {
        // Navigate to passenger signup
        Navigator.pushNamed(context, AppRoutes.signup, arguments: role);
      } else {
        // Navigate to driver signup
        Navigator.pushNamed(context, AppRoutes.signup, arguments: role);
      }
    });
  }
}
