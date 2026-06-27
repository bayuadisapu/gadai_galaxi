import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check crew_members and pelanggan rows', () async {
    final client = SupabaseClient(
      'https://ebxwouoddlzwkdwmyxht.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
    );

    try {
      final crew = await client.from('crew_members').select().limit(5);
      print('=== CREW MEMBERS SAMPLE ===');
      for (var c in crew) {
        print(c);
      }
    } catch (e) {
      print('Error crew: $e');
    }
  });
}
