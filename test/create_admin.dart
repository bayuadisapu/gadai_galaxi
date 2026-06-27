import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

class MyStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> removeItem({required String key}) async {}

  @override
  Future<void> setItem({required String key, required String value}) async {}
}

void main() {
  test('Create superadmin user', () async {
    final client = SupabaseClient(
      'https://ebxwouoddlzwkdwmyxht.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
      authOptions: AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        pkceAsyncStorage: MyStorage(),
      ),
    );

    final testEmail = 'superadmin@gadai.com';
    final testPassword = 'password123';

    print('=== Attempting to sign up $testEmail ===');
    try {
      final response = await client.auth.signUp(
        email: testEmail,
        password: testPassword,
        data: {
          'username': 'superadmin',
          'full_name': 'Super Admin',
          'role': 'superadmin',
        },
      );
      final user = response.user;
      if (user != null) {
        print('Sign up successful! User ID: ${user.id}');
        
        // Wait 1 second for the database trigger to create a profile (if any)
        await Future.delayed(const Duration(seconds: 1));
        
        // Try to update profile to superadmin
        try {
          await client.from('profiles').update({
            'role': 'superadmin',
            'username': 'superadmin',
            'full_name': 'Super Admin',
            'is_active': true,
          }).eq('id', user.id);
          print('Profile updated to superadmin!');
        } catch (e) {
          print('Could not update profile to superadmin: $e');
        }
      } else {
        print('Sign up failed: User is null');
      }
    } catch (e) {
      print('Sign up error: $e');
      if (e.toString().contains('already registered') || e.toString().contains('User already exists')) {
        print('Email already registered! Let\'s try signing in...');
        try {
          final res = await client.auth.signInWithPassword(email: testEmail, password: testPassword);
          print('Sign in successful! User ID: ${res.user?.id}');
          
          // Try to update profile
          try {
            await client.from('profiles').update({
              'role': 'superadmin',
              'username': 'superadmin',
              'full_name': 'Super Admin',
              'is_active': true,
            }).eq('id', res.user!.id);
            print('Profile updated successfully!');
          } catch (updateError) {
            print('Failed to update profile: $updateError');
          }
        } catch (signInError) {
          print('Sign in error: $signInError');
        }
      }
    }
  });
}
