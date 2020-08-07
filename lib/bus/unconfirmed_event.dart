import 'package:event_taxi/event_taxi.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/unconfirmed_response.dart';

class UnconfirmedEvent implements Event {
  final UnconfirmedResponse response;

  UnconfirmedEvent({this.response});
}