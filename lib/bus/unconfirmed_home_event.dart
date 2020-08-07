import 'package:event_taxi/event_taxi.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/account_history_response_item.dart';

class UnconfirmedHomeEvent implements Event {
  final List<AccountHistoryResponseItem> items;

  UnconfirmedHomeEvent({this.items});
}