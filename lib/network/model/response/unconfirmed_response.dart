import 'package:json_annotation/json_annotation.dart';

import 'account_history_response_item.dart';
part 'unconfirmed_response.g.dart';

/// For running in an isolate, needs to be top-level function
UnconfirmedResponse unconfirmedResponseFromJson(Map<dynamic, dynamic> json) {
  return UnconfirmedResponse.fromJson(json);
} 

@JsonSerializable()
class UnconfirmedResponse {
  @JsonKey(name:"unconfirmed")
  List<AccountHistoryResponseItem> unconfirmed;

  @JsonKey(ignore: true)
  String account;

  UnconfirmedResponse({List<AccountHistoryResponseItem> unconfirmed, String account}):super() {
    this.unconfirmed = unconfirmed;
    this.account = account;
  }

  factory UnconfirmedResponse.fromJson(Map<String, dynamic> json) => _$UncofirmedResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UncofirmedResponseToJson(this);
}