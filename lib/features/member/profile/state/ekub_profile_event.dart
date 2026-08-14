import 'dart:io';

abstract class EkubProfileEvent {}

class EkubProfileLoadEvent extends EkubProfileEvent {
  final bool isSilent;
  EkubProfileLoadEvent({this.isSilent = false});
}

class EkubProfileRefreshEvent extends EkubProfileEvent {
  EkubProfileRefreshEvent();
}

class EkubProfileUpdateEvent extends EkubProfileEvent {
  final String? name;
  final String? email;
  final String? password;
  final File? profilePicture;
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? city;

  EkubProfileUpdateEvent({
    this.name,
    this.email,
    this.password,
    this.profilePicture,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.city,
  });
}

class EkubProfileDeleteAccountEvent extends EkubProfileEvent {
  EkubProfileDeleteAccountEvent();
}
