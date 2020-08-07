import 'package:flutter/material.dart';
import 'package:bitorzo_wallet_flutter/src/models/user_model.dart';
import 'package:bitorzo_wallet_flutter/ui/contacts/add_contact.dart';
import 'package:bitorzo_wallet_flutter/ui/contacts/contact_details.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/sheet_util.dart';

import '../../appstate_container.dart';

class UserCardWidget extends StatelessWidget {
  final UserModel user;
  const UserCardWidget({Key key, this.user})
      : assert(user != null),
        super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: 90.0,
      height: 90.0,


      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
      //  borderRadius: BorderRadius.circular(3.0),
        boxShadow: [
          BoxShadow(
            color: StateContainer.of(context).curTheme.backgroundDark,

            blurRadius: 0.0,
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[

          IconButton(
            icon: Icon(
              Icons.account_circle,
              color:StateContainer.of(context).curTheme.primary60,
              size: 34.0,
            ),
            onPressed: () {
              ContactDetailsSheet(user.contact, "").
              mainBottomSheet(context);
            }
          ),
          Padding(

            padding: const EdgeInsets.only(top: 0.0),
            child: Text(
              user.contact.name,
              style: TextStyle(
                  inherit: true,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.0,
                  color:StateContainer.of(context).curTheme.primary ),

              textAlign: TextAlign.center,
            )
            ,
          )
        ],
      ),
    );
  }
}
