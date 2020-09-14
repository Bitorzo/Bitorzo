import 'package:bitcoin_flutter/bitcoin_flutter.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/model/db/account.dart';
import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';


final _BITCOIN = new bip32.NetworkType(
    wif: 0x80,
    bip32: new bip32.Bip32Type(
        public: 0x0488b21e,
        private: 0x0488ade4
    )
);

final _BITCOIN_SEGWIT = new bip32.NetworkType(
    wif: 0x80,
    bip32: new bip32.Bip32Type(
        public: 0x04b24746,
        private: 0x04b2430c
    )
);

class BitcoinKeys {
  static String seedToPrivate(String seed, int index, bool is_segwit) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed), is_segwit ? _BITCOIN_SEGWIT : _BITCOIN);
    return HEX.encode(node.deriveHardened(index).privateKey);

    //assert(NanoSeeds.isValidSeed(seed));
    //assert(index >= 0);
    //return NanoHelpers.byteToHex(
    //    Ed25519Blake2b.derivePrivkey(NanoHelpers.hexToBytes(seed), index))
    //    .toUpperCase();
  }


  static String seedToBase58Derived(String seed, int index, bool is_segwit) {
    int purpose_num = is_segwit ? 84 : 44;
    final node = bip32.BIP32.fromSeed(HEX.decode(seed), is_segwit ? _BITCOIN_SEGWIT : _BITCOIN);

    // For backward compatability - different derivation path
    if(!is_segwit) {
      return node.deriveHardened(index).neutered().toBase58();
    }

    return node.deriveHardened(purpose_num) // bip 44/84?
        .deriveHardened(0x0) // Coin Type: bitcoin
        .deriveHardened(index).neutered().toBase58();
  }

  static String seedToPublicKeyDerived(String seed, int index, bool is_segwit) {

    int purpose_num = is_segwit ? 84 : 44;

    final node = bip32.BIP32.fromSeed(HEX.decode(seed), is_segwit ? _BITCOIN_SEGWIT : _BITCOIN);

    // For backward compatability - different derivation path
    if(!is_segwit) {
      return node.deriveHardened(index).neutered().toBase58();
    }


    return HEX.encode(
        node.deriveHardened(purpose_num) // bip 44/84?
            .deriveHardened(0x0) // Coin Type: bitcoin
            .deriveHardened(index).publicKey);
  }

  static String seedToPublicKey(String seed, bool is_segwit) {
      final node = bip32.BIP32.fromSeed(HEX.decode(seed), is_segwit ? _BITCOIN_SEGWIT : _BITCOIN);
    return HEX.encode(node.publicKey);
  }


  static String seedToWIF(String seed, bool is_segwit) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed), is_segwit ? _BITCOIN_SEGWIT : _BITCOIN);
    return node.toWIF();
  }
}


class BitcoinUtil {
  static String seedToPrivate(String seed, int index, bool is_segwit) {
    return BitcoinKeys.seedToPrivate(seed, index, is_segwit);
  }

  static Future<http.Response> publishTx(String hextx) {
    //print(hextx);


    // TODO : Allow user to set his own Esplora server address (or implement that into Bitorzo Server as well).
    return http.post(
      'https://blockstream.info/api/tx',
      body: hextx);

    return http.post(
      'https://blockchain.info/pushtx',
      body: {
        'tx': hextx,
      }

      /*
      headers: <String, String>{
        'Content-Type': 'plain/text',
      },

      body: jsonEncode(<String, String>{
        'tx': hextx,
      }),
*/

    );
  }

  static String seedToAddress(String seed, int index, bool is_segwit, {base58: true}) {
    //return NanoAccounts.createAccount(NanoAccountType.NANO, BitcoinKeys.createPublicKey(seed, index));
    if(base58) {
      return BitcoinKeys.seedToBase58Derived(seed, index, is_segwit);
    } else {
      return BitcoinKeys.seedToPublicKeyDerived(seed, index, is_segwit);
    }
  }

  Future<void> loginAccount(String seed, bool is_segwit, BuildContext context) async {
    Account selectedAcct = await sl.get<DBHelper>().getSelectedAccount(seed, is_segwit);
    if (selectedAcct == null) {
      selectedAcct = Account(index: 0, lastAccess: 0, name: AppLocalization.of(context).defaultAccountName, selected: true);
      await sl.get<DBHelper>().saveAccount(selectedAcct);
    }
    StateContainer.of(context).updateWallet(account: selectedAcct);
  }
}
