// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'utxos_for_tx_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UtxosForTxResponse _$UtxosForTxResponseFromJson(
    Map<String, dynamic> json) {
  return UtxosForTxResponse(
    utxos: (json['utxos'] as List)
        ?.map((e) => e == null
            ? null
            : UTXOSforTXResponseItem.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$UtxosForTxResponseToJson(
      UtxosForTxResponse instance) =>
    <String, dynamic>{
      'utxos': instance.utxos,
    };
