import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bitorzo_wallet_flutter/util/random_util.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/util/encrypt.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:bitcoin_flutter/bitcoin_flutter.dart';


// Singleton for keystore access methods in android/iOS
class Vault {
  static const String seedKey = 'bitorzo_seed';
  static const String serverAddressKey = 'bitorzo_server';
  static const String segwitEnabled = 'bitorzo_segwit_enabled';
  static const String encryptionKey = 'bitorzo_secret_phrase';
  static const String pinKey = 'bitorzo_pin';
  static const String sessionKey = 'fencsess_key';
  final FlutterSecureStorage secureStorage = new FlutterSecureStorage();

  Future<bool> legacy() async {
    return await sl.get<SharedPrefsUtil>().useLegacyStorage();
  }

  // Re-usable
  Future<String> _write(String key, String value) async {
    if (await legacy()) {
      await setEncrypted(key, value);
    } else {
      await secureStorage.write(key: key, value: value);
    }
    return value;
  }

  Future<String> _read(String key, {String defaultValue}) async {
    if (await legacy()) {
      return await getEncrypted(key);
    }
    return await secureStorage.read(key: key) ?? defaultValue;
  }

  Future<void> deleteAll() async {
    if (await legacy()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(encryptionKey);
      await prefs.remove(seedKey);
      await prefs.remove(pinKey);
      await prefs.remove(sessionKey);
      return;
    }
    return await secureStorage.deleteAll();
  }

  // Specific keys
  Future<String> getSeed() async {
    return await _read(seedKey);
  }

  Future<String> setSeed(String seed) async {
    return await _write(seedKey, seed);
  }

  // Specific keys
  Future<String> getServerAddress() async {
    return await _read(serverAddressKey);
  }

  Future<String> setServerAddress(String serverAddress) async {
    return await _write(serverAddressKey, serverAddress);
  }

  Future<bool> isSegwit() async {
    return await _read(segwitEnabled) == true.toString();
  }

  Future<bool> setSegwit(bool segwit_enabled) async {
    return await _write(segwitEnabled, segwit_enabled.toString()) == true.toString();
  }


  Future<void> deleteSeed() async {
    if (await legacy()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(seedKey);
    }
    return await secureStorage.delete(key: seedKey);
  }

  Future<String> getEncryptionPhrase() async {
    return await _read(encryptionKey);
  }

  Future<String> writeEncryptionPhrase(String secret) async {
    return await _write(encryptionKey, secret);
  }

  /// Used to keep the seed in-memory in the session without being plaintext
  Future<String> getSessionKey() async {
    String key = await _read(sessionKey);
    if (key == null) {
      key = await updateSessionKey();
    }
    return key;
  }

  Future<String> updateSessionKey() async {
    String key = RandomUtil.generateEncryptionSecret(25);
    await writeSessionKey(key);
    return key;
  }

  Future<String> writeSessionKey(String key) async {
    return await _write(sessionKey, key);
  }

  Future<void> deleteEncryptionPhrase() async {
    if (await legacy()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(encryptionKey);
    }
    return await secureStorage.delete(key: encryptionKey);
  }

  Future<String> getPin() async {
    return await _read(pinKey);
  }

  Future<String> writePin(String pin) async {
    return await _write(pinKey, pin);
  }

  Future<void> deletePin() async {
    if (await legacy()) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(pinKey);
    }
    return await secureStorage.delete(key: pinKey);
  }

  // For encrypted data
  Future<void> setEncrypted(String key, String value) async {
    String secret = await getSecret();
    if (secret == null) return null;
    // Decrypt and return
    Salsa20Encryptor encrypter = new Salsa20Encryptor(
        secret.substring(0, secret.length - 8),
        secret.substring(secret.length - 8));
    // Encrypt and save
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, encrypter.encrypt(value));
  }

  Future<String> getEncrypted(String key) async {
    String secret = await getSecret();
    if (secret == null) return null;
    // Decrypt and return
    Salsa20Encryptor encrypter = new Salsa20Encryptor(
        secret.substring(0, secret.length - 8),
        secret.substring(secret.length - 8));
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encrypted = prefs.get(key);
    if (encrypted == null) return null;
    return encrypter.decrypt(encrypted);
  }

  static const _channel = const MethodChannel('fappchannel');

  Future<String> getSecret() async {
    return await _channel.invokeMethod('getSecret');
  }
}
