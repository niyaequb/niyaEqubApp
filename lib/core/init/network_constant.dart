const String apiUrl = "https://cms.niya-et.com/api/";

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

class MemberEndpoints {
  static String equbPackages() => 'member/equb-packages';
  static String equbGroups() => 'member/equb-groups';
  static String equbGroupDetail(int id) => 'member/equb-groups/$id';
  static String equbMemberships() => 'member/equb-memberships';
  static String leaveEqub(int id) => 'member/equb-memberships/$id/leave';
  static String equbDraws() => 'member/equb-draws';
  static String equbPayments() => 'member/equb-payments';
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
  static String splitPlan(int id) => 'member/my-equb-groups/$id/split-plan';
  static String start(int id) => 'member/my-equb-groups/$id/start';
  static String cancel(int id) => 'member/my-equb-groups/$id/cancel';
  static String draws(int id) => 'member/my-equb-groups/$id/draws';
  static String remindUnpaid(int id) => 'member/my-equb-groups/$id/remind-unpaid';

  static String memberLookup() => 'member/member-lookup';
  static String memberSearch() => 'member/member-search';
  static String joinableGroups() => 'member/joinable-equb-groups';
  static String joinByCode() => 'member/my-equb-groups/join-by-code';
  static String joinRequests(int groupId) => 'member/my-equb-groups/$groupId/requests';
  static String respondToRequest(int groupId, int invitationId) =>
      'member/my-equb-groups/$groupId/requests/$invitationId';
  static String myInvitations() => 'member/equb-invitations';
  static String acceptInvitation(int id) => 'member/equb-invitations/$id/accept';
  static String declineInvitation(int id) => 'member/equb-invitations/$id/decline';
}

class AdminEndpoints {
  static String members() => 'agent/members';
}
