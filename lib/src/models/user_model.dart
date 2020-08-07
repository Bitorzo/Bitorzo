

import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';

class UserModel{
  AppContact _contact;
  String _profilePic;

  UserModel(this._contact, this._profilePic);

  AppContact get contact => _contact;

  get profilePic => _profilePic;

}