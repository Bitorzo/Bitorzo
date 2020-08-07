import 'package:json_annotation/json_annotation.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/actions.dart';
import 'package:bitorzo_wallet_flutter/network/model/base_request.dart';

part 'account_unconfirmed_request.g.dart';

@JsonSerializable()
class AccountUnconfirmedRequest extends BaseRequest {
  @JsonKey(name:'action')
  String action;

  @JsonKey(name:'account')
  String account;

  @JsonKey(name:'count', includeIfNull: false)
  int count;

  AccountUnconfirmedRequest({String action, String account, int count}):super() {
    this.action = Actions.ACCOUNT_UNCONFIRMED;
    this.account = account ?? "";
    this.count = count ?? 3000;
  }

  factory AccountUnconfirmedRequest.fromJson(Map<String, dynamic> json) => _$AccountUnconfirmedRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AccountUnconfirmedRequestToJson(this);
}