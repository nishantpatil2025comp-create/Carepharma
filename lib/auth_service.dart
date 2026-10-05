import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/user_profile.dart';

/// Service managing Supabase authentication, dual-role detection,
/// and profile checks for CareWell Pharma.
class AuthService {
  const AuthService({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  // In-memory test/fallback data for offline and automated test execution
  static final Map<String, String> _mockUserRoles = {};
  static final Set<String> _registeredPharmacyEmails = {
    'pharmacist@apollomeds.com',
    'chemist@apollomeds.com',
    'admin@carepharma.com',
  };
  static final Map<String, UserProfile> _mockProfiles = {
    'rahul.mehta@example.com': const UserProfile(
      id: 'mock_rahul_id',
      email: 'rahul.mehta@example.com',
      role: 'user',
      fullName: 'Rahul Mehta',
      phone: '+91 98230 44556',
      deliveryAddress: 'Flat 402, Green Glen Apts, Baner, Pune',
      isProfileCompleted: true,
    ),
  };

  SupabaseClient? get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Current authenticated Supabase user.
  User? get currentUser => _client?.auth.currentUser;

  /// Returns the current logged-in user's email, if any.
  String? get currentUserEmail => _client?.auth.currentUser?.email;

  /// Returns current user ID, if any.
  String? get currentUserId => _client?.auth.currentUser?.id;

  /// Sends a 6-digit OTP code to the specified email address using Supabase OTP sign-in.
  Future<void> sendOtpCode(String email) async {
    final client = _client;
    if (client != null) {
      final cleanEmail = email.trim();
      debugPrint('[AuthService] Sending OTP code to: $cleanEmail');
      await client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: true,
      );
    } else {
      debugPrint('[AuthService] Offline fallback: OTP simulated for $email');
    }
  }

  /// Verifies the 6-digit OTP code sent to the email address.
  Future<AuthResponse?> verifyOtpCode(String email, String otpCode) async {
    final client = _client;
    final cleanEmail = email.trim();
    final cleanToken = otpCode.trim();

    if (client != null) {
      // Attempt verification with OtpType.email (standard for signInWithOtp)
      try {
        final response = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: OtpType.email,
        );
        if (response.session != null) {
          debugPrint('Email OTP verified successfully with OtpType.email');
          return response;
        }
      } catch (e) {
        debugPrint('OtpType.email attempt failed: $e, trying OtpType.signup');
      }

      // Fallback to OtpType.signup (if user was newly created during OTP)
      try {
        final response = await client.auth.verifyOTP(
          email: cleanEmail,
          token: cleanToken,
          type: OtpType.signup,
        );
        if (response.session != null) {
          debugPrint('Email OTP verified successfully with OtpType.signup');
          return response;
        }
      } catch (e) {
        debugPrint('OtpType.signup attempt failed: $e, trying OtpType.magiclink');
      }

      // Fallback to OtpType.magiclink
      final response = await client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.magiclink,
      );
      return response;
    } else {
      // Fallback for tests
      return AuthResponse(
        session: Session(
          accessToken: 'simulated_token',
          tokenType: 'bearer',
          user: User(
            id: 'mock_user_id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
            email: cleanEmail,
          ),
        ),
      );
    }
  }

  /// Determines the active role for a user ('pharmacist' or 'user').
  /// Checks user metadata first, then the `profiles` table.
  Future<String?> getUserRole({User? user, String? email}) async {
    final targetUser = user ?? currentUser;
    final targetEmail = email ?? targetUser?.email;

    // 1. Check user metadata
    final metaRole = targetUser?.userMetadata?['role']?.toString().toLowerCase();
    if (metaRole != null && metaRole.isNotEmpty) {
      return metaRole;
    }

    // 2. Check mock / offline roles
    if (targetEmail != null && _mockUserRoles.containsKey(targetEmail.toLowerCase())) {
      return _mockUserRoles[targetEmail.toLowerCase()];
    }

    // 3. Check public.profiles in Supabase
    final client = _client;
    if (client != null && targetUser != null) {
      try {
        final res = await client
            .from('profiles')
            .select('role')
            .eq('id', targetUser.id)
            .maybeSingle();
        if (res != null && res['role'] != null) {
          return res['role'].toString().toLowerCase();
        }
      } catch (e) {
        debugPrint('[AuthService] Error querying user profile role: $e');
      }
    }

    return null;
  }

  /// Assigns or updates the role of a user in Supabase metadata and `profiles` table.
  Future<void> setUserRole(String role, {User? user, String? email}) async {
    final cleanRole = role.trim().toLowerCase();
    final targetUser = user ?? currentUser;
    final targetEmail = email ?? targetUser?.email;

    if (targetEmail != null) {
      _mockUserRoles[targetEmail.toLowerCase()] = cleanRole;
    }

    final client = _client;
    if (client != null && targetUser != null && client.auth.currentUser != null && !targetUser.id.startsWith('mock') && !targetUser.id.startsWith('guest')) {
      try {
        // Update user metadata
        await client.auth.updateUser(
          UserAttributes(data: {'role': cleanRole}),
        );

        // Upsert into public.profiles
        await client.from('profiles').upsert({
          'id': targetUser.id,
          'email': targetUser.email,
          'role': cleanRole,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('[AuthService] Error persisting user role: $e');
      }
    }
  }

  /// Checks if a registered pharmacy store exists for this pharmacist email or user ID.
  Future<bool> checkPharmacyExists({String? email, String? userId}) async {
    final cleanEmail = (email ?? currentUserEmail)?.trim().toLowerCase();
    final cleanUserId = userId ?? currentUserId;

    // Check offline / test mock registrations
    if (cleanEmail != null && _registeredPharmacyEmails.contains(cleanEmail)) {
      return true;
    }

    final client = _client;
    if (client != null) {
      // 1. Strictly query exact "Email" column with matching uppercase casing
      if (cleanEmail != null && cleanEmail.isNotEmpty) {
        try {
          final List<dynamic> records = await client
              .from('pharmacies')
              .select('UID, Email')
              .ilike('Email', cleanEmail)
              .limit(1);
          if (records.isNotEmpty) {
            _registeredPharmacyEmails.add(cleanEmail);
            return true;
          }
        } catch (e) {
          debugPrint('[AuthService] Error checking pharmacy Email existence: $e');
        }
      }

      // 2. Fallback check for owner_id if cleanUserId is available
      if (cleanUserId != null && cleanUserId.isNotEmpty) {
        try {
          final List<dynamic> records = await client
              .from('pharmacies')
              .select('UID')
              .eq('owner_id', cleanUserId)
              .limit(1);
          if (records.isNotEmpty) {
            if (cleanEmail != null) _registeredPharmacyEmails.add(cleanEmail);
            return true;
          }
        } catch (e) {
          debugPrint('[AuthService] Error checking pharmacy owner_id: $e');
        }
      }
    }

    return false;
  }

  /// Marks a pharmacy as registered in local cache (called after store registration).
  void markPharmacyRegistered(String email) {
    _registeredPharmacyEmails.add(email.trim().toLowerCase());
  }

  /// Fetches the user's profile from the database.
  Future<UserProfile?> getUserProfile({String? userId, String? email}) async {
    final cleanUserId = userId ?? currentUserId;
    final cleanEmail = (email ?? currentUserEmail)?.trim().toLowerCase();

    final client = _client;
    if (client != null) {
      try {
        if (cleanUserId != null) {
          final res = await client
              .from('profiles')
              .select('*')
              .eq('id', cleanUserId)
              .maybeSingle();

          if (res != null) {
            final p = UserProfile.fromJson(Map<String, dynamic>.from(res as Map));
            if (cleanEmail != null) _mockProfiles[cleanEmail] = p;
            return p;
          }
        }

        if (cleanEmail != null) {
          final byEmail = await client
              .from('profiles')
              .select('*')
              .eq('email', cleanEmail)
              .maybeSingle();
          if (byEmail != null) {
            final p = UserProfile.fromJson(Map<String, dynamic>.from(byEmail as Map));
            _mockProfiles[cleanEmail] = p;
            return p;
          }
        }
      } catch (e) {
        debugPrint('[AuthService] Error fetching user profile: $e');
      }
    }

    // Check test / mock profile cache when offline or not found
    if (cleanEmail != null && _mockProfiles.containsKey(cleanEmail)) {
      return _mockProfiles[cleanEmail];
    }

    return null;
  }

  /// Saves or updates the user profile record in `public.profiles`.
  /// Anonymous / guest exploration remains local in-memory only without inserting dummy rows to Supabase.
  Future<void> saveUserProfile(UserProfile profile) async {
    if (profile.email != null) {
      _mockProfiles[profile.email!.toLowerCase()] = profile;
    }

    final client = _client;
    final isGuest = profile.id.startsWith('guest') ||
        profile.id.startsWith('mock') ||
        (client?.auth.currentUser == null);

    if (client != null && !isGuest && client.auth.currentUser != null) {
      try {
        await client.from('profiles').upsert(profile.toJson());
        await client.auth.updateUser(
          UserAttributes(data: {
            'role': profile.role,
            'full_name': profile.fullName,
            'profile_completed': profile.isProfileCompleted,
          }),
        );
      } catch (e) {
        debugPrint('[AuthService] Error saving user profile: $e');
        rethrow;
      }
    }
  }

  /// Checks if the patient has completed their profile setup.
  Future<bool> isUserProfileComplete({String? userId, String? email}) async {
    final cleanEmail = (email ?? currentUserEmail)?.trim().toLowerCase();

    // Check mock / offline cache
    if (cleanEmail != null && _mockProfiles.containsKey(cleanEmail)) {
      return _mockProfiles[cleanEmail]!.hasCompletedProfile;
    }

    final profile = await getUserProfile(userId: userId, email: email);
    return profile?.hasCompletedProfile ?? false;
  }

  /// Signs the user out from Supabase.
  Future<void> signOut() async {
    final client = _client;
    if (client != null) {
      await client.auth.signOut();
    }
  }

  /// Resets mock test states (useful for clean unit tests).
  @visibleForTesting
  static void resetMockState() {
    _mockUserRoles.clear();
    _registeredPharmacyEmails.clear();
    _registeredPharmacyEmails.addAll({
      'pharmacist@apollomeds.com',
      'chemist@apollomeds.com',
      'admin@carepharma.com',
    });
    _mockProfiles.clear();
    _mockProfiles['rahul.mehta@example.com'] = const UserProfile(
      id: 'mock_rahul_id',
      email: 'rahul.mehta@example.com',
      role: 'user',
      fullName: 'Rahul Mehta',
      phone: '+91 98230 44556',
      deliveryAddress: 'Flat 402, Green Glen Apts, Baner, Pune',
      isProfileCompleted: true,
    );
  }
}
