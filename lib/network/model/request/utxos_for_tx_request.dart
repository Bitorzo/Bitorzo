import 'package:json_annotation/json_annotation.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/actions.dart';
import 'package:bitorzo_wallet_flutter/network/model/base_request.dart';
part 'utxos_for_tx_request.g.dart';

@JsonSerializable()
class UtxosForTxRequest extends BaseRequest {
  @JsonKey(name:'action')
  String action;

  @JsonKey(name:'account')
  String account;

  @JsonKey(name:'amount')
  String amount;

  UtxosForTxRequest({String account, String amount}):super() {
    this.action = Actions.UTXOS_FOR_TX;
    this.account = account;
    this.amount = amount;
  }

  factory UtxosForTxRequest.fromJson(Map<String, dynamic> json) => _$UtxosForTxRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UtxosForTxRequestToJson(this);
}