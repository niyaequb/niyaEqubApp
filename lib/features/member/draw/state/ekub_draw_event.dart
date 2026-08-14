abstract class EkubDrawEvent {}

class EkubDrawLoadEvent extends EkubDrawEvent {
  final bool isSilent;
  EkubDrawLoadEvent({this.isSilent = false});
}
