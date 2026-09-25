import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/upload_page.dart';
import '../screens/store_image_page.dart';
import '../screens/image_gallery_page.dart';
import '../screens/dashboard_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/persons_screen.dart';
import '../screens/person_detail_screen.dart';
import '../screens/person_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthed = session != null;

    final publicRoutes = {'/login', '/register'};
    final isPublic = publicRoutes.contains(state.matchedLocation);

    if (!isAuthed && !isPublic) return '/login';
    if (isAuthed && isPublic)   return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(
      path:    '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path:    '/register',
      builder: (_, __) => const SignupScreen(),
    ),
    GoRoute(
      path:    '/upload',
      builder: (_, __) => const UploadPage(),
    ),
    GoRoute(
      path:    '/gallery',
      builder: (_, __) => const ImageGalleryPage(),
    ),
    GoRoute(
      path:    '/dashboard',
      builder: (_, __) => const DashboardScreen(),
    ),
    GoRoute(
      path:    '/camera',
      builder: (_, __) => const CameraScreen(),
    ),
    GoRoute(
      path:    '/persons',
      builder: (_, __) => const PersonsScreen(),
      routes: [
        GoRoute(
          path: ':personId',
          builder: (_, state) => PersonDetailScreen(
            personId: state.pathParameters['personId']!,
          ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, state) => PersonEditScreen(
                personId: state.pathParameters['personId']!,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/store-image/:personId',
      builder: (_, state) => StoreImagePage(
        personId: state.pathParameters['personId']!,
      ),
    ),
  ],
);
