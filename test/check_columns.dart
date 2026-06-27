import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  test('Check profiles columns', () async {
    final client = SupabaseClient(
      'https://ebxwouoddlzwkdwmyxht.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
    );

    try {
      final res = await client.from('profiles').select().limit(1);
      print('=== PROFILES SAMPLE ROW ===');
      if (res.isNotEmpty) {
        print(res.first.keys.toList());
        print(res.first);
      } else {
        print('No rows returned, but table structure might be queryable.');
      }
    } catch (e) {
      print('Error querying profiles: $e');
    }
  });
}
