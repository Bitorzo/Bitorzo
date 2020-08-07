// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'utxos_for_tx_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtxosForTxRequest _$UtxosForTxRequestFromJson(
    Map<String, dynamic> json) {
  return UtxosForTxRequest(
    account: json['account'] as String,
    amount: json['amount'] as String,
  );
}

Map<String, dynamic> _$UtxosForTxRequestToJson(
    UtxosForTxRequest instance) {
  final val = <String, dynamic>{
    'action': instance.action,
    'account': instance.account,
    'amount':instance.amount,
  };

  return val;
}
