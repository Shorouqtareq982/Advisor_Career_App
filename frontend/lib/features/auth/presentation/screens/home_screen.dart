import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //     watch the auth provider
    final authState = ref.watch(authProvider);
    final user = authState.user;

    print(' [HOME SCREEN] Building with user: ${user?.username}');
    print(' [HOME SCREEN] isAuthenticated: ${authState.isAuthenticated}');
    print(' [HOME SCREEN] isLoading: ${authState.isLoading}');

    return Scaffold(
      backgroundColor: AppColors.blue500,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.blue500,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //     Show loading indicator while loading
                if (authState.isLoading)
                  const CircularProgressIndicator()

                //     Show user data when available
                else if (user != null) ...[
                  // Profile Picture
                  if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lightBlue500,
                          width: 3,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(user.avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.green700.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.green700,
                        size: 60,
                      ),
                    ),
                  const SizedBox(height: 32),

                  const Text(
                    'Welcome to Growza!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Username
                  Text(
                    user.username != null && user.username!.isNotEmpty
                        ? '@${user.username}'
                        : 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Email
                  if (user.email != null && user.email!.isNotEmpty)
                    Text(
                      user.email!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),

                  // Phone
                  if (user.phone != null && user.phone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),

                  // Provider
                  if (user.provider != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue500.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.provider == 'google'
                              ? 'Sign in with Google'
                              : user.provider == 'phone'
                                  ? 'Sign in with Phone'
                                  : 'Sign in with Email',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.lightBlue500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ] else
                  // No user data
                  const Column(
                    children: [
                      Text(
                        'No user data available',
                        style: TextStyle(color: AppColors.grey500),
                      ),
                      SizedBox(height: 16),
                      CircularProgressIndicator(),
                    ],
                  ),

                const SizedBox(height: 48),

                Text(
                  'Your AI-powered career journey starts here!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grey50.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
