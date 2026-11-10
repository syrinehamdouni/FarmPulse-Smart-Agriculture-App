import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'profile_screen.dart';
import 'edit_info_screen.dart';
import 'my_farm_screen.dart';
import 'notifications_screen.dart';
import 'language_screen.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'crop_yield_prediction_screen.dart';
import 'gps_recommendation_screen.dart';
import 'agenda_screen.dart';
import 'power_bi_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('fr_FR', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit_info': (context) => const EditInfoScreen(),
        '/my_farm': (context) => const MyFarmScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/language': (context) => const LanguageScreen(),
        '/chatbot': (context) => const ChatBotScreen(),
        '/crop_prediction': (context) => const CropYieldPredictionScreen(),
        '/gps': (context) => const GpsRecommendationScreen(),
        '/agenda': (context) => const AgendaScreen(),
        '/power_bi': (context) => const PowerBIScreen(
          portalUrl: 'https://app.powerbi.com/view?r=YOUR_REPORT_LINK_HERE', // ضع رابط التقرير هنا
        ),
      },
    );
  }
}
