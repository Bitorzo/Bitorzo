import 'package:event_taxi/event_taxi.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/callback_response.dart';

class CallbackEvent implements Event {
  final CallbackResponse response;

  CallbackEvent({this.response});
}