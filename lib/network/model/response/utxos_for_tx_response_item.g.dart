// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'utxos_for_tx_response_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UTXOSforTXResponseItem _$UTXOSforTXResponseItemFromJson(
    Map<String, dynamic> json) {

  return UTXOSforTXResponseItem(
    address_path: json['address_path'] as String,
    address: json['address'] as String,
    vout: json['vout'] as String,
    tx_hash: json['tx_hash'] as String,
    total_output_amount: json['total_output_amount'] as String,
  );
}

Map<String, dynamic> _$UTXOSforTXResponseItemToJson(
    UTXOSforTXResponseItem instance) =>
    <String, dynamic>{
      'address_path': instance.address_path,
      'address': instance.address,
      'vout': instance.vout,
      'tx_hash': instance.tx_hash,
      'total_output_amount': instance.total_output_amount
    };
