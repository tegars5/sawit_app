import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/mitra/screens/mitra_home_screen.dart';
import 'features/mitra/screens/edit_profile_screen.dart';
import 'features/mitra/screens/change_password_screen.dart';
import 'features/mitra/screens/privacy_policy_screen.dart';
import 'features/mitra/screens/terms_of_service_screen.dart';
import 'features/mitra/providers/product_provider.dart';
import 'features/mitra/providers/cart_provider.dart';
import 'features/mitra/providers/order_provider.dart';
import 'features/admin/screens/admin_home_screen.dart';
import 'features/admin/screens/admin_driver_list_screen.dart';
import 'features/admin/screens/admin_product_form_screen.dart';
import 'features/admin/providers/admin_order_provider.dart';
import 'features/driver/screens/driver_home_screen.dart';
import 'features/driver/providers/driver_order_provider.dart';
import 'core/models/product.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Storage
  await StorageService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => AdminOrderProvider()),
        ChangeNotifierProvider(create: (_) => DriverOrderProvider()),
      ],
      child: MaterialApp(
        title: 'Cangkang Sawit',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/mitra/home': (context) => const MitraHomeScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/change-password': (context) => const ChangePasswordScreen(),
          '/privacy-policy': (context) => const PrivacyPolicyScreen(),
          '/terms-of-service': (context) => const TermsOfServiceScreen(),
          '/admin/home': (context) => const AdminHomeScreen(),
          '/admin/drivers': (context) => const AdminDriverListScreen(),
          '/driver/home': (context) => const DriverHomeScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/admin/product-form') {
            final product = settings.arguments as Product?;
            return MaterialPageRoute(
              builder: (context) => AdminProductFormScreen(product: product),
            );
          }
          return null;
        },
      ),
    );
  }
}
