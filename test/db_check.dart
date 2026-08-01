import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://ebxwouoddlzwkdwmyxht.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
  );

  try {
    final res = await client.from('gadai_transactions').select().limit(1);
    print('=== GADAI_TRANSACTIONS SAMPLE ROW ===');
    if (res.isNotEmpty) {
      print(res.first.keys.toList());
      print(res.first);
    } else {
      print('No transactions found in DB.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
