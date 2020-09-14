import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:flutter_nano_ffi/flutter_nano_ffi.dart';
import 'package:bitorzo_wallet_flutter/model/wallet.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/accounts_balances_response.dart';
import 'package:uni_links/uni_links.dart';
import 'package:bitorzo_wallet_flutter/themes.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/model/available_themes.dart';
import 'package:bitorzo_wallet_flutter/model/available_currency.dart';
import 'package:bitorzo_wallet_flutter/model/available_language.dart';
import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/model/vault.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/model/db/account.dart';
import 'package:bitorzo_wallet_flutter/util/ninja/api.dart';
import 'package:bitorzo_wallet_flutter/util/ninja/ninja_node.dart';
import 'package:bitorzo_wallet_flutter/network/model/block_types.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/account_history_request.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/utxos_for_tx_request.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/fcm_update_request.dart';
import 'package:bitorzo_wallet_flutter/network/model/request/subscribe_request.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/account_history_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/utxos_for_tx_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/account_history_response_item.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/callback_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/error_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/subscribe_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/process_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/pending_response.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/pending_response_item.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:bitorzo_wallet_flutter/util/bitcoinutil.dart';
import 'package:bitorzo_wallet_flutter/network/account_service.dart';
import 'package:bitorzo_wallet_flutter/bus/events.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';

import 'bus/unconfirmed_home_event.dart';
import 'network/model/response/unconfirmed_response.dart';


class _InheritedStateContainer extends InheritedWidget {
   // Data is your entire state. In our case just 'User' 
  final StateContainerState data;
   
  // You must pass through a child and your state.
  _InheritedStateContainer({
    Key key,
    @required this.data,
    @required Widget child,
  }) : super(key: key, child: child);

  // This is a built in method which you can use to check if
  // any state has changed. If not, no reason to rebuild all the widgets
  // that rely on your state.
  @override
  bool updateShouldNotify(_InheritedStateContainer old) => true;
}

class StateContainer extends StatefulWidget {
   // You must pass through a child. 
  final Widget child;

  StateContainer({
    @required this.child
  });

  // This is the secret sauce. Write your own 'of' method that will behave
  // Exactly like MediaQuery.of and Theme.of
  // It basically says 'get the data from the widget of this type.
  static StateContainerState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InheritedStateContainer>().data;
  }
  
  @override
  StateContainerState createState() => StateContainerState();
}

/// App InheritedWidget
/// This is where we handle the global state and also where
/// we interact with the server and make requests/handle+propagate responses
/// 
/// Basically the central hub behind the entire app
class StateContainerState extends State<StateContainer> {
  final Logger log = sl.get<Logger>();

  // Minimum receive = 0.000001 NANO
  // String receiveThreshold = BigInt.from(10).pow(24).toString();
  String receiveThreshold = "0";

  AppWallet wallet;
  String currencyLocale;
  Locale deviceLocale = Locale('en', 'US');
  AvailableCurrency curCurrency = AvailableCurrency(AvailableCurrencyEnum.USD);
  LanguageSetting curLanguage = LanguageSetting(AvailableLanguage.DEFAULT);
  BaseTheme curTheme = BitorzoTheme();
  // Currently selected account
  Account selectedAccount = Account(id:1, name: "AB", index: 0, lastAccess: 0, selected: true);
  // Two most recently used accounts
  Account recentLast;
  Account recentSecondLast;

  // If callback is locked
  bool _locked = false;

  // Initial deep link
  String initialDeepLink;
  // Deep link changes
  StreamSubscription _deepLinkSub;

  List<String> pendingRequests = [];
  List<String> alreadyReceived = [];

  // List of Verified BTC Ninja Nodes
  bool nanoNinjaUpdated = false;
  List<NinjaNode> nanoNinjaNodes;

  // When wallet is encrypted
  String encryptedSecret;

  void updateNinjaNodes(List<NinjaNode> list) {
    setState(() {
      nanoNinjaNodes = list;
    });
  }

  @override
  void initState() {
    super.initState();
    // Register RxBus
    _registerBus();
    // Set currency locale here for the UI to access
    sl.get<SharedPrefsUtil>().getCurrency(deviceLocale).then((currency) {
      setState(() {
        currencyLocale = currency.getLocale().toString();
        curCurrency = currency;
      });
    });
    // Get default language setting
    sl.get<SharedPrefsUtil>().getLanguage().then((language) {
      setState(() {
        curLanguage = language;
      });
    });
    // Get theme default
    sl.get<SharedPrefsUtil>().getTheme().then((theme) {
      updateTheme(theme, setIcon: false);
    });
    // Get initial deep link
    getInitialLink().then((initialLink) {
      setState(() {
       initialDeepLink = initialLink;
      });
    });

  }

  // Subscriptions
  StreamSubscription<ConnStatusEvent> _connStatusSub;
  StreamSubscription<SubscribeEvent> _subscribeEventSub;
  StreamSubscription<PriceEvent> _priceEventSub;
  StreamSubscription<UnconfirmedEvent> _unconfirmedEventSub;
  StreamSubscription<CallbackEvent> _callbackSub;
  StreamSubscription<ErrorEvent> _errorSub;
  StreamSubscription<FcmUpdateEvent> _fcmUpdateSub;
  StreamSubscription<AccountModifiedEvent> _accountModifiedSub;

  // Register RX event listeners
  void _registerBus() {
    _subscribeEventSub = EventTaxiImpl.singleton().registerTo<SubscribeEvent>().listen((event) {
      handleSubscribeResponse(event.response);
    });
    _priceEventSub = EventTaxiImpl.singleton().registerTo<PriceEvent>().listen((event) {
      // PriceResponse's get pushed periodically, it wasn't a request we made so don't pop the queue

      sl.get<Logger>().d("Ok Damn that works");
      setState(() {
        wallet.btcPrice = event.response.btcPrice.toString();
        wallet.localCurrencyPrice = event.response.price.toString();
        //wallet.btcPrice = "1";
        // wallet.localCurrencyPrice = "1";
      });
    });

    _unconfirmedEventSub = EventTaxiImpl.singleton().registerTo<UnconfirmedEvent>().listen((event) {
      // PriceResponse's get pushed periodically, it wasn't a request we made so don't pop the queue
      sl.get<Logger>().d("Setting state!");
      setState(() {
        //wallet.btcPrice = "12312312312312312312321312312312";
        //wallet.unconfirmed = "WII";
        wallet.unconfirmed = event.response.unconfirmed;
        sl.get<Logger>().d(wallet.unconfirmed );
      });
    });

    _connStatusSub = EventTaxiImpl.singleton().registerTo<ConnStatusEvent>().listen((event) {
      if (event.status == ConnectionStatus.CONNECTED) {
        requestUpdate();
      } else if (event.status == ConnectionStatus.DISCONNECTED && !sl.get<AccountService>().suspended) {
        sl.get<AccountService>().initCommunication();
      }
    });
    _callbackSub = EventTaxiImpl.singleton().registerTo<CallbackEvent>().listen((event) {
      handleCallbackResponse(event.response);
    });
    _errorSub = EventTaxiImpl.singleton().registerTo<ErrorEvent>().listen((event) {
      handleErrorResponse(event.response);
    });
    _fcmUpdateSub = EventTaxiImpl.singleton().registerTo<FcmUpdateEvent>().listen((event) {
      if (wallet != null) {
        sl.get<SharedPrefsUtil>().getNotificationsOn().then((enabled) {
          sl.get<AccountService>().sendRequest(FcmUpdateRequest(account: wallet.address, fcmToken: event.token, enabled: enabled));
        });
      }
    });
    // Account has been deleted or name changed
    _accountModifiedSub = EventTaxiImpl.singleton().registerTo<AccountModifiedEvent>().listen((event) {
      if (!event.deleted) {
        if (event.account.index == selectedAccount.index) {
          setState(() {
            selectedAccount.name = event.account.name;
          });
        } else {
          updateRecentlyUsedAccounts();
        }
      } else {
        // Remove account
        updateRecentlyUsedAccounts().then((_) {
          if (event.account.index == selectedAccount.index && recentLast != null) {
            sl.get<DBHelper>().changeAccount(recentLast);
            setState(() {
              selectedAccount = recentLast;
            });
            EventTaxiImpl.singleton().fire(AccountChangedEvent(account: recentLast, noPop: true));
          } else if (event.account.index == selectedAccount.index && recentSecondLast != null) {
            sl.get<DBHelper>().changeAccount(recentSecondLast);
            setState(() {
              selectedAccount = recentSecondLast;
            });
            EventTaxiImpl.singleton().fire(AccountChangedEvent(account: recentSecondLast, noPop: true));
          } else if (event.account.index == selectedAccount.index) {
            getSeed().then((seed) {
              isSegwit().then((is_segwit) {
              sl.get<DBHelper>().getMainAccount(seed, is_segwit).then((mainAccount) {
                sl.get<DBHelper>().changeAccount(mainAccount);
                setState(() {
                  selectedAccount = mainAccount;
                });
                EventTaxiImpl.singleton().fire(
                    AccountChangedEvent(account: mainAccount, noPop: true));
              });
              });
            });       
          }
        });
        updateRecentlyUsedAccounts();
      }
    });
    // Deep link has been updated
    _deepLinkSub = getLinksStream().listen((String link) {
      setState(() {
        initialDeepLink = link;
      });
    });
  }

  @override
  void dispose() {
    _destroyBus();
    super.dispose();
  }

  void _destroyBus() {
    if (_connStatusSub != null) {
      _connStatusSub.cancel();
    }

    if(_unconfirmedEventSub != null) {
      _unconfirmedEventSub.cancel();
    }

    if (_subscribeEventSub != null) {
      _subscribeEventSub.cancel();
    }
    if (_priceEventSub != null) {
      _priceEventSub.cancel();
    }
    if (_callbackSub != null) {
      _callbackSub.cancel();
    }
    if (_errorSub != null) {
      _errorSub.cancel();
    }
    if (_fcmUpdateSub != null) {
      _fcmUpdateSub.cancel();
    }
    if (_accountModifiedSub != null) {
      _accountModifiedSub.cancel();
    }
    if (_deepLinkSub != null) {
      _deepLinkSub.cancel();
    }
  }

  // Update the global wallet instance with a new address
  Future<void> updateWallet({Account account}) async {

    String address = BitcoinUtil.seedToAddress(await getSeed(), account.index,  await isSegwit(), base58 : true);
    account.address = address;
    selectedAccount = account;
    updateRecentlyUsedAccounts();
    setState(() {
      wallet = AppWallet(address: address, loading: true);
      requestUpdate();
    });
  }

  Future<void> updateRecentlyUsedAccounts() async {
    List<Account> otherAccounts = await sl.get<DBHelper>().getRecentlyUsedAccounts(await getSeed(), await isSegwit());
    if (otherAccounts != null && otherAccounts.length > 0) {
      if (otherAccounts.length > 1) {
        setState(() {
          recentLast = otherAccounts[0];
          recentSecondLast = otherAccounts[1];
        });
      } else {
        setState(() {
          recentLast = otherAccounts[0];
          recentSecondLast = null;
        });
      }
    } else {
      setState(() {
        recentLast = null;
        recentSecondLast = null;
      });
    }
  }

  // Change language
  void updateLanguage(LanguageSetting language) {
    setState(() {
      curLanguage = language;
    });
  }

  // Set encrypted secret
  void setEncryptedSecret(String secret) {
    setState(() {
      encryptedSecret = secret;      
    });
  }

  // Reset encrypted secret
  void resetEncryptedSecret() {
    setState(() {
      encryptedSecret = null;
    });
  }

  // Change theme
  void updateTheme(ThemeSetting theme, {bool setIcon = true}) {
    setState(() {
      curTheme = theme.getTheme();
    });
    if (setIcon) {
      AppIcon.setAppIcon(theme.getTheme().appIcon);
    }
  }

  void disconnect() {
    sl.get<AccountService>().reset(suspend: true);
  }

  void reconnect() {
    sl.get<AccountService>().initCommunication(unsuspend: true);
  }

  void lockCallback() {
    _locked = true;
  }

  void unlockCallback() {
    _locked = false;
  }

  ///
  /// When an error is returned from server
  /// 
  Future<void> handleErrorResponse(ErrorResponse errorResponse) async {
    sl.get<AccountService>().processQueue();
    if (errorResponse.error == null) { return; }
  }

  /// Handle account_subscribe response
  void handleSubscribeResponse(SubscribeResponse response) {
    // Combat spam by raising minimum receive if pending block count is large enough
    if (response.pendingCount != null && response.pendingCount > 50) {
      // Bump min receive to 0.05 NANO
      // receiveThreshold = BigInt.from(5).pow(28).toString();
      receiveThreshold = "0";
    }
    // Set currency locale here for the UI to access
    sl.get<SharedPrefsUtil>().getCurrency(deviceLocale).then((currency) {
      setState(() {
        currencyLocale = currency.getLocale().toString();
        curCurrency = currency;
      });
    });
    // Server gives us a UUID for future requests on subscribe
    if (response.uuid != null) {
      sl.get<SharedPrefsUtil>().setUuid(response.uuid);
    }
    setState(() {
      wallet.loading = false;
      wallet.frontier = response.frontier;
      wallet.representative = response.representative;
      wallet.representativeBlock = response.representativeBlock;
      wallet.openBlock = response.openBlock;
      wallet.blockCount = response.blockCount;
      if (response.balance == null) {
        wallet.accountBalance = BigInt.from(0);
      } else {
        wallet.accountBalance = BigInt.tryParse(response.balance);
      }
      wallet.localCurrencyPrice = response.price.toString();
      wallet.btcPrice = response.btcPrice.toString();
      sl.get<AccountService>().pop();
      sl.get<AccountService>().processQueue();
    });
  }
 
  /// Handle callback response
  /// Typically this means we need to pocket transactions
  Future<void> handleCallbackResponse(CallbackResponse resp) async {
    if (_locked) {
      return;
    }
    log.d("Received callback ${json.encode(resp.toJson())}");
    if (resp.isSend != "true") {
      sl.get<AccountService>().processQueue();
      return;
    }
    PendingResponseItem pendingItem = PendingResponseItem(
        hash: resp.hash, source: resp.account, amount: resp.amount);
    String receivedHash = await handlePendingItem(pendingItem);
    if (receivedHash != null) {
      AccountHistoryResponseItem histItem = AccountHistoryResponseItem(
        type: BlockTypes.RECEIVE,
        account: resp.account,
        amount: resp.amount,
        hash: receivedHash
      );
      if (!wallet.history.contains(histItem)) {
        setState(() {
          wallet.history.insert(0, histItem);
          wallet.accountBalance += BigInt.parse(resp.amount);
          // Send list to home screen
          EventTaxiImpl.singleton()
              .fire(HistoryHomeEvent(items: wallet.history));
        });
      }
    }
  }

  Future<String> handlePendingItem(PendingResponseItem item) async {
    if (pendingRequests.contains(item.hash)) {
      return null;
    }
    pendingRequests.add(item.hash);
    print(item.hash);
    BigInt amountBigInt = BigInt.tryParse(item.amount);
    sl.get<Logger>().d("Handling ${item.hash} pending, amount ${item.amount} threshold ${receiveThreshold}");
    if (amountBigInt != null) {
      // TODO - think here
      //if (amountBigInt < BigInt.parse(receiveThreshold)) {
      //  pendingRequests.remove(item.hash);
      //  return null;
      //}
    }
    if (wallet.openBlock == null) {
      // Publish open
      sl.get<Logger>().d("Handling ${item.hash} as open");
      try {
        //ProcessResponse resp = await sl.get<AccountService>().requestOpen(item.amount, item.hash, wallet.address, await _getPrivKey());
        wallet.openBlock = "hab"; // resp.hash;
        wallet.frontier = "hab"; //resp.hash;
        pendingRequests.remove(item.hash);
        //alreadyReceived.add(item.hash);
        return "hab"; // resp.hash;
      } catch (e) {
        pendingRequests.remove(item.hash);
        sl.get<Logger>().e("Error creating open", e);
      }
    } else {
      // Publish receive
      sl.get<Logger>().d("Handling ${item.hash} as receive");
      try {
        //ProcessResponse resp = await sl.get<AccountService>().requestReceive(wallet.representative, wallet.frontier, item.amount, item.hash, wallet.address, await _getPrivKey());
        wallet.frontier = "hab"; // resp.hash;
        pendingRequests.remove(item.hash);
        alreadyReceived.add(item.hash);        
        return "hab"; //resp.hash;
      } catch (e) {
        pendingRequests.remove(item.hash);
        sl.get<Logger>().e("Error creating receive", e);
      }     
    }
    return null;
  }

  /// Request balances for accounts in our database
  Future<void> _requestBalances() async {

    print("Balances Req");
    List<Account> accounts = await sl.get<DBHelper>().getAccounts(await getSeed(), await isSegwit());

    List<String> addressToRequest = List();
    accounts.forEach((account) {
      if (account.address != null) {
        addressToRequest.add(account.address);
      }
    });
    AccountsBalancesResponse resp = await sl.get<AccountService>().requestAccountsBalances(addressToRequest);
    print(resp);
    sl.get<DBHelper>().getAccounts(await getSeed(), await isSegwit()).then((accounts) {
      //log.d("1");
      accounts.forEach((account) {
        //log.d("2");
        resp.balances.forEach((address, balance) {
          //log.d("3");
          String combinedBalance = (BigInt.tryParse(balance.balance) + BigInt.tryParse(balance.pending)).toString();
          //log.d("address ${address}, account address ${account.address} combined ${combinedBalance} balance ${account.balance}");
          if (address == account.address && combinedBalance != account.balance) {
            //log.d("account - ${account} combined balanace - ${combinedBalance}");
            sl.get<DBHelper>().updateAccountBalance(account, combinedBalance);
          }
        });
      });
    });
  }

  Future<void> requestUtxoForTx({String amount}) async {
    sl.get<AccountService>().queueRequest(UtxosForTxRequest(account:wallet.address, amount:amount));
    sl.get<AccountService>().processQueue();
  }

  Future<void> requestUpdate({bool pending = true}) async {
    print("Requesting update!!");
    if (wallet != null &&
        wallet.address != null &&
        Address(wallet.address).isValid()) {
      String uuid = await sl.get<SharedPrefsUtil>().getUuid();
      String fcmToken = await FirebaseMessaging().getToken();
      bool notificationsEnabled =
          await sl.get<SharedPrefsUtil>().getNotificationsOn();
      sl.get<AccountService>().clearQueue();
      sl.get<AccountService>().queueRequest(SubscribeRequest(
          account: wallet.address,
          currency: curCurrency.getIso4217Code(),
          uuid: uuid,
          fcmToken: fcmToken,
          notificationEnabled: notificationsEnabled));

      sl.get<AccountService>().queueRequest(
          AccountHistoryRequest(account: wallet.address));
      sl.get<AccountService>().processQueue();
      // Request account history

      int count = 500;
      if (wallet.history != null && wallet.history.length > 1) {
        count = 50;
      }
      try {
        print("haboshabosasda");
        AccountHistoryResponse resp = await sl.get<AccountService>()
            .requestAccountHistory(wallet.address, count: count);

        _requestBalances();
        // wallet.accountBalance = BigInt.parse("12321321");
        bool postedToHome = false;
        // Iterate list in reverse (oldest to newest block)
        for (AccountHistoryResponseItem item in resp.history) {
          // If current list doesn't contain this item, insert it and the rest of the items in list and exit loop
          if (!wallet.history.contains(item)) {
            int startIndex = 0; // Index to start inserting into the list
            int lastIndex = resp.history.indexWhere((item) =>
                wallet.history.contains(
                    item)); // Last index of historyResponse to insert to (first index where item exists in wallet history)
            lastIndex =
            lastIndex <= 0 ? resp.history.length : lastIndex;
            setState(() {
              wallet.history.insertAll(
                  0, resp.history.getRange(startIndex, lastIndex));
              // Send list to home screen
              EventTaxiImpl.singleton()
                  .fire(HistoryHomeEvent(items: wallet.history));
            });
            postedToHome = true;
            break;
          }
        }


          UnconfirmedResponse uresp = await sl.get<AccountService>()
              .requestAccountUnconfirmed(wallet.address, count: count);


        wallet.unconfirmed = uresp.unconfirmed;
        EventTaxiImpl.singleton()
            .fire(UnconfirmedHomeEvent(items: wallet.unconfirmed));


           /*
          // Iterate list in reverse (oldest to newest block)
          for (AccountHistoryResponseItem item in uresp.unconfirmed) {
            // If current list doesn't contain this item, insert it and the rest of the items in list and exit loop
            if (!wallet.unconfirmed.contains(item)) {
              int startIndex = 0; // Index to start inserting into the list
              int lastIndex = uresp.unconfirmed.indexWhere((item) =>
                  wallet.unconfirmed.contains(
                      item)); // Last index of historyResponse to insert to (first index where item exists in wallet history)
              lastIndex =
              lastIndex <= 0 ? uresp.unconfirmed.length : lastIndex;
              setState(() {
                wallet.unconfirmed.insertAll(
                    0, uresp.unconfirmed.getRange(startIndex, lastIndex));
                // Send list to home screen
                EventTaxiImpl.singleton()
                    .fire(UnconfirmedHomeEvent(items: wallet.unconfirmed));
              });
              postedToHome = true;
              break;
            }
          }

            */


        setState(() {
          wallet.historyLoading = false;
        });
        if (!postedToHome) {
          EventTaxiImpl.singleton().fire(HistoryHomeEvent(items: wallet.history));
        }
        sl.get<AccountService>().pop();
        sl.get<AccountService>().processQueue();
        // Receive pendings
        pending = false; // TODO - what exactly is pending?
        if (pending) {
          //PendingResponse pendingResp = await sl.get<AccountService>().getPending(wallet.address, max(wallet.blockCount ?? 0, 10), threshold: receiveThreshold);
          PendingResponse pendingResp = await sl.get<AccountService>().getPending(wallet.address, max(wallet.blockCount ?? 0, 10), threshold: "0");
          print(pendingResp);
          // Initiate receive/open request for each pending
          for (String hash in pendingResp.blocks.keys) {
            PendingResponseItem pendingResponseItem = pendingResp.blocks[hash];
            pendingResponseItem.hash = hash;
            String receivedHash = await handlePendingItem(pendingResponseItem);
            if (receivedHash != null) {
              AccountHistoryResponseItem histItem = AccountHistoryResponseItem(
                type: BlockTypes.RECEIVE,
                account: pendingResponseItem.source,
                amount: pendingResponseItem.amount,
                hash: receivedHash
              );
              if (!wallet.history.contains(histItem)) {
                setState(() {

                  wallet.history.insert(0, histItem);
                  wallet.accountBalance += BigInt.parse(pendingResponseItem.amount);
                  print(wallet.accountBalance);
                  // Send list to home screen
                  EventTaxiImpl.singleton()
                      .fire(HistoryHomeEvent(items: wallet.history));
                });
              }
            }
          }
        }
      } catch (e) {
        // TODO handle account history error
        sl.get<Logger>().e("account_history e", e);
      }
    }
  }

  Future<void> requestSubscribe() async {
    if (wallet != null && wallet.address != null && Address(wallet.address).isValid()) {
      String uuid = await sl.get<SharedPrefsUtil>().getUuid();
      String fcmToken = await FirebaseMessaging().getToken();
      bool notificationsEnabled = await sl.get<SharedPrefsUtil>().getNotificationsOn();
      sl.get<AccountService>().removeSubscribeHistoryPendingFromQueue();
      sl.get<AccountService>().queueRequest(SubscribeRequest(account:wallet.address, currency:curCurrency.getIso4217Code(), uuid:uuid, fcmToken: fcmToken, notificationEnabled: notificationsEnabled));
      sl.get<AccountService>().processQueue();
    }
  }

  void logOut() {
    setState(() {
      wallet = AppWallet();
      encryptedSecret = null;
    });
    sl.get<DBHelper>().dropAccounts();
    sl.get<AccountService>().clearQueue();
  }


  Future<String> getSeed() async {
    String seed;
    if (encryptedSecret != null)  {
      seed = NanoHelpers.byteToHex(NanoCrypt.decrypt(encryptedSecret, await sl.get<Vault>().getSessionKey()));
    } else {
      seed = await sl.get<Vault>().getSeed();
    }
    return seed;
  }

  Future<bool> isSegwit() async {
    return await sl.get<Vault>().isSegwit();
  }

  // Simple build method that just passes this state through
  // your InheritedWidget
  @override
  Widget build(BuildContext context) {
    return _InheritedStateContainer(
      data: this,
      child: widget.child,
    );
  }
}
