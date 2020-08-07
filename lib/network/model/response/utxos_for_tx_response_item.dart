import 'package:json_annotation/json_annotation.dart';

import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/util/numberutil.dart';

part 'utxos_for_tx_response_item.g.dart';

@JsonSerializable()
class UTXOSforTXResponseItem {
  @JsonKey(name:'address_path')
  String address_path;

  @JsonKey(name:'tx_hash')
  String tx_hash;

  @JsonKey(name:'vout')
  String vout;

  @JsonKey(name:'address')
  String address;

  @JsonKey(name:'total_output_amount')
  String total_output_amount;

  UTXOSforTXResponseItem({String address_path, String address, String tx_hash, String vout, String total_output_amount}) {
    this.address_path = address_path;
    this.address = address;
    this.tx_hash = tx_hash;
    this.vout = vout;
    this.total_output_amount = total_output_amount;
  }


  factory UTXOSforTXResponseItem.fromJson(Map<String, dynamic> json) => _$UTXOSforTXResponseItemFromJson(json);
  Map<String, dynamic> toJson() => _$UTXOSforTXResponseItemToJson(this);

}