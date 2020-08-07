import 'package:event_taxi/event_taxi.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';

class ContactModifiedEvent implements Event {
  final AppContact contact;

  ContactModifiedEvent({this.contact});
}