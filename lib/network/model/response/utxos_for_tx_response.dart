import 'package:json_annotation/json_annotation.dart';

import 'package:bitorzo_wallet_flutter/network/model/response/utxos_for_tx_response_item.dart';

part 'utxos_for_tx_response.g.dart';

/// For running in an isolate, needs to be top-level function
UtxosForTxResponse UtxosForTxResponseFromJson(Map<dynamic, dynamic> json) {
  return UtxosForTxResponse.fromJson(json);
} 

@JsonSerializable()
class UtxosForTxResponse {
  @JsonKey(name:'utxos')
  List<UTXOSforTXResponseItem> utxos;

  @JsonKey(ignore: true)
  String account;

  UtxosForTxResponse({List<UTXOSforTXResponseItem> utxos, String account}):super() {
    this.utxos = utxos;
    this.account = account;
  }

  factory UtxosForTxResponse.fromJson(Map<String, dynamic> json) => _$UtxosForTxResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UtxosForTxResponseToJson(this);
}