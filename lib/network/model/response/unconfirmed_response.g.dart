// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unconfirmed_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************


UnconfirmedResponse _$UncofirmedResponseFromJson(
    Map<String, dynamic> json) {
  return UnconfirmedResponse(
    unconfirmed: (json['unconfirmed'] as List)
        ?.map((e) => e == null
        ? null
        : AccountHistoryResponseItem.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$UncofirmedResponseToJson(
    UnconfirmedResponse instance) =>
    <String, dynamic>{
      'unconfirmed': instance.unconfirmed,
    };


