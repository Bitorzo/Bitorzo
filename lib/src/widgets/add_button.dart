import 'package:flutter/material.dart';
import 'package:bitorzo_wallet_flutter/ui/contacts/add_contact.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/sheet_util.dart';

import '../../appstate_container.dart';

class AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(right: 0.0),
      alignment: Alignment.center,
      padding: EdgeInsets.all(0.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),

      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[

          IconButton(
            icon: Icon(
              Icons.add_circle,
              color: StateContainer.of(context).curTheme.primary,
            ),
            onPressed: () =>   Sheets.showAppHeightNineSheet(
                context: context, widget: AddContactSheet()),
            iconSize:24.0,
          ),

        ],
      ),
    );
  }
}
