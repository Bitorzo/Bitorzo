import 'dart:async';
import 'package:bip32/bip32.dart' as bip32;
import 'package:flutter/cupertino.dart';
import 'package:hex/hex.dart';
import '../service_locator.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:bitcoin_flutter/src/payments/p2Wpkh.dart';
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;

String getAddress(node, {network, segwit:true} ) {

  return segwit?
  P2WPKH(
      data: new PaymentData(pubkey: node.publicKey), network: network).data
      .address :
  P2PKH(
      data: new PaymentData(pubkey: node.publicKey), network: network).data
      .address;
}

class AddressUtil {
  final Logger log = sl.get<Logger>();

  static Future<String> getDerivedReceiveAddress(String seed, int account_index, int address_id, {is_segwit = true, is_change = false}) async {
    bip32.BIP32 wallet = bip32.BIP32.fromSeed(HEX.decode(seed));
    int purpose_num = is_segwit ? 84 : 44;

    final child_public_key = getAddress(
      // Backward compatability
        is_segwit?
        wallet
            .deriveHardened(purpose_num) // Purpose: BIP44 hardened
            .deriveHardened(0x0) // Coin Type: bitcoin
            .deriveHardened(account_index) // account
            .derive(is_change? 1 : 0)
            .derive(address_id + 1) :
        wallet
            .deriveHardened(account_index) // account
            .derive(is_change? 1 : 0)
            .derive(address_id + 1)

        ,  // address_index
        segwit:is_segwit);

  return child_public_key;
  }

  static Future<String> getDerivedChangeAddress(String seed, int account_index, int address_id, {is_segwit = true}) async {
    print(seed);
    print(account_index);
    print(address_id);
    return getDerivedReceiveAddress(seed, account_index, address_id, is_segwit: is_segwit, is_change: true);
  }


  // For future encrypted xpub feature
  static Future<String> getDerivedXpub(String seed, int account_index, int derived_contact_xpub_index, {is_segwit = true}) async {
    bip32.BIP32 wallet = bip32.BIP32.fromSeed(HEX.decode(seed));
    int purpose_num = is_segwit ? 84 : 44;

    // Backward compatability
    return is_segwit?
    wallet
        .deriveHardened(purpose_num) // Purpose: BIP44 hardened
        .deriveHardened(0x0) // Coin Type: bitcoin
        .deriveHardened(account_index) // account
        .deriveHardened(derived_contact_xpub_index).neutered().toBase58()  // contact hardened xpub
        :
    wallet
        .deriveHardened(account_index) // account
        .deriveHardened(derived_contact_xpub_index).neutered().toBase58(); // contact hardened xpub


  }

}