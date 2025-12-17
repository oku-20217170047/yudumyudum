import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  SupabaseClient get _sb => Supabase.instance.client;

  Session? get session => _sb.auth.currentSession;
  User? get user => _sb.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await _sb.auth.signUp(email: email, password: password);

    // Eğer email confirmation kapalıysa session gelir ve user_id hazır olur
    if (res.user != null) {
      await _ensureProfile(
        userId: res.user!.id,
        displayName: displayName,
      );
    }
    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _sb.auth.signInWithPassword(email: email, password: password);

    if (res.user != null) {
      await _ensureProfile(userId: res.user!.id);
    }
    return res;
  }

  Future<void> signOut() => _sb.auth.signOut();

  Future<void> _ensureProfile({required String userId, String? displayName}) async {
    await _sb.from('profiles').upsert(
      {
        'user_id': userId,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        // daily_target_ml tablodaki default 2000; yazmasak da olur.
      },
      onConflict: 'user_id',
    );
  }
}
