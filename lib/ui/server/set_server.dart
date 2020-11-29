import 'package:auto_size_text/auto_size_text.dart';
import 'package:bitorzo_wallet_flutter/model/vault.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bitorzo_wallet_flutter/util/firebaseutil.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/dimens.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/bus/events.dart';
import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/styles.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/app_text_field.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/buttons.dart';
import 'package:bitorzo_wallet_flutter/ui/util/formatters.dart';
import 'package:bitorzo_wallet_flutter/ui/util/ui_util.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/tap_outside_unfocus.dart';
import 'package:bitorzo_wallet_flutter/util/caseconverter.dart';
import 'package:bitorzo_wallet_flutter/app_icons.dart';
import 'package:bitorzo_wallet_flutter/util/user_data_util.dart';

class SetServerSheet extends StatefulWidget {
  String serverAddress;

  SetServerSheet({this.serverAddress}) : super();

  _SetServerSheetState createState() => _SetServerSheetState();
}

class _SetServerSheetState extends State<SetServerSheet> {
  FocusNode _serverAddressFocusNode;
  FocusNode _addressFocusNode;
  TextEditingController _addressController;
  TextEditingController _serverAddressController;

  // State variables
  bool _showServerAddressHint;
  bool _addressValidAndUnfocused;
  String _nameValidationText;


  @override
  void initState() {
    super.initState();
    // Text field initialization
    this._serverAddressFocusNode = FocusNode();
    this._addressFocusNode = FocusNode();
    this._addressController = TextEditingController();
    this._serverAddressController = TextEditingController();
    // State initializationrue;

    this._showServerAddressHint = true;
    this._addressValidAndUnfocused = false;
    this._nameValidationText = "";


    // Add focus listeners
    // On name focus change
    _serverAddressFocusNode.addListener(() {
      if (_serverAddressFocusNode.hasFocus) {
        setState(() {
          _showServerAddressHint = false;
        });
      } else {
        setState(() {
          _showServerAddressHint = true;
        });
      }
    });
  }

  /// Return true if textfield should be shown, false if colorized should be shown
  bool _shouldShowTextField() {
    if (widget.serverAddress != null) {
      return false;
    } else if (_addressValidAndUnfocused) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return TapOutsideUnfocus(
      child: SafeArea(
        minimum: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.035),
        child: Column(
          children: <Widget>[
            // Top row of the sheet which contains the header and the scan qr button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Empty SizedBox
                SizedBox(
                  width: 60,
                  height: 60,
                ),
                // The header of the sheet
                Container(
                  margin: EdgeInsets.only(top: 30.0),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 140),
                  child: Column(
                    children: <Widget>[
                      AutoSizeText(
                        CaseChange.toUpperCase(
                            AppLocalization.of(context).setServerHeader,
                            context),
                        style: AppStyles.textStyleHeader(context),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        stepGranularity: 0.1,
                      ),
                    ],
                  ),
                ),

                // Scan QR Button
                SizedBox(
                  width: 60,
                  height: 60
                ),
              ],
            ),

            // The main container that holds "Enter Name" and "Enter Address" text fields
            Expanded(
              child: KeyboardAvoider(
                duration: Duration(milliseconds: 0),
                autoScroll: true,
                focusPadding: 40,
                child: Column(
                children: <Widget>[
                  // Enter Name Container
                  AppTextField(
                    topMargin: MediaQuery.of(context).size.height * 0.14,
                    padding: EdgeInsets.symmetric(horizontal: 30),
                        focusNode: _serverAddressFocusNode,
                        controller: _addressController,
                        textInputAction: widget.serverAddress != null
                            ? TextInputAction.done
                            : TextInputAction.next,
                        hintText: _showServerAddressHint ?? true
                            ? widget.serverAddress ??  AppLocalization.of(context).setServerAddressHint
                            : "",
                        keyboardType: TextInputType.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16.0,
                          color: StateContainer.of(context)
                              .curTheme
                              .text,
                          fontFamily: 'NunitoSans',
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(50),
                        ],
                        onSubmitted: (text) {
                      /*
                          if (widget.address == null) {


                            if (!Address(_phoneController.text)
                                .isValid()) {
                              FocusScope.of(context)
                                  .requestFocus(_addressFocusNode);
                            } else {
                              FocusScope.of(context).unfocus();
                            }
                          } else {
                            FocusScope.of(context).unfocus();
                          }
                         */
                        },


                      ),
                      // Enter Name Error Container
                      Container(
                        margin: EdgeInsets.only(top: 5, bottom: 5),
                        child: Text(_nameValidationText,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: StateContainer.of(context)
                                  .curTheme
                                  .primary,
                              fontFamily: 'NunitoSans',
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                      // Enter Address container
                  ],
                ),
              ),
            ),

            Container(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      // Set Server Address Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY_OUTLINE,
                          AppLocalization.of(context).restoreDefaultServerButton,
                          Dimens.BUTTON_TOP_EXCEPTION_DIMENS, onPressed: () async {
                        _addressController.text = "pay.bitorzo.io";
                      }),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      // Set Server Address Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY,
                          AppLocalization.of(context).setServerButton,
                          Dimens.BUTTON_TOP_DIMENS, onPressed: () async {
                        if (await validateForm()) {
                          await sl.get<SharedPrefsUtil>().setServerAddress(_addressController.text);
                          Navigator.pop(context);
                        }

                      }),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      // Close Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY_OUTLINE,
                          AppLocalization.of(context).close,
                          Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                        Navigator.pop(context);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }

  Future<bool> validateForm() async {

    bool isValid = true;
    // address Validations
    if (_addressController.text.isEmpty) {
      isValid = false;
      setState(() {
        _nameValidationText = AppLocalization.of(context).serverAddressMising;
      });
    }

    if(_addressController.text.startsWith("http://") || _addressController.text.startsWith("https://") ) {
      isValid = false;
      _nameValidationText = AppLocalization.of(context).serverAddressInvalidPrefix;
    } else {

    }

    return isValid;
  }
}
