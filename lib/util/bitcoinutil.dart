import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/model/db/account.dart';
import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';

class BitcoinKeys {
  static String seedToPrivate(String seed, int index) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed));
    return HEX.encode(node.deriveHardened(index).privateKey);

    //assert(NanoSeeds.isValidSeed(seed));
    //assert(index >= 0);
    //return NanoHelpers.byteToHex(
    //    Ed25519Blake2b.derivePrivkey(NanoHelpers.hexToBytes(seed), index))
    //    .toUpperCase();
  }

  static String seedToBase58Derived(String seed, int index) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed));
    return node.deriveHardened(index).neutered().toBase58();
  }

  static String seedToPublicKeyDerived(String seed, int index) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed));
    return HEX.encode(node.deriveHardened(index).publicKey);
  }

  static String seedToPublicKey(String seed) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed));
    return HEX.encode(node.publicKey);
  }


  static String seedToWIF(String seed) {
    final node = bip32.BIP32.fromSeed(HEX.decode(seed));
    return node.toWIF();
  }
}


class BitcoinUtil {
  static String seedToPrivate(String seed, int index) {
    return BitcoinKeys.seedToPrivate(seed, index);
  }

  static Future<http.Response> publishTx(String hextx) {
    print(hextx);
    return http.post(
      'https://blockchain.info/pushtx',
      body: {
        'tx': hextx,
      },
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

  static String seedToAddress(String seed, int index, {base58: true}) {
    //return NanoAccounts.createAccount(NanoAccountType.NANO, BitcoinKeys.createPublicKey(seed, index));
    if(base58) {
      return BitcoinKeys.seedToBase58Derived(seed, index);
    } else {
      return BitcoinKeys.seedToPublicKeyDerived(seed, index);
    }
  }

  Future<void> loginAccount(String seed, BuildContext context) async {
    Account selectedAcct = await sl.get<DBHelper>().getSelectedAccount(seed);
    if (selectedAcct == null) {
      selectedAcct = Account(index: 0, lastAccess: 0, name: AppLocalization.of(context).defaultAccountName, selected: true);
      await sl.get<DBHelper>().saveAccount(selectedAcct);
    }
    StateContainer.of(context).updateWallet(account: selectedAcct);
  }
}
