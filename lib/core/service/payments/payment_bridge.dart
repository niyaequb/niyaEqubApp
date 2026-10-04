// Talking to a bank's host app — mobile implementation.
//
// ============================================================================
// ONE BRIDGE, EVERY BANK
// ============================================================================
//
// Niya collects through several banks: Dashen now, CBE, Awash and more to
// come. There is deliberately NO class per bank here, and adding a bank should
// require no change to this file at all.
//
// That works because the server tells the client everything it needs. A
// create-payment response carries a `client` block — which host-app global to
// talk to, what kind of flow it is, the public app code — alongside the signed
// order. So the client is not a list of banks, it is a mechanism that takes
// whatever descriptor it is handed.
//
// The alternative, a DashenBridge beside a CbeBridge beside an AwashBridge,
// would mean an app release and a wait for members to update every time a bank
// is added, and old builds offering banks that no longer work. This way a bank
// goes live for everyone the moment it is configured on the server.
//
// ============================================================================
// WHY THIS FILE DOES NOTHING ON A PHONE
// ============================================================================
//
// These integrations are mini apps: web apps loaded INSIDE the bank's own
// super-app, reached over a JavaScript object the host injects into the page.
// A standalone Flutter app is a different application on the same device, and
// none of the banks ship a native SDK or expose an intent we could use.
//
// So on mobile every call reports `unsupported`. That is the same choice
// MosqueModeService and the Qibla compass already make on web — say plainly
// that the platform cannot do the thing, and let the UI explain it — rather
// than shipping a button that fails at the moment a member tries to pay.
//
// `MiniApp/web_overrides/core/service/payments/payment_bridge.dart` replaces
// this file in the web build with the real bridge. It keeps this exact public
// API, which is why no screen, bloc or repository knows which platform it is
// on: they read `isAvailable` and act on a `PaymentAuthorisation`.
//
// If a bank ever ships a native SDK, this is the only file that changes.

import 'package:niya_equb/core/util/logger.dart';

/// How an authorisation attempt ended.
enum PaymentOutcome {
  /// The host app reported the transaction as complete.
  ///
  /// This is NOT proof of settlement — it is a prompt to go and ask the
  /// backend. Only a verified settlement notification moves a contribution to
  /// `paid`, and the backend is the only thing that knows.
  completed,

  /// The member backed out, or the host app closed the sheet.
  cancelled,

  /// The host app reported a failure, or the bridge errored.
  failed,

  /// This platform has no bridge to this bank at all.
  unsupported,
}

class PaymentAuthorisation {
  final PaymentOutcome outcome;
  final String? message;

  /// Whatever the host app handed the callback, kept for logging. Its shape is
  /// not documented by any of the banks, so nothing branches on it.
  final Object? raw;

  const PaymentAuthorisation(this.outcome, {this.message, this.raw});

  const PaymentAuthorisation.unsupported()
    : outcome = PaymentOutcome.unsupported,
      message = null,
      raw = null;

  /// Whether the app should go and re-read the contribution from the server.
  ///
  /// True only on [PaymentOutcome.completed]. Deliberately not named `isPaid`:
  /// the client never decides that.
  bool get shouldRefetch => outcome == PaymentOutcome.completed;
}

/// How to reach one bank's host app.
///
/// Comes from the server — either the `client` block on a create-payment
/// response, or an entry from GET /api/payments/providers. Nothing in it is
/// secret: a global object name and a public app code.
class PaymentClientConfig {
  /// Gateway slug, e.g. 'dashen'.
  final String slug;

  /// Bank name, for anything shown to a member.
  final String name;

  /// Flow type. 'superapp' means the order is handed to a host application
  /// over a bridge rather than opened as a web checkout.
  final String kind;

  /// The global object the host app injects, e.g. 'dashenbanksuperapp'.
  final String? bridge;

  /// Public mini-app code, presented when asking the host who the customer is.
  final String? appCode;

  final String? stage;

  const PaymentClientConfig({
    required this.slug,
    required this.name,
    this.kind = 'superapp',
    this.bridge,
    this.appCode,
    this.stage,
  });

  factory PaymentClientConfig.fromJson(Map<String, dynamic> json) {
    return PaymentClientConfig(
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'superapp',
      bridge: json['bridge']?.toString(),
      appCode: json['app_code']?.toString(),
      stage: json['stage']?.toString(),
    );
  }
}

/// The client half of one bank integration.
abstract class PaymentBridge {
  const PaymentBridge();

  /// Whether this bank's host app is reachable from here.
  ///
  /// Read this before offering a payment action, so the UI can explain the
  /// situation instead of presenting a control that cannot work.
  bool get isAvailable;

  /// Ask the host app who the current customer is.
  ///
  /// Returns the opaque identifier for the backend to exchange, or null when
  /// there is no bridge. Nothing is inferred from it here — it is only useful
  /// to the server.
  Future<String?> fetchCustomerIdentifier();

  /// Present a signed order for authorisation.
  ///
  /// [orderPayload] and [authPayload] come from the backend verbatim and must
  /// NOT be modified. The order carries an HMAC over its own contents, and
  /// every one of these banks refuses a request whose signed content disagrees
  /// with the rest of it.
  Future<PaymentAuthorisation> authorise({
    required Map<String, dynamic> orderPayload,
    required Map<String, dynamic> authPayload,
  });

  /// Request native permissions through the host app.
  ///
  /// Returns permission name to status ("granted" / "rejected").
  Future<Map<String, String>> requestPermissions(List<String> permissions);
}

/// A bridge for a platform that has none.
///
/// Not an error type. It is the honest answer on a phone, and the UI is built
/// to render it: the payment screen shows "pay from the bank's app" rather
/// than a dead button.
class UnavailableBridge extends PaymentBridge {
  final String reason;

  const UnavailableBridge([this.reason = 'no_bridge_on_this_platform']);

  @override
  bool get isAvailable => false;

  @override
  Future<String?> fetchCustomerIdentifier() async {
    logger('PaymentBridge.fetchCustomerIdentifier: $reason');
    return null;
  }

  @override
  Future<PaymentAuthorisation> authorise({
    required Map<String, dynamic> orderPayload,
    required Map<String, dynamic> authPayload,
  }) async {
    logger('PaymentBridge.authorise: $reason');
    return const PaymentAuthorisation.unsupported();
  }

  @override
  Future<Map<String, String>> requestPermissions(List<String> permissions) async {
    return const {};
  }
}

/// Resolves a bank descriptor to a bridge.
///
/// On mobile there is nothing to resolve to, so every bank gets the same
/// honest "not here" answer. The web override returns a working bridge built
/// from the descriptor.
class PaymentBridges {
  const PaymentBridges._();

  /// True where at least the mechanism exists, whatever the bank.
  ///
  /// Lets a screen say "payments happen in the bank's app" once, rather than
  /// per bank.
  static bool get supportedOnThisPlatform => false;

  static PaymentBridge of(PaymentClientConfig? config) {
    return const UnavailableBridge();
  }
}
