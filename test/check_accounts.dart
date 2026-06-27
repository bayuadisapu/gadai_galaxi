import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://ebxwouoddlzwkdwmyxht.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVieHdvdW9kZGx6d2tkd215eGh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzNDQ0NTksImV4cCI6MjA5NDkyMDQ1OX0.DOaMJS8sMoNReioAgtsvZ-3W7GC4pCaR_-RI2QuKHUo',
  );

  try {
    final nasabahAccounts = await client.from('gadai_nasabah_accounts').select();
    print('=== NASABAH ACCOUNTS (${nasabahAccounts.length}) ===');
    for (var a in nasabahAccounts) {
      print(a);
    }
  } catch (e) {
    print('Error nasabah accounts: $e');
  }

  try {
    final nasabah = await client.from('gadai_nasabah').select();
    print('=== NASABAH (${nasabah.length}) ===');
    for (var n in nasabah) {
      print(n);
    }
  } catch (e) {
    print('Error nasabah: $e');
  }
}
