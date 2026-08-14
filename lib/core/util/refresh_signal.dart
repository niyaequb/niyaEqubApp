import 'dart:async';

/// Connects a `RefreshIndicator` to a bloc event.
///
/// `RefreshIndicator` keeps its spinner up until the future returned by
/// `onRefresh` completes. Adding a bloc event returns immediately, so pulling
/// down used to snap back before the request had even left the device and the
/// list looked like it never refreshed at all.
///
/// The refresh event now carries one of these, and the handler completes it in
/// a `finally` once the data is in.
class RefreshSignal {
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  /// Safe to call more than once — a handler that reloads twice won't throw.
  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Dispatches a refresh event and waits for its handler to finish.
///
/// ```dart
/// onRefresh: () => refreshWith(
///   (signal) => context.read<GroupListBloc>().add(
///         GroupListLoadEvent(isSilent: true, signal: signal),
///       ),
/// ),
/// ```
Future<void> refreshWith(
  void Function(RefreshSignal signal) dispatch, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final signal = RefreshSignal();
  dispatch(signal);

  try {
    await signal.future.timeout(timeout);
  } on TimeoutException {
    // A dead connection must not leave the spinner turning forever.
  }
}
