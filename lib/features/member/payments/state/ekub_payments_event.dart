abstract class EkubPaymentsEvent {}

class EkubPaymentsLoadEvent extends EkubPaymentsEvent {
  final bool isSilent;
  EkubPaymentsLoadEvent({this.isSilent = false});
}

class EkubPaymentsSetFilterEvent extends EkubPaymentsEvent {
  final int filterIndex; // 0 all, 1 paid, 2 pending
  EkubPaymentsSetFilterEvent({required this.filterIndex});
}
