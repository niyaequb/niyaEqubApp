abstract class EkubNotificationsEvent {}

class EkubNotificationsLoadEvent extends EkubNotificationsEvent {
  final bool isSilent;
  EkubNotificationsLoadEvent({this.isSilent = false});
}
