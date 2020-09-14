import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:bitorzo_wallet_flutter/model/available_currency.dart';
import 'package:bitorzo_wallet_flutter/network/model/block_types.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/account_history_response_item.dart';
import 'package:bitorzo_wallet_flutter/util/numberutil.dart';

/// Main wallet object that's passed around the app via state
class AppWallet {
  static const String defaultRepresentative = '';

  bool _loading; // Whether or not app is initially loading
  bool _historyLoading; // Whether or not we have received initial account history response
  String _address;
  BigInt _accountBalance;
  String _frontier;
  String _openBlock;
  String _representativeBlock;
  String _representative;
  String _localCurrencyPrice;
  String _btcPrice;
  int _blockCount;
  List<AccountHistoryResponseItem> _history;
  List<AccountHistoryResponseItem> _unconfirmed;


  AppWallet({String address, BigInt accountBalance, String frontier, String openBlock, String representativeBlock,
                String representative, String localCurrencyPrice,String btcPrice, int blockCount,
                List<AccountHistoryResponseItem> history, bool loading, bool historyLoading, List<AccountHistoryResponseItem> unconfirmed}) {
    this._address = address;
    this._accountBalance = accountBalance ?? BigInt.zero;
    this._frontier = frontier;
    this._openBlock = openBlock;
    this._representativeBlock = representativeBlock;
    this._representative = representative;
    this._localCurrencyPrice = localCurrencyPrice ?? "0";
    this._btcPrice = btcPrice ?? "0";
    this._blockCount = blockCount ?? 0;
    this._history = history ?? new List<AccountHistoryResponseItem>();
    this._loading = loading ?? true;
    this._historyLoading = historyLoading  ?? true;
    this._unconfirmed = unconfirmed ?? new List<AccountHistoryResponseItem>();
  }

  String get address => _address;

  set unconfirmed(List<AccountHistoryResponseItem> unconfirmed) {
    this._unconfirmed = unconfirmed;

  }

  List<AccountHistoryResponseItem> get unconfirmed => _unconfirmed;

  set address(String address) {
    this._address = address;
  }

  BigInt get accountBalance => _accountBalance;

  set accountBalance(BigInt accountBalance) {
    this._accountBalance = accountBalance;
  }

  bool hasUnconfirmed() {
    return (_unconfirmed?.length != 0 ?? 0);
  }

  BigInt getSumUnconfirmed() {
    BigInt sum = new BigInt.from(0);

    if(_unconfirmed == null) {
      return sum;
    }

    for(AccountHistoryResponseItem i in _unconfirmed) {
      if (i.type == BlockTypes.RECEIVE_UNCONFIRMED) {
        sum += BigInt.parse(i.amount);
      } else if (i.type == BlockTypes.SEND_UNCONFIRMED) {
        sum -= BigInt.parse(i.amount);
      }
    }
    return sum;
  }

  String getUnconfirmedTotalAmountDisplay() {
    BigInt sum = getSumUnconfirmed();
    return "${NumberUtil.SatoshiToMilliBTC(getSumUnconfirmed().toString())}";
  }

  // Get pretty account balance version
  String getAccountBalanceDisplay() {
    if (accountBalance == null) {
      return "1212312231";
    }
    //return NumberUtil.getRawAsUsableString(_accountBalance.toString());
    return NumberUtil.SatoshiToMilliBTC(_accountBalance.toString());
    //return "100";
  }


  String getLocalCurrencyPrice(AvailableCurrency currency, {String locale = "en_US"}) {
    // print("local currency ${_localCurrencyPrice} account_balance ${_accountBalance}");
    Decimal converted = Decimal.parse(_localCurrencyPrice) * Decimal.parse(_accountBalance.toString());
    return NumberFormat.currency(locale:locale, symbol: currency.getCurrencySymbol()).format(converted.toDouble());
  }

  set localCurrencyPrice(String value) {
    _localCurrencyPrice = value;
  }

  String get localCurrencyConversion {
    return _localCurrencyPrice;
  }

  String get btcPrice {
    Decimal converted = Decimal.parse(_btcPrice) * NumberUtil.getRawAsUsableDecimal(_accountBalance.toString());
    // Show 4 decimal places for BTC price if its >= 0.0001 BTC, otherwise 6 decimals
    if (converted >= Decimal.parse("0.0001")) {
      return new NumberFormat("#,##0.0000", "en_US").format(converted.toDouble());
    } else {
      return new NumberFormat("#,##0.000000", "en_US").format(converted.toDouble());
    }
  }

  set btcPrice(String value) {
    _btcPrice = value;
  }

  String get representative {
   return _representative ?? defaultRepresentative;
  }

  set representative(String value) {
    _representative = value;
  }

  String get representativeBlock => _representativeBlock;

  set representativeBlock(String value) {
    _representativeBlock = value;
  }

  String get openBlock => _openBlock;

  set openBlock(String value) {
    _openBlock = value;
  }

  String get frontier => _frontier;

  set frontier(String value) {
    _frontier = value;
  }

  int get blockCount => _blockCount;

  set blockCount(int value) {
    _blockCount = value;
  }

  List<AccountHistoryResponseItem> get history => _history;

  set history(List<AccountHistoryResponseItem> value) {
    _history = value;
  }

  bool get loading => _loading;

  set loading(bool value) {
    _loading = value;
  }

  bool get historyLoading => _historyLoading;

  set historyLoading(bool value) {
    _historyLoading = value;
  }
}