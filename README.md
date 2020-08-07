![Alt text](assets/images/bitorzowall.png?raw=true "Title")

# Bitorzo - Friendly & Secure BTC Wallet

## What is Bitorzo?

Bitorzo is a cross-platform mobile wallet for the Bitcoin cryptocurrency. It is written in Dart using [Flutter](https://flutter.io).


secure-by design and implementation, allowing users to be in full control of their funds. Exchange Bitcoin with your contacts anywhere, anytime!

Main features:
- Private keys never leave your device (unless the user actively exports it), and strongly encrypted on it!
- Choose a contact and just send - easily send Bitcoin to your contacts with Bitorzo, can be done anywhere and anytime without scanning any QR codes or sending addresses on a different app / channel.
- Protect your funds with biometrics (FaceID / Fingerprint)
- Import/export your wallet using 24 words mnemonic (Paper wallet).
- HD enabled - wallet never reuse addresses (BIP32, BIP44) to keep your privacy safe.
- Dynamic transaction fees (recommended for a reasonable confirmation time).
- Easily Send / Receive by scanning QR code (for non-contacts or non-Bitorzo users).
- Keep track of senders/receivers identities (from your contacts).


## Contributing

* Fork the repository and clone it to your local machine
* Follow the instructions [here](https://flutter.io/docs/get-started/install) to install the Flutter SDK
* Setup [Android Studio](https://flutter.io/docs/development/tools/android-studio) or [Visual Studio Code](https://flutter.io/docs/development/tools/vs-code).

## Building

Android (armeabi-v7a): `flutter build apk`
Android (arm64-v8a): `flutter build apk --target=android-arm64`
iOS: `flutter build ios`

If you have a connected device or emulator you can run and deploy the app with `flutter run`

## Have a question?

If you need any help, feel free to file an issue if you do not manage to find a solution.

## License

Bitorzo is released under the MIT License

### Update translations:

```
flutter pub pub run intl_translation:extract_to_arb --output-dir=lib/l10n lib/localization.dart
flutter pub pub run intl_translation:generate_from_arb --output-dir=lib/l10n \
   --no-use-deferred-loading lib/localization.dart lib/l10n/intl_*.arb
```



