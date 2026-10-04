/// Where the app talks to the API.
///
/// The default is the deployed backend, so nothing changes for a normal build
/// of either app: no flag, same URL as before.
///
/// It is overridable because payment testing needs it to be. The deployed
/// backend shares the production database, so exercising the Dashen order flow
/// against it writes real pending contributions into live data. Pointing the
/// app at a local server instead keeps that off production:
///
///     flutter run -d chrome --web-port 5002 \
///         --dart-define=NIYA_API_URL=http://localhost:8000/api/
///
/// or `.\sync.ps1 -Run -ApiUrl http://localhost:8000/api/` from MiniApp.
///
/// String.fromEnvironment is a const constructor, so this stays a compile-time
/// constant and is tree-shaken exactly as the literal was. The trailing slash
/// is part of the value — every endpoint below is relative to it.
const String apiUrl = String.fromEnvironment(
  'NIYA_API_URL',
  defaultValue: "https://cms.niya-et.com/api/",
);

class AuthEndpoint {
  static String login() {
    return "auth/login";
  }

  static String delete() {
    return "auth/delete-account";
  }

  static String checkUser() {
    return "auth/check-user";
  }

  static String resetPassword() {
    return "auth/reset-password";
  }

  static String logout() {
    return "auth/logout";
  }

  static String requestOtp() {
    return "auth/send-otp";
  }

  static String verifyOtp() {
    return "auth/verify-otp";
  }

  static String register() {
    return "auth/register";
  }

  static String me() {
    return "auth/me";
  }

  static String update() {
    return "auth/update";
  }

  static String fcmToken() {
    return "auth/fcm-token";
  }
}

class ParentDashboardEndpoints {
  static String addchild() {
    return "auth/link-student-to-parent";
  }
}

/// Endpoints that need no account. Called before, or instead of, signing in.
class AppEndpoints {
  /// "Is there a newer build, and can I keep using this one?" Public, because
  /// someone stuck on a build where login broke is exactly who needs telling.
  static String appVersion() => 'app-version';
}

class MemberEndpoints {
  static String equbPackages() => 'member/equb-packages';
  static String equbGroups() => 'member/equb-groups';
  static String equbGroupDetail(int id) => 'member/equb-groups/$id';
  static String equbMemberships() => 'member/equb-memberships';
  static String leaveEqub(int id) => 'member/equb-memberships/$id/leave';
  static String equbDraws() => 'member/equb-draws';
  static String equbPayments() => 'member/equb-payments';

  /// Settles several contributions in one charge: the member's own place plus
  /// every place they hold for someone under "My Responsibility People".
  static String equbPaymentsBatch() => 'member/equb-payments/batch';

  /// The banks a member can pay through, and how to reach each one's app.
  ///
  /// Not under member/ and needs no session: the app draws its payment options
  /// before anyone has necessarily signed in, and nothing it returns is
  /// privileged. Asked of the server rather than hardcoded so a new bank
  /// reaches members without an app release.
  static String paymentProviders() => 'payments/providers';

  /// Exchanges a bank host-app customer identifier for a Niya session.
  static String paymentIdentify(String provider) =>
      'payments/$provider/identify';
  static String faqs() => 'faqs';
  static String exchangeRate() => 'exchange-rates';
  static String banners() => 'promotions';
}

class AgentEndpoints {
  static String dashboard() => 'agent/dashboard';
  static String members() => 'agent/members';
  static String payments() => 'agent/payments';
}

/// Group Equb: member-created private groups.
class GroupEqubEndpoints {
  static String myGroups() => 'member/my-equb-groups';
  static String group(int id) => 'member/my-equb-groups/$id';
  static String byCode(String code) => 'member/my-equb-groups/by-code/$code';
  static String ledger(int id) => 'member/my-equb-groups/$id/ledger';
  static String invitations(int id) => 'member/my-equb-groups/$id/invitations';
  static String removeMember(int groupId, int membershipId) =>
      'member/my-equb-groups/$groupId/members/$membershipId';

  /// "My Responsibility People": places in a group held for someone with no
  /// Niya account. The membership id is the handle for each one.
  static String responsibilityPeople(int groupId) =>
      'member/my-equb-groups/$groupId/responsibility-people';
  static String responsibilityPerson(int groupId, int membershipId) =>
      'member/my-equb-groups/$groupId/responsibility-people/$membershipId';

  static String splitPlan(int id) => 'member/my-equb-groups/$id/split-plan';
  static String start(int id) => 'member/my-equb-groups/$id/start';
  static String cancel(int id) => 'member/my-equb-groups/$id/cancel';
  static String draws(int id) => 'member/my-equb-groups/$id/draws';
  static String remindUnpaid(int id) =>
      'member/my-equb-groups/$id/remind-unpaid';

  static String memberLookup() => 'member/member-lookup';
  static String memberSearch() => 'member/member-search';
  static String joinableGroups() => 'member/joinable-equb-groups';
  static String joinByCode() => 'member/my-equb-groups/join-by-code';
  static String joinRequests(int groupId) =>
      'member/my-equb-groups/$groupId/requests';
  static String respondToRequest(int groupId, int invitationId) =>
      'member/my-equb-groups/$groupId/requests/$invitationId';
  static String myInvitations() => 'member/equb-invitations';
  static String acceptInvitation(int id) =>
      'member/equb-invitations/$id/accept';
  static String declineInvitation(int id) =>
      'member/equb-invitations/$id/decline';
}

class AdminEndpoints {
  static String members() => 'agent/members';
}
