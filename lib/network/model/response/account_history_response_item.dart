import 'package:json_annotation/json_annotation.dart';

import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/util/numberutil.dart';

part 'account_history_response_item.g.dart';

@JsonSerializable()
class AccountHistoryResponseItem {
  @JsonKey(name:'type')
  String type;

  @JsonKey(name:'account')
  String account;

  @JsonKey(name:'amount')
  String amount;

  @JsonKey(name:'hash')
  String hash;

  AccountHistoryResponseItem({String type, String account, String amount, String hash}) {
    this.type = type;
    this.account = account;
    this.amount = amount;
    this.hash = hash;
  }

  String getShortString() {
    return this.account.substring(0,6) + ".." + this.account.substring(20,26);
    // return new Address(this.account).getShortString();
  }

  String getShorterString() {
    return this.account.substring(0,6) + ".." + this.account.substring(20,26);
    return new Address(this.account).getShorterString();
  }

  /**
   * Return amount formatted for use in the UI
   */
  String getFormattedAmount() {
    //return NumberUtil.getRawAsUsableString(amount);
    return NumberUtil.SatoshiToMilliBTC(amount);
  }

  factory AccountHistoryResponseItem.fromJson(Map<String, dynamic> json) => _$AccountHistoryResponseItemFromJson(json);
  Map<String, dynamic> toJson() => _$AccountHistoryResponseItemToJson(this);

  bool operator ==(o) => o is AccountHistoryResponseItem && o.hash == hash;
  int get hashCode => hash.hashCode;
}