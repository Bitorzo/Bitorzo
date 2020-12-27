import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:manta_dart/manta_wallet.dart';
import 'package:manta_dart/messages.dart';
import 'package:bitorzo_wallet_flutter/app_icons.dart';
import 'dart:convert';
import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/bus/events.dart';
import 'package:bitorzo_wallet_flutter/dimens.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';
import 'package:bitorzo_wallet_flutter/network/account_service.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/process_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/utxos_for_tx_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/utxos_for_tx_response_item.dart';
import 'package:bitorzo_wallet_flutter/styles.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/ui/send/send_complete_sheet.dart';
import 'package:bitorzo_wallet_flutter/ui/util/routes.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/buttons.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/dialog.dart';
import 'package:bitorzo_wallet_flutter/ui/util/ui_util.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/sheet_util.dart';
import 'package:bitorzo_wallet_flutter/util/bitcoinutil.dart';
import 'package:bitorzo_wallet_flutter/util/firebaseutil.dart';
import 'package:bitorzo_wallet_flutter/util/addressutil.dart';
import 'package:bitorzo_wallet_flutter/util/numberutil.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:bitorzo_wallet_flutter/util/biometrics.dart';
import 'package:bitorzo_wallet_flutter/util/hapticutil.dart';
import 'package:bitorzo_wallet_flutter/util/caseconverter.dart';
import 'package:bitorzo_wallet_flutter/model/authentication_method.dart';
import 'package:bitorzo_wallet_flutter/model/vault.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/security.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;


class NotEnoughFundsForFeeException implements Exception {
  final _message;
  NotEnoughFundsForFeeException([this._message]);

  String toString() {
    if (_message == null) return "Not enough funds for fee";
    return "Exception: $_message";
  }
}


class SendConfirmSheet extends StatefulWidget {
  final String amountRaw;
  final String destination;
  final AppContact contact;
  final String localCurrency;
  final bool maxSend;
  final MantaWallet manta;
  final PaymentRequestMessage paymentRequest;

  SendConfirmSheet(
      {this.amountRaw,
        this.destination,
        this.contact,
        this.localCurrency,
        this.manta,
        this.paymentRequest,
        this.maxSend = false})
      : super();

  _SendConfirmSheetState createState() => _SendConfirmSheetState();
}

class _SendConfirmSheetState extends State<SendConfirmSheet> {
  String amount;
  String destinationAltered;
  bool animationOpen;
  bool isMantaTransaction;
  String unusedChangeAddress;
  int calculatedFees = -1;
  dynamic fees_json = null;

  // Depracted
  //double fastestFees = 0;
  //double hourFees = 0;
  //double dayFees = 0;
  //double halfHourFees = -1;
  String calculatedFeesDisplay = "...";
  double _fees_slider_value = 0;
  bool requestConfirmState = true;
  int tx_vsize = -1;
  List<UTXOSforTXResponseItem> UTXOS = null;

  StreamSubscription<AuthenticatedEventWithFees> _authSub;

  void _registerBus() {
    _authSub = EventTaxiImpl.singleton()
        .registerTo<AuthenticatedEventWithFees>()
        .listen((event) {
      if (event.authType == AUTH_EVENT_TYPE.SEND) {
        _doSend(fees: event.fees);
      }
    });
  }

  void _destroyBus() {
    if (_authSub != null) {
      _authSub.cancel();
    }
  }

  void updateCalculatedFees(double new_fee) {
    calculatedFees = (new_fee * tx_vsize).toInt();

    calculatedFeesDisplay = NumberUtil.SatoshiToMilliBTC(calculatedFees.toString());
  }

