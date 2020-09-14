import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keyboard_avoider/keyboard_avoider.dart';

import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:logger/logger.dart';

import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/bus/events.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/dimens.dart';
import 'package:bitorzo_wallet_flutter/network/account_service.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/process_response.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/ui/util/ui_util.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/app_text_field.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/sheets.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/buttons.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/dialog.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/security.dart';
import 'package:bitorzo_wallet_flutter/ui/util/routes.dart';
import 'package:bitorzo_wallet_flutter/styles.dart';
import 'package:bitorzo_wallet_flutter/app_icons.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/tap_outside_unfocus.dart';
import 'package:bitorzo_wallet_flutter/util/bitcoinutil.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:bitorzo_wallet_flutter/util/biometrics.dart';
import 'package:bitorzo_wallet_flutter/util/hapticutil.dart';
import 'package:bitorzo_wallet_flutter/util/caseconverter.dart';
import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/model/authentication_method.dart';
import 'package:bitorzo_wallet_flutter/model/vault.dart';

// TODO - add validations
/* This class not needed for this project (BTC)
class AppChangeRepresentativeManualEntrySheet {
  FocusNode _repFocusNode;
  TextEditingController _repController;

  String _changeRepHint = "";
  TextStyle _repAddressStyle;
  bool _showPasteButton = true;
  bool _addressValidAndUnfocused = false;
  bool _animationOpen = false;

  AppChangeRepresentativeManualEntrySheet() {
    _repFocusNode = new FocusNode();
    _repController = new TextEditingController();
  }

  StreamSubscription<AuthenticatedEvent> _authSub;

  void _registerBus(BuildContext context) {
    _authSub = EventTaxiImpl.singleton()
        .registerTo<AuthenticatedEvent>()
        .listen((event) {
      if (event.authType == AUTH_EVENT_TYPE.CHANGE_MANUAL) {
        doChange(context);
      }
    });
  }

  void _destroyBus() {
    if (_authSub != null) {
      _authSub.cancel();
    }
  }

  Future<bool> _onWillPop() async {
    _destroyBus();
    return true;
  }

  mainBottomSheet(BuildContext context) {
    _changeRepHint = AppLocalization.of(context).changeRepHint;
    _repAddressStyle = AppStyles.textStyleAddressText60(context);
    AppSheets.showAppHeightEightSheet(
        context: context,
        builder: (BuildContext context) {
          _registerBus(context);
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            // On address focus change
            _repFocusNode.addListener(() {
              if (_repFocusNode.hasFocus) {
                setState(() {
                  _changeRepHint = "";
                  _addressValidAndUnfocused = false;
                });
                _repController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _repController.text.length));
              } else {
                setState(() {
                  _changeRepHint = AppLocalization.of(context).changeRepHint;
                  if (Address(_repController.text).isValid()) {
                    _addressValidAndUnfocused = true;
                  }
                });
              }
            });
            return WillPopScope(
                onWillPop: _onWillPop,
                child: TapOutsideUnfocus(
                  child: SafeArea(
                    minimum: EdgeInsets.only(
                      bottom: MediaQuery.of(context).size.height * 0.035,
                    ),
                    child: Container(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          //A container for the header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(width: 60, height:60),
                              //Container for the header
                              Column(
                                children: <Widget>[
                                  // Sheet handle
                                  Container(
                                    margin: EdgeInsets.only(top: 10),
                                    height: 5,
                                    width: MediaQuery.of(context).size.width *
                                        0.15,
                                    decoration: BoxDecoration(
                                      color: StateContainer.of(context)
                                          .curTheme
                                          .text10,
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(top: 15),
                                    constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width -
                                                140),
                                    child: AutoSizeText(
                                      CaseChange.toUpperCase(
                                          AppLocalization.of(context)
                                              .changeRepAuthenticate,
                                          context),
                                      style: AppStyles.textStyleHeader(context),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      stepGranularity: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                              // Empty sized box
                              SizedBox(width: 60, height:60),
                            ],
                          ),

                          //A expanded section for current representative and new representative fields
                          Expanded(
                            child: KeyboardAvoider(
                              duration: Duration(milliseconds: 0),
                              autoScroll: true,
                              focusPadding: 40,
                              child: Column(
                                children: <Widget>[
                                  // New representative
                                  AppTextField(
                                    topMargin: MediaQuery.of(context).size.height * 0.05,
                                    padding: _addressValidAndUnfocused
                                        ? EdgeInsets.symmetric(
                                            horizontal: 25.0, vertical: 15.0)
                                        : EdgeInsets.zero,
                                    focusNode: _repFocusNode,
                                    controller: _repController,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(
                                          65),
                                    ],
                                    textInputAction: TextInputAction.done,
                                    maxLines: null,
                                    autocorrect: false,
                                    hintText: _changeRepHint,
                                    prefixButton: TextFieldButton(
                                      icon: AppIcons.scan,
                                      onPressed: () {
                                        UIUtil.cancelLockEvent();
                                          BarcodeScanner.scan(
                                                  StateContainer.of(context)
                                                      .curTheme
                                                      .qrScanTheme)
                                              .then((result) {
                                            if (result == null) {
                                              return;
                                            }
                                            Address address = new Address(result);
                                            if (address.isValid()) {
                                              setState(() {
                                                _addressValidAndUnfocused = true;
                                                _showPasteButton = false;
                                                _repAddressStyle =
                                                    AppStyles.textStyleAddressText60(
                                                        context);
                                              });
                                              _repController.text = address.address;
                                              _repFocusNode.unfocus();
                                            } else {
                                              UIUtil.showSnackbar(
                                                  AppLocalization.of(context)
                                                      .qrInvalidAddress,
                                                  context);
                                            }
                                          });                                         
                                      },
                                    ),
                                    fadePrefixOnCondition: true,
                                    prefixShowFirstCondition: _showPasteButton,
                                    suffixButton: TextFieldButton(
                                      icon: AppIcons.paste,
                                      onPressed: () {
                                        if (!_showPasteButton) {
                                          return;
                                        }
                                        Clipboard.getData("text/plain")
                                            .then((ClipboardData
                                                data) {
                                          if (data == null ||
                                              data.text ==
                                                  null) {
                                            return;
                                          }
                                          Address address =
                                              new Address(
                                                  data.text);
                                          if (address
                                              .isValid()) {
                                            setState(() {
                                              _addressValidAndUnfocused =
                                                  true;
                                              _showPasteButton =
                                                  false;
                                              _repAddressStyle =
                                                  AppStyles
                                                      .textStyleAddressText90(
                                                          context);
                                            });
                                            _repController
                                                    .text =
                                                address.address;
                                            _repFocusNode
                                                .unfocus();
                                          }
                                        });
                                      },
                                    ),
                                    fadeSuffixOnCondition: true,
                                    suffixShowFirstCondition: _showPasteButton,
                                    keyboardType: TextInputType.text,
                                    style: _repAddressStyle,
                                    onChanged: (text) {
                                      if (Address(text).isValid()) {
                                        _repFocusNode.unfocus();
                                        setState(() {
                                          _showPasteButton = false;
                                          _repAddressStyle = AppStyles
                                              .textStyleAddressText90(
                                                  context);
                                        });
                                      } else {
                                        setState(() {
                                          _showPasteButton = true;
                                          _repAddressStyle = AppStyles
                                              .textStyleAddressText60(
                                                  context);
                                        });
                                      }
                                    },
                                    overrideTextFieldWidget: _addressValidAndUnfocused ?
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _addressValidAndUnfocused =
                                                false;
                                          });
                                          Future.delayed(
                                              Duration(milliseconds: 50),
                                              () {
                                            FocusScope.of(context)
                                                .requestFocus(
                                                    _repFocusNode);
                                          });
                                        },
                                        child:
                                            UIUtil.threeLineAddressText(
                                                context,
                                                _repController.text),
                                      )
                                    : null,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          //A row with change and close button
                          Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  AppButton.buildAppButton(
                                    context,
                                    AppButtonType.PRIMARY,
                                    AppLocalization.of(context)
                                        .changeRepButton
                                        .toUpperCase(),
                                    Dimens.BUTTON_TOP_DIMENS,
                                    onPressed: () async {

                                      // TODO : implement for BTC
                                      //if (!NanoAccounts.isValid(
                                     //     NanoAccountType.NANO,
                                     //     _repController.text)) {
                                      //  return;
                                      //}
                                      // Authenticate
                                      AuthenticationMethod authMethod = await sl.get<SharedPrefsUtil>().getAuthMethod();
                                      bool hasBiometrics = await sl.get<BiometricUtil>().hasBiometrics();
                                      if (authMethod.method == AuthMethod.BIOMETRICS && hasBiometrics) {
                                        try {
                                          bool authenticated = await sl.get<BiometricUtil>()
                                                      .authenticateWithBiometrics(
                                                          context,
                                                          AppLocalization.of(
                                                                  context)
                                                              .changeRepAuthenticate);
                                          if (authenticated) {
                                            sl.get<HapticUtil>().fingerprintSucess();
                                            EventTaxiImpl.singleton()
                                                .fire(AuthenticatedEvent(AUTH_EVENT_TYPE.CHANGE_MANUAL));                                               
                                          }
                                        } catch(e) {
                                          await authenticateWithPin(context);
                                        }
                                      } else {
                                        await authenticateWithPin(context);
                                      }                        
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: <Widget>[
                                  AppButton.buildAppButton(
                                    context,
                                    AppButtonType.PRIMARY_OUTLINE,
                                    CaseChange.toUpperCase(
                                        AppLocalization.of(context).close,
                                        context),
                                    Dimens.BUTTON_BOTTOM_DIMENS,
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  )
                )   
            );
          });
        });
  }

  Future<void> doChange(BuildContext context) async {
    _animationOpen = true;
    Navigator.of(context).push(
        AnimationLoadingOverlay(
            AnimationType.GENERIC,
            StateContainer.of(context)
                .curTheme
                .animationOverlayStrong,
            StateContainer.of(context)
                .curTheme
                .animationOverlayMedium,
            onPoppedCallback: () =>
                _animationOpen =
                    false));
      // If account isnt open, just store the account in sharedprefs
      if (StateContainer.of(context).wallet.openBlock == null) {
        await sl.get<SharedPrefsUtil>().setRepresentative(_repController.text);
        StateContainer.of(context).wallet.representative = _repController.text;
        UIUtil.showSnackbar(AppLocalization.of(context).changeRepSucces, context);
        Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
      } else {
        try {
          ProcessResponse resp = await sl.get<AccountService>().requestChange(
            StateContainer.of(context).wallet.address,
            _repController.text,
            StateContainer.of(context).wallet.frontier,
            StateContainer.of(context).wallet.accountBalance.toString(),
            BitcoinUtil.seedToPrivate(await sl.get<Vault>().getSeed(), StateContainer.of(context).selectedAccount.index)
          );
          StateContainer.of(context).wallet.representative = _repController.text;
          StateContainer.of(context).wallet.frontier = resp.hash;
          UIUtil.showSnackbar(AppLocalization.of(context).changeRepSucces, context);
          Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));                                              
        } catch (e) {
          sl.get<Logger>().e("Failed to change", e);
          if (_animationOpen) {
            Navigator.of(context).pop();
          }
          UIUtil.showSnackbar(AppLocalization.of(context).sendError, context);
        }
      }    
  }

  Future<void> authenticateWithPin(BuildContext context) async {
    // PIN Authentication
    String expectedPin = await sl.get<Vault>().getPin();
    bool auth = await Navigator.of(context).push(
        MaterialPageRoute(builder:
            (BuildContext context) {
      return new PinScreen(
        PinOverlayType.ENTER_PIN,
        expectedPin: expectedPin,
        description:
            AppLocalization.of(context)
                .pinRepChange,
      );
    }));
    if (auth != null && auth) {
      await Future.delayed(Duration(milliseconds: 200));
      EventTaxiImpl.singleton()
      .fire(AuthenticatedEvent(AUTH_EVENT_TYPE.CHANGE_MANUAL));   
    }
  }
}
*/