import 'package:flutter_test/flutter_test.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

void main() {
  group('EqubMembership Parsing', () {
    test('should parse draw_info correctly from JSON', () {
      final json = {
        "id": 13,
        "equb_group_name": "Daily Ekub",
        "equb_package_name": "ኡምራ በ90 ቀናት ይሂዱ",
        "equb_group_id": "6",
        "member_id": "16",
        "contribution_amount": "100.00",
        "contribution_frequency_days": "1",
        "join_date": "2026-02-17T19:20:08+00:00",
        "calculated_end_date": "2026-05-28T21:01:46+00:00",
        "draw_position": null,
        "has_won": true,
        "win_date": "2026-02-18T06:58:56+00:00",
        "status": "active",
        "total_paid": 100,
        "expected_total_amount": 10000,
        "remaining_amount": 9900,
        "equb_group_package_name": "ኡምራ በ90 ቀናት ይሂዱ",
        "payments": [],
        "draw_info": {
          "id": 8,
          "equb_group_name": "Daily Ekub",
          "equb_package_name": "ኡምራ በ90 ቀናት ይሂዱ",
          "equb_group_id": "6",
          "draw_date": "2026-02-18T06:58:56+00:00",
          "executed_by_admin_id": "1",
          "winner_membership_id": "13",
          "winner_expected_total_amount": 10000,
          "winner_total_paid": 100,
          "winner_remaining_amount": 9900,
          "winner_member_name": null,
          "winner_member_id": "16",
          "created_at": "2026-02-18T06:58:56+00:00",
          "updated_at": "2026-02-18T06:58:56+00:00",
          "total_won": "200.00",
        },
      };

      final membership = EqubMembership.fromJson(json);

      expect(membership.drawInfo, isNotNull);
      expect(membership.drawInfo!.id, 8);
      expect(membership.drawInfo!.equbGroupName, "Daily Ekub");
      expect(membership.drawInfo!.winnerMembershipId, 13);
      expect(membership.drawInfo!.winnerExpectedTotalAmount, 10000);
      expect(membership.drawInfo!.winnerRemainingAmount, 9900);
      expect(membership.drawInfo!.winnerMemberId, 16);
      expect(membership.drawInfo!.totalWon, 200.0);
    });
  });
}
