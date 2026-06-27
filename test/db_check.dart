import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://ebxwouoddlzwkdwmyxht.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
  );

  try {
    final res = await client.from('profiles').select();
    print('=== PROFILES TABLE ROWS ===');
    print(res);
  } catch (e) {
    print('Error profiles: $e');
  }
}
