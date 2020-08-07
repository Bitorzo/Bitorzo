// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_unconfirmed_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountUnconfirmedRequest _$AccountUnconfirmedRequestFromJson(
    Map<String, dynamic> json) {
  return AccountUnconfirmedRequest(
    action: json['action'] as String,
    account: json['account'] as String,
    count: json['count'] as int,
  );
}

Map<String, dynamic> _$AccountUnconfirmedRequestToJson(
    AccountUnconfirmedRequest instance) {
  final val = <String, dynamic>{
    'action': instance.action,
    'account': instance.account,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('count', instance.count);
  return val;
}