  @override
  void initState() {
    super.initState();
    _registerBus();
    this.animationOpen = false;
    this.isMantaTransaction = widget.manta != null && widget.paymentRequest != null;
    // Derive amount from raw amount

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _estimateFees().then((result)
      { setState(() {

        fees_json = result;
        //dayFees = result["144"]?.toDouble() ?? 0;
        //hourFees = result["6"]?.toDouble() ?? 0;
        //halfHourFees = result["3"]?.toDouble() ?? 0;
        //fastestFees = result["1"]?.toDouble() ?? 0;
        _fees_slider_value = 5 ;
        updateCalculatedFees(result["1"]);
      }); }
      );
    });

    /*
       .catchError((error,stackTrace)
   {

   });

*/

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      int account_index  = StateContainer.of(context).selectedAccount.index;
      int change_address_id = await sl.get<SharedPrefsUtil>().incrementLastUsedChangeAddressId();
      String seed = await StateContainer.of(context).getSeed();
      bool is_segwit = await StateContainer.of(context).isSegwit();


      AddressUtil.getDerivedChangeAddress(seed, account_index, change_address_id, is_segwit:is_segwit).then((result)
      { setState(() {
        unusedChangeAddress = result;
      });}).catchError((error, stackTrace) {
        if (animationOpen) {
          Navigator.of(context).pop();
        }
        UIUtil.showSnackbar(AppLocalization
            .of(context)
            .noChangeKeyAvailable, context);
        Navigator.of(context).pop();
      });
    });

    // estimate tx size

    amount = widget.amountRaw;

    //if (NumberUtil.getRawAsUsableString(widget.amountRaw).replaceAll(",", "") ==
    //    NumberUtil.getRawAsUsableDecimal(widget.amountRaw).toString()) {
    //  amount = NumberUtil.getRawAsUsableString(widget.amountRaw);
    //} else {
    //  amount = NumberUtil.truncateDecimal(
    //              NumberUtil.getRawAsUsableDecimal(widget.amountRaw),
    //              digits: 6)
    //          .toStringAsFixed(6) +
    //      "~";
    //}
    // Ensure nano_ prefix on destination
    //destinationAltered = widget.destination.replaceAll("xrb_", "nano_");
    destinationAltered = widget.destination;
  }

  @override
  void dispose() {
    _destroyBus();
    super.dispose();
  }

  void _showSendingAnimation(BuildContext context) {
    animationOpen = true;
    Navigator.of(context).push(AnimationLoadingOverlay(
        AnimationType.SEND,
        StateContainer.of(context).curTheme.animationOverlayStrong,
        StateContainer.of(context).curTheme.animationOverlayMedium,
        onPoppedCallback: () => animationOpen = false));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        minimum:
        EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.035),
        child: Column(
          children: <Widget>[
            // Sheet handle
            Container(
              margin: EdgeInsets.only(top: 10),
              height: 5,
              width: MediaQuery.of(context).size.width * 0.15,
              decoration: BoxDecoration(
                color: StateContainer.of(context).curTheme.text10,
                borderRadius: BorderRadius.circular(100.0),
              ),
            ),
            //The main widget that holds the text fields, "SENDING" and "TO" texts
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // "SENDING" TEXT
                  Container(
                    margin: EdgeInsets.only(bottom: 10.0),
                    child: Column(
                      children: <Widget>[
                        Text(
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).sending, context),
                          style: AppStyles.textStyleHeader(context),
                        ),
                      ],
                    ),
                  ),
                  // Container for the amount and estimated fees text
                  // Estimated fee
                  Container(
                      margin: EdgeInsets.only(
                          left: MediaQuery.of(context).size.width * 0.105,
                          right: MediaQuery.of(context).size.width * 0.105),
                      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:
                        StateContainer.of(context).curTheme.backgroundDarkest,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      // Amount text
                      child:
                      Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: '',
                                children: [
                                  TextSpan(
                                    text: "$amount",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: " mBTC",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w100,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: widget.localCurrency != null
                                        ? " (${widget.localCurrency})"
                                        : "",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: '',
                                children: [
                                  TextSpan(
                                    text: "($calculatedFeesDisplay",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: "${AppLocalization
                                        .of(context)
                                        .estimatedFees})",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w100,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                  TextSpan(
                                    text: widget.localCurrency != null
                                        ? " (${widget.localCurrency})"
                                        : "",
                                    style: TextStyle(
                                      color:
                                      StateContainer.of(context).curTheme.primary,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'NunitoSans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Slider(
                              min: tx_vsize == 0 ? 0 : 0,
                              max: tx_vsize == 0 ? 0 : 5,
                              label: fees_json == null ? "Loading fee info"
                                  : _fees_slider_value > 4 ?
                              "Fastest (${fees_json["1"]?.toDouble()?.toStringAsFixed(3) ?? "unkn"} sat/vb)":

                              _fees_slider_value < 1 ?
                              "~Day (${fees_json["144"]?.toDouble()?.toStringAsFixed(3) ?? "unkn"} sat/vb)" :
                              "~${(4-_fees_slider_value).ceil()*10} min (${fees_json[(4-_fees_slider_value).ceil().toString()]?.toDouble()?.toStringAsFixed(3) ?? "unkn"} sat/vb)"
                              ,
                              divisions: 4,
                              value: tx_vsize == 0 ? 0 : _fees_slider_value ,
                              onChanged: (value) {
                                setState(() {
                                  _fees_slider_value = value;
                                  updateCalculatedFees(
                                      _fees_slider_value > 4 ?
                                      fees_json["1"] :
                                      _fees_slider_value < 1 ?
                                      fees_json["144"] :
                                      fees_json[(4-_fees_slider_value).ceil().toString()]

                                  );
                                });
                              },
                            )
                          ])
                  ),

                  // "TO" text
                  Container(
                    margin: EdgeInsets.only(top: 15.0, bottom: 10),
                    child: Column(
                      children: <Widget>[
                        Text(
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).to, context),
                          style: AppStyles.textStyleHeader(context),
                        ),
                      ],
                    ),
                  ),
                  // Address text
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 25.0, vertical: 15.0),
                    margin: EdgeInsets.only(
                        left: MediaQuery.of(context).size.width * 0.105,
                        right: MediaQuery.of(context).size.width * 0.105),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: StateContainer.of(context)
                          .curTheme
                          .backgroundDarkest,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child:
                    Column( children: [
                      UIUtil.threeLineAddressText(
                          context, destinationAltered,
                          contactName: widget.contact?.name ?? ""),
                      Container(
                        margin: EdgeInsets.only(top: 5.0, bottom: 0),
                        child: widget.contact != null ?  Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                                CaseChange.toUpperCase(
                                    AppLocalization.of(context).requestConfirmation, context),
                                style: AppStyles.textStyleButtonPrimarySmallOutline(context),
                                textAlign: TextAlign.center
                            ),
                            Switch(
                              value: requestConfirmState,
                              onChanged: (value) {
                                setState(() {
                                  requestConfirmState = value;

                                });
                              },
                              activeTrackColor: Colors.lightGreenAccent,
                              activeColor: Colors.green,
                            ),
                          ],
                        ) : Container(),
                      ),
                    ]),
                  ),



                ],
              ),
            ),

            //A container for CONFIRM and CANCEL buttons
            Container(
              child: Column(
                children: <Widget>[
                  // A row for CONFIRM Button
                  Row(
                    children: <Widget>[
                      // CONFIRM Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY,
                          (calculatedFees == -1) ?
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).confirm_wait_fees, context) :
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).confirm, context),
                          Dimens.BUTTON_TOP_DIMENS, disabled: (calculatedFees == -1), onPressed: () async {
                        // Authenticate
                        AuthenticationMethod authMethod = await sl.get<SharedPrefsUtil>().getAuthMethod();
                        bool hasBiometrics = await sl.get<BiometricUtil>().hasBiometrics();
                        if (authMethod.method == AuthMethod.BIOMETRICS &&
                            hasBiometrics) {
                          try {
                            bool authenticated = await sl
                                .get<BiometricUtil>()
                                .authenticateWithBiometrics(
                                context,
                                AppLocalization.of(context)
                                    .sendAmountConfirm
                                    .replaceAll("%1", amount));



                            if (authenticated) {
                              sl.get<HapticUtil>().fingerprintSucess();
                              EventTaxiImpl.singleton()
                                  .fire(AuthenticatedEventWithFees(AUTH_EVENT_TYPE.SEND, calculatedFees));
                            }
                          } catch (e) {
                            await authenticateWithPin();
                          }
                        } else {
                          await authenticateWithPin();
                        }
                      }
                      )
                    ],
                  ),
                  // A row for CANCEL Button
                  Row(
                    children: <Widget>[
                      // CANCEL Button
                      AppButton.buildAppButton(
                          context,
                          AppButtonType.PRIMARY_OUTLINE,
                          CaseChange.toUpperCase(
                              AppLocalization.of(context).cancel, context),
                          Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                        Navigator.of(context).pop();
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ));
  }


  Future<int> _getTxVirtualSize() async {
    Transaction tx = await buildTx(fees : 0); // dummy fees
    int tx_vsize = tx.virtualSize();  // tx.byteLength();
    return tx_vsize;
  }

  Future<Map<String, dynamic>> _estimateFees() async {

    final result = await _getTxVirtualSize();

    tx_vsize = result;

    int dummy_fees = 0; // Just to create a tx and
    String fees_estimation_json_url = "https://blockstream.info/api/fee-estimates";


    // Retrieve online fee estimation

    final res = await http.get(fees_estimation_json_url, headers: {"Accept": "aplication/json"});
    var fees_json = json.decode(res.body);
    return fees_json;
  }

  Future<Transaction> buildTx({int fees}) async {

    // await StateContainer.of(context).requestUtxoForTx(amount: NumberUtil.MilliBTCToSatoshi(widget.amountRaw));
    // Request server for utxos to use in the transaction

    bool is_segwit = await StateContainer.of(context).isSegwit();

    int total_outputs_needed =
    min<int>((BigInt.parse(NumberUtil.MilliBTCToSatoshi(widget.amountRaw)) + BigInt.from(fees)).toInt(), StateContainer.of(context).wallet.accountBalance.toInt());

    final resp = await sl.get<AccountService>().requestUtxosForTX(
        account: StateContainer
            .of(context)
            .wallet
            .address, amount: total_outputs_needed.toString());

    if (resp.utxos.length == 0) {
      throw new Exception("No UTXOS available for that address");
    }

    UTXOS = resp.utxos;
    BigInt sum_UTXO_outputs = BigInt.from(0);
    for(UTXOSforTXResponseItem i in UTXOS) {
      sum_UTXO_outputs +=  BigInt.parse(i.total_output_amount);
    }

    // Lets sign the tx
    int witness_value = 0;
    String seed = await StateContainer.of(context).getSeed();
    bip32.BIP32 wallet = bip32.BIP32.fromSeed(HEX.decode(seed));
    final txb = new TransactionBuilder();
    txb.setVersion(1);

    // Add all needed unspent outputs as inputs to the new bitcoin tx


    if(BigInt.from(int.parse(NumberUtil.MilliBTCToSatoshi(widget.amountRaw)) + fees) >= sum_UTXO_outputs) {
      if(sum_UTXO_outputs.toInt() - fees < 0) {

        throw NotEnoughFundsForFeeException();
      }
      witness_value = sum_UTXO_outputs.toInt() - fees;
      txb.addOutput(widget.destination, witness_value);

    } else {
      final change_after_fees = sum_UTXO_outputs - BigInt.parse(NumberUtil.MilliBTCToSatoshi(widget.amountRaw)) - BigInt.from(fees);

      witness_value = int.parse(NumberUtil.MilliBTCToSatoshi(widget.amountRaw));
      txb.addOutput(widget.destination, witness_value);

      txb.addOutput(unusedChangeAddress, change_after_fees.toInt()); // change

    }

    for(final utxo in UTXOS) {
      if(is_segwit) {
        final p2wpkh = new P2WPKH(
            data: new PaymentData(address: utxo.address))
            .data;

        txb.addInput(utxo.tx_hash,int.parse(utxo.vout), null, p2wpkh.output);
      } else {
        txb.addInput(utxo.tx_hash,int.parse(utxo.vout));
      }
    }

    int vin_counter = 0 ;
    for(final utxo in UTXOS) {

      ECPair ec = ECPair.fromPrivateKey(
        // Backward compatability
          is_segwit ?
          wallet
              .deriveHardened(is_segwit ? 84 : 44) // Purpose: BIP44 hardened
              .deriveHardened(0x0) // Coin Type: bitcoin
              .deriveHardened(StateContainer.of(context).selectedAccount.index)
              .derivePath(utxo.address_path).privateKey :
          wallet.deriveHardened(StateContainer.of(context).selectedAccount.index)
              .derivePath(utxo.address_path).privateKey);
      txb.sign(vin: vin_counter, keyPair: ec, witnessValue: int.parse(utxo.total_output_amount));
      vin_counter += 1;
    }

    // Send to destination, and find
    return txb.build();
  }



  Future<void> _doSend({int fees, bool request_confirm = true}) async {

    _showSendingAnimation(context);

    try {

      Transaction final_output = await buildTx(fees: fees);

      // After the creation of the tx we can mark change address as used

      if (this.requestConfirmState && widget.contact != null) {
        // In this case do not publish to web, just to firebase
        FirebaseUtil.addPendingRequest(widget.contact.phone,
            BigInt.parse(NumberUtil.MilliBTCToSatoshi(widget.amountRaw))
                .toInt(), final_output.toHex());
        //FirebaseUtil.markChangeAddressAsUsed(unusedChangeAddress);
      } else {
        Response response = await BitcoinUtil.publishTx(final_output.toHex());

        if (response.statusCode == 200) {

        } else {

          throw new Exception(
              'Publish tx request failed with status: ${response.statusCode}.');
        }

        //FirebaseUtil.markChangeAddressAsUsed(unusedChangeAddress);

        if (widget.contact != null) {
          FirebaseUtil.markContactPublicAddressAsUsed(
              widget.contact.phone, widget.destination);
        }


      }
      // Now mark ddreeses as used


      //final child_public_key = getAddress()
      /*
      ProcessResponse resp = await sl.get<AccountService>().requestSend(
        StateContainer.of(context).wallet.representative,
        StateContainer.of(context).wallet.frontier,
        widget.amountRaw,
        destinationAltered,
        StateContainer.of(context).wallet.address,
        BitcoinUtil.seedToPrivate(await StateContainer.of(context).getSeed(), StateContainer.of(context).selectedAccount.index),
        max: widget.maxSend
      );


      if (widget.manta != null) {
        widget.manta.sendPayment(
            transactionHash: resp.hash, cryptoCurrency: "NANO");
      }
      StateContainer.of(context).wallet.frontier = resp.hash;
      StateContainer.of(context).wallet.accountBalance += BigInt.parse(widget.amountRaw);
      // Show complete
      AppContact contact = await sl.get<DBHelper>().getContactWithAddress(widget.destination);
      String contactName = contact == null ? null : contact.name;
      Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
      StateContainer.of(context).requestUpdate();
       */

      String contactName = widget.contact?.name ?? "";
      Sheets.showAppHeightNineSheet(
          context: context,
          closeOnTap: true,
          removeUntilHome: true,
          widget: SendCompleteSheet(
              amountRaw: widget.amountRaw,
              destination: destinationAltered,
              contactName: contactName,
              localAmount: widget.localCurrency,
              paymentRequest: widget.paymentRequest));
    } on NotEnoughFundsForFeeException catch(e) {
      if (animationOpen) {
        Navigator.of(context).pop();
      }
      UIUtil.showSnackbar(e.toString(), context);
      Navigator.of(context).pop();
    } catch (e) {
      // Send failed
      if (animationOpen) {
        Navigator.of(context).pop();
      }

      UIUtil.showSnackbar(AppLocalization.of(context).sendError, context);
      Navigator.of(context).pop();
    }



  }

  Future<void> authenticateWithPin() async {
    // PIN Authentication
    String expectedPin = await sl.get<Vault>().getPin();
    bool auth = await Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) {
          return new PinScreen(
            PinOverlayType.ENTER_PIN,
            expectedPin: expectedPin,
            description: AppLocalization.of(context)
                .sendAmountConfirmPin
                .replaceAll("%1", amount),
          );
        }));
    if (auth != null && auth) {
      await Future.delayed(Duration(milliseconds: 200));
      EventTaxiImpl.singleton()
          .fire(AuthenticatedEventWithFees(AUTH_EVENT_TYPE.SEND, calculatedFees));
    }
  }
}
