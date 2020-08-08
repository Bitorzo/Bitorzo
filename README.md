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

## Support our project ##
<style type="text/css"> .btcpay-form { display: inline-flex; align-items: center; justify-content: center; } .btcpay-form--inline { flex-direction: row; } .btcpay-form--block { flex-direction: column; } .btcpay-form--inline .submit { margin-left: 15px; } .btcpay-form--block select { margin-bottom: 10px; } .btcpay-form .btcpay-custom-container{ text-align: center; }.btcpay-custom { display: flex; align-items: center; justify-content: center; } .btcpay-form .plus-minus { cursor:pointer; font-size:25px; line-height: 25px; background: #DFE0E1; height: 30px; width: 45px; border:none; border-radius: 60px; margin: auto 5px; display: inline-flex; justify-content: center; } .btcpay-form select { -moz-appearance: none; -webkit-appearance: none; appearance: none; color: currentColor; background: transparent; border:1px solid transparent; display: block; padding: 1px; margin-left: auto; margin-right: auto; font-size: 11px; cursor: pointer; } .btcpay-form select:hover { border-color: #ccc; } #btcpay-input-price { -moz-appearance: none; -webkit-appearance: none; border: none; box-shadow: none; text-align: center; font-size: 25px; margin: auto; border-radius: 5px; line-height: 35px; background: #fff; } </style>
<form method="POST"  action="https://pay.bitorzo.io/api/v1/invoices" class="btcpay-form btcpay-form--block">
  <input type="hidden" name="storeId" value="41NmJmHNH9btp3cWaNUyP5PynXF5hJAT9doNpdi2vKSm" />
  <div class="btcpay-custom-container">
    <div class="btcpay-custom">
      <button class="plus-minus" onclick="event.preventDefault(); var price = parseInt(document.querySelector('#btcpay-input-price').value); if ('-' == '-' && (price - 1) < 1) { return; } document.querySelector('#btcpay-input-price').value = parseInt(document.querySelector('#btcpay-input-price').value) - 1;">-</button>
      <input id="btcpay-input-price" name="price" type="text" min="1" max="20" step="1" value="0.01" style="width: 3em;" oninput="event.preventDefault();isNaN(event.target.value) || event.target.value <= 0 ? document.querySelector('#btcpay-input-price').value = 0.01 : event.target.value"  />
      <button class="plus-minus" onclick="event.preventDefault(); var price = parseInt(document.querySelector('#btcpay-input-price').value); if ('+' == '-' && (price - 1) < 1) { return; } document.querySelector('#btcpay-input-price').value = parseInt(document.querySelector('#btcpay-input-price').value) + 1;">+</button>
    </div>
    <select name="currency">
      <option value="USD">USD</option>
      <option value="GBP">GBP</option>
      <option value="EUR">EUR</option>
      <option value="BTC" selected>BTC</option>
    </select>
  </div>
  <input type="image" class="submit" name="submit" src="https://pay.bitorzo.io/img/paybutton/pay.svg" style="width:209px" alt="Pay with BtcPay, Self-Hosted Bitcoin Payment Processor">
</form>



