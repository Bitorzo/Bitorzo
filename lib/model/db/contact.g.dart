// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appcontact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppContact _$ContactFromJson(Map<String, dynamic> json) {
  return AppContact(
    name: json['name'] as String,
    address: json['address'] as String,
    phone: json['phone'] as String,
  );
}

Map<String, dynamic> _$ContactToJson(AppContact instance) => <String, dynamic>{
      'name': instance.name,
      'address': instance.address,
    };
