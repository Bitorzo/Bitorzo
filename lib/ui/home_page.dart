import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:bitorzo_wallet_flutter/bus/pending_request_event.dart';
import 'package:bitorzo_wallet_flutter/util/bitcoinutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:event_taxi/event_taxi.dart';
import 'package:logger/logger.dart';
import 'package:manta_dart/manta_wallet.dart';
import 'package:manta_dart/messages.dart';

import 'package:bitorzo_wallet_flutter/bus/unconfirmed_home_event.dart';
import 'package:bitorzo_wallet_flutter/model/db/account.dart';
import 'package:bitorzo_wallet_flutter/src/data/data.dart';
import 'package:bitorzo_wallet_flutter/src/models/user_model.dart';
import 'package:bitorzo_wallet_flutter/src/utils/screen_size.dart';
import 'package:bitorzo_wallet_flutter/src/widgets/add_button.dart';
import 'package:bitorzo_wallet_flutter/src/widgets/user_card.dart';
import 'package:bitorzo_wallet_flutter/ui/popup_button.dart';
import 'package:bitorzo_wallet_flutter/appstate_container.dart';
import 'package:bitorzo_wallet_flutter/dimens.dart';
import 'package:bitorzo_wallet_flutter/localization.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/model/address.dart';
import 'package:bitorzo_wallet_flutter/model/list_model.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/network/model/block_types.dart';
import 'package:bitorzo_wallet_flutter/network/model/response/account_history_response_item.dart';
import 'package:bitorzo_wallet_flutter/styles.dart';
import 'package:bitorzo_wallet_flutter/app_icons.dart';
import 'package:bitorzo_wallet_flutter/ui/contacts/add_contact.dart';
import 'package:bitorzo_wallet_flutter/ui/send/send_sheet.dart';
import 'package:bitorzo_wallet_flutter/ui/send/send_confirm_sheet.dart';
import 'package:bitorzo_wallet_flutter/ui/receive/receive_sheet.dart';
import 'package:bitorzo_wallet_flutter/ui/settings/settings_drawer.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/buttons.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/app_drawer.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/app_scaffold.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/dialog.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/sheet_util.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/list_slidable.dart';
import 'package:bitorzo_wallet_flutter/ui/util/routes.dart';
import 'package:bitorzo_wallet_flutter/ui/widgets/reactive_refresh.dart';
import 'package:bitorzo_wallet_flutter/ui/util/ui_util.dart';
import 'package:bitorzo_wallet_flutter/util/manta.dart';
import 'package:bitorzo_wallet_flutter/util/sharedprefsutil.dart';
import 'package:bitorzo_wallet_flutter/util/hapticutil.dart';
import 'package:bitorzo_wallet_flutter/util/caseconverter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bitorzo_wallet_flutter/bus/events.dart';
import 'package:bitorzo_wallet_flutter/util/contactsutil.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';
import 'package:bitorzo_wallet_flutter/util/firebaseutil.dart';
import 'package:bitcoin_flutter/src/payments/index.dart' show PaymentData;
import 'package:bitcoin_flutter/src/payments/p2pkh.dart';
import 'package:bitcoin_flutter/src/payments/p2Wpkh.dart';
import 'package:bitorzo_wallet_flutter/util/numberutil.dart';

class AppHomePage extends StatefulWidget {
  PriceConversion priceConversion;

  AppHomePage({this.priceConversion}) : super();

  @override
  _AppHomePageState createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage>

    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        FlareController {
  final GlobalKey<AppScaffoldState> _scaffoldKey =
  new GlobalKey<AppScaffoldState>();
  final Logger log = sl.get<Logger>();

  // Controller for placeholder card animations
  AnimationController _placeholderCardAnimationController;
  Animation<double> _opacityAnimation;
  bool _animationDisposed;

  // Manta
  bool mantaAnimationOpen;

  // Receive card instance
  ReceiveSheet receive;

  // A separate unfortunate instance of this list, is a little unfortunate
  // but seems the only way to handle the animations
  final Map<String, GlobalKey<AnimatedListState>> _listKeyMap = Map();
  final Map<String, ListModel<AccountHistoryResponseItem>> _historyListMap =
  Map();

  final Map<String, String> _pendingRequestsMap = Map();

  final Map<String, ListModel<AccountHistoryResponseItem>> _unconfirmedListMap =
  Map();

  // List of contacts (Store it so we only have to query the DB once for transaction cards)
  List<AppContact> _contacts = List();

  String receive_address_for_qr = "";
  // Price conversion state (BTC, NANO, NONE)
  PriceConversion _priceConversion;

  bool _isRefreshing = false;
  bool _lockDisabled = false; // whether we should avoid locking the app

  // Main card height
  double mainCardHeight;
  double settingsIconMarginTop = 5;

  String _myPhoneNumber = "";

  // FCM instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  // Animation for swiping to send
  ActorAnimation _sendSlideAnimation;
  ActorAnimation _sendSlideReleaseAnimation;
  double _fanimationPosition;
  bool releaseAnimation = false;

  void initialize(FlutterActorArtboard actor) {
    _fanimationPosition = 0.0;
    _sendSlideAnimation = actor.getAnimation("pull");
    _sendSlideReleaseAnimation = actor.getAnimation("release");
  }

  void setViewTransform(Mat2D viewTransform) {}

  bool advance(FlutterActorArtboard artboard, double elapsed) {
    if (releaseAnimation) {
      _sendSlideReleaseAnimation.apply(
          _sendSlideReleaseAnimation.duration * (1 - _fanimationPosition),
          artboard,
          1.0);
    } else {
      _sendSlideAnimation.apply(
          _sendSlideAnimation.duration * _fanimationPosition, artboard, 1.0);
    }
    return true;
  }

  Future<void> _switchToAccount(String account) async {
    bool is_segwit = await StateContainer.of(context).isSegwit();
    List<Account> accounts = await sl
        .get<DBHelper>()
        .getAccounts(await StateContainer.of(context).getSeed(), is_segwit);
    for (Account a in accounts) {
      if (a.address == account &&
          a.address != StateContainer
              .of(context)
              .wallet
              .address) {
        await sl.get<DBHelper>().changeAccount(a);
        EventTaxiImpl.singleton()
            .fire(AccountChangedEvent(account: a, delayPop: true));
      }
    }
  }

  /// Notification includes which account its for, automatically switch to it if they're entering app from notification
  Future<void> _chooseCorrectAccountFromNotification(dynamic message) async {
    if (message.containsKey("account")) {
      String account = message['account'];
      if (account != null) {
        await _switchToAccount(account);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _updatePublicKeys(context));
    /*
    WidgetsBinding.instance.addPostFrameCallback((_) =>
    _getUnusedPublicAddressAndPaintQR(context));
     */

    /* Not needed anymore
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        _setMyPhoneNumber(context));

     */

    _registerBus();

    this.mantaAnimationOpen = false;
    WidgetsBinding.instance.addObserver(this);
    if (widget.priceConversion != null) {
      _priceConversion = widget.priceConversion;
    } else {
      _priceConversion = PriceConversion.BTC;
    }
    // Main Card Size
    if (_priceConversion == PriceConversion.BTC) {
      mainCardHeight = 120;
      settingsIconMarginTop = 7;
    } else if (_priceConversion == PriceConversion.NONE) {
      mainCardHeight = 64;
      settingsIconMarginTop = 7;
    } else if (_priceConversion == PriceConversion.HIDDEN) {
      mainCardHeight = 64;
      settingsIconMarginTop = 5;
    }

    _addRegisteredContacts();
    _updateContacts();
    // Setup placeholder animation and start
    _animationDisposed = false;
    _placeholderCardAnimationController = new AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _placeholderCardAnimationController
        .addListener(_animationControllerListener);
    _opacityAnimation = new Tween(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(
        parent: _placeholderCardAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );
    _opacityAnimation.addStatusListener(_animationStatusListener);
    _placeholderCardAnimationController.forward();
    // Register push notifications
    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        
      },
      onLaunch: (Map<String, dynamic> message) async {
        if (message.containsKey('data')) {
          await _chooseCorrectAccountFromNotification(message['data']);
        }
      },
      onResume: (Map<String, dynamic> message) async {
        if (message.containsKey('data')) {
          await _chooseCorrectAccountFromNotification(message['data']);
        }
      },
    );
    _firebaseMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: true, badge: true, alert: true));
    _firebaseMessaging.onIosSettingsRegistered
        .listen((IosNotificationSettings settings) {
      if (settings.alert || settings.badge || settings.sound) {
        sl.get<SharedPrefsUtil>().getNotificationsSet().then((beenSet) {
          if (!beenSet) {
            sl.get<SharedPrefsUtil>().setNotificationsOn(true);
          }
        });
        _firebaseMessaging.getToken().then((String token) {
          if (token != null) {
            EventTaxiImpl.singleton().fire(FcmUpdateEvent(token: token));
          }
        });
      } else {
        sl.get<SharedPrefsUtil>().setNotificationsOn(false).then((_) {
          _firebaseMessaging.getToken().then((String token) {
            EventTaxiImpl.singleton().fire(FcmUpdateEvent(token: token));
          });
        });
      }
    });
    _firebaseMessaging.getToken().then((String token) {
      if (token != null) {
        EventTaxiImpl.singleton().fire(FcmUpdateEvent(token: token));
      }
    });
  }

  void _animationStatusListener(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.dismissed:
        _placeholderCardAnimationController.forward();
        break;
      case AnimationStatus.completed:
        _placeholderCardAnimationController.reverse();
        break;
      default:
        return null;
    }
  }

  void _animationControllerListener() {
    setState(() {});
  }

  void _startAnimation() {
    if (_animationDisposed) {
      _animationDisposed = false;
      _placeholderCardAnimationController
          .addListener(_animationControllerListener);
      _opacityAnimation.addStatusListener(_animationStatusListener);
      _placeholderCardAnimationController.forward();
    }
  }

  void _disposeAnimation() {
    if (!_animationDisposed) {
      _animationDisposed = true;
      _opacityAnimation.removeStatusListener(_animationStatusListener);
      _placeholderCardAnimationController
          .removeListener(_animationControllerListener);
      _placeholderCardAnimationController.stop();
    }
  }

  String getAddress(node, {network, segwit:true} ) {


    return segwit?
      P2WPKH(
        data: new PaymentData(pubkey: node.publicKey), network: network).data
        .address :
      P2PKH(
        data: new PaymentData(pubkey: node.publicKey), network: network).data
        .address;
  }


  Future<void> _getUnusedPublicAddressAndPaintQR(var context, bool markUsed) async {

      FirebaseUtil.getLocalUnusedPublicAddress(markUsed: markUsed).then((value) {
          setState(() {
            receive_address_for_qr = value;
            paintQrCode(address: receive_address_for_qr);
            });
      });

  }

  Future<void> _updatePublicKeys(var context) async {

    bool is_segwit = await StateContainer.of(context).isSegwit();
  

    String seed = await StateContainer.of(context).getSeed();
    bip32.BIP32 wallet = bip32.BIP32.fromSeed(HEX.decode(seed));

    int unused_num = await FirebaseUtil.getNumUnusedReceivePublicKeys();
    int used_num = await FirebaseUtil.getNumUsedReceivePublicKeys();

    int last_id = unused_num + used_num - 1;

    int change_unused_num = await FirebaseUtil.getNumUnusedChangePublicKeys();
    int change_used_num = await FirebaseUtil.getNumUsedChangePublicKeys();

    int change_last_id = change_unused_num + change_used_num - 1;

    List<String> derived_public_keys = [];
    List<String> derived_change_keys = [];

    int purpose_num = is_segwit ? 84 : 44;

    for (int i = 0; i < 20 - unused_num; i++) {

      final child_public_key = getAddress(
        // Backward compatability
        is_segwit?
          wallet
          .deriveHardened(purpose_num) // Purpose: BIP44 hardened
          .deriveHardened(0x0) // Coin Type: bitcoin
          .deriveHardened(StateContainer.of(context).selectedAccount.index) // account
          .derive(0) // change: External chain (recieve)
          .derive(last_id + i + 1) :
          wallet
          .deriveHardened(StateContainer.of(context).selectedAccount.index) // account
          .derive(0) // change: External chain (recieve)
          .derive(last_id + i + 1)

          ,  // address_index
          segwit:is_segwit);
      derived_public_keys.add(child_public_key);
    }

    await FirebaseUtil.addUserRecievePublicKeys(derived_public_keys);

    for (int i = 0; i < 20 - change_unused_num; i++) {

      final change_public_key = getAddress(
          is_segwit?
          wallet
          .deriveHardened(purpose_num)
          .deriveHardened(0x0) // Coin Type: bitcoin
          .deriveHardened(StateContainer
          .of(context)
          .selectedAccount
          .index)
          .derive(1) // Internal chain (change)
          .derive(change_last_id + i + 1):
          wallet
            .deriveHardened(StateContainer
            .of(context)
            .selectedAccount
            .index)
            .derive(1) // Internal chain (change)
            .derive(change_last_id + i + 1)
          , // address_index
      segwit:is_segwit);



      derived_change_keys.add(change_public_key);

    }

    await FirebaseUtil.addUserChangePublicKeys(derived_change_keys);

    _getUnusedPublicAddressAndPaintQR(context, false);
  }


  Future<void> _addRegisteredContacts() async {

    List<AppContact> contacts = await ContactsUtil.getRegisteredAppContacts(true);

    /*
    bool contactAdded = await sl.get<SharedPrefsUtil>().getFirstContactAdded();
    if (!contactAdded) {
      bool addressExists = await sl.get<DBHelper>().contactExistsWithAddress(
          "nano_1natrium1o3z5519ifou7xii8crpxpk8y65qmkih8e8bpsjri651oza8imdd");
      if (addressExists) {
        return;
      }
      bool nameExists =
          await sl.get<DBHelper>().contactExistsWithName("@BitorzoDonations");
      if (nameExists) {
        return;
      }
      await sl.get<SharedPrefsUtil>().setFirstContactAdded(true);
      AppContact c = AppContact(
          name: "@BitorZoDonations",
          address:
              "nano_1natrium1o3z5519ifou7xii8crpxpk8y65qmkih8e8bpsjri651oza8imdd");
      await sl.get<DBHelper>().saveContact(c);
    }
     */
  }


  void _updatePending() {
    setState() {

    }
  }

  void _updateContacts() {
    sl.get<DBHelper>().getContacts().then((contacts) {
      setState(() {
        _contacts = contacts;
      });
    });
  }

  StreamSubscription<HistoryHomeEvent> _historySub;
  StreamSubscription<UnconfirmedHomeEvent> _unconfirmedSub;
  StreamSubscription<ContactModifiedEvent> _contactModifiedSub;
  StreamSubscription<DisableLockTimeoutEvent> _disableLockSub;
  StreamSubscription<AccountChangedEvent> _switchAccountSub;
  StreamSubscription<PendingRequestEvent> _pendingRequestsModifiedSub;

  void _registerBus() {
    _historySub = EventTaxiImpl.singleton()
        .registerTo<HistoryHomeEvent>()
        .listen((event) {
      diffAndUpdateHistoryList(event.items);
      setState(() {
        _isRefreshing = false;
      });
      if (StateContainer
          .of(context)
          .initialDeepLink != null) {
        handleDeepLink(StateContainer
            .of(context)
            .initialDeepLink);
        StateContainer
            .of(context)
            .initialDeepLink = null;
      }
    });



    _unconfirmedSub = EventTaxiImpl.singleton()
        .registerTo<UnconfirmedHomeEvent>()
        .listen((event) {
      //diffAndUpdateHistoryList(event.items);
      diffAndUpdateUnconfirmedList(event.items ?? []);
      setState(() {
        _isRefreshing = false;
      });
      if (StateContainer
          .of(context)
          .initialDeepLink != null) {
        handleDeepLink(StateContainer
            .of(context)
            .initialDeepLink);
        StateContainer
            .of(context)
            .initialDeepLink = null;
      }
    });

    _contactModifiedSub = EventTaxiImpl.singleton()
        .registerTo<ContactModifiedEvent>()
        .listen((event) {
      _updateContacts();
    });

    // Hackish event to block auto-lock functionality
    _disableLockSub = EventTaxiImpl.singleton()
        .registerTo<DisableLockTimeoutEvent>()
        .listen((event) {
      if (event.disable) {
        cancelLockEvent();
      }
      _lockDisabled = event.disable;
    });
    // User changed account
    _switchAccountSub = EventTaxiImpl.singleton()
        .registerTo<AccountChangedEvent>()
        .listen((event) {
      setState(() {
        StateContainer
            .of(context)
            .wallet
            .loading = true;
        StateContainer
            .of(context)
            .wallet
            .historyLoading = true;
        _startAnimation();
        StateContainer.of(context).updateWallet(account: event.account);
      });

      // TODO : when supprting account chang -  get it back
      paintQrCode(address: receive_address_for_qr);

      if (event.delayPop) {
        Future.delayed(Duration(milliseconds: 300), () {
          Navigator.of(context).popUntil(RouteUtils.withNameLike("/home"));
        });
      } else if (!event.noPop) {
        Navigator.of(context).popUntil(RouteUtils.withNameLike("/home"));
      }
    });
  }

  @override
  void dispose() {
    _destroyBus();
    WidgetsBinding.instance.removeObserver(this);
    _placeholderCardAnimationController.dispose();
    super.dispose();
  }

  void _destroyBus() {
    if (_historySub != null) {
      _historySub.cancel();
    }

    if (_unconfirmedSub != null) {
      _unconfirmedSub.cancel();
    }

    if (_contactModifiedSub != null) {
      _contactModifiedSub.cancel();
    }
    if (_disableLockSub != null) {
      _disableLockSub.cancel();
    }
    if (_switchAccountSub != null) {
      _switchAccountSub.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle websocket connection when app is in background
    // terminate it to be eco-friendly
    switch (state) {
      case AppLifecycleState.paused:
        setAppLockEvent();
        StateContainer.of(context).disconnect();
        super.didChangeAppLifecycleState(state);
        break;
      case AppLifecycleState.resumed:
        cancelLockEvent();
        StateContainer.of(context).reconnect();
        if (!StateContainer
            .of(context)
            .wallet
            .loading &&
            StateContainer
                .of(context)
                .initialDeepLink != null) {
          handleDeepLink(StateContainer
              .of(context)
              .initialDeepLink);
          StateContainer
              .of(context)
              .initialDeepLink = null;
        }
        super.didChangeAppLifecycleState(state);
        break;
      default:
        super.didChangeAppLifecycleState(state);
        break;
    }
  }

  // To lock and unlock the app
  StreamSubscription<dynamic> lockStreamListener;

  Future<void> setAppLockEvent() async {
    if (((await sl.get<SharedPrefsUtil>().getLock()) ||
        StateContainer
            .of(context)
            .encryptedSecret != null) &&
        !_lockDisabled) {
      if (lockStreamListener != null) {
        lockStreamListener.cancel();
      }
      Future<dynamic> delayed = new Future.delayed(
          (await sl.get<SharedPrefsUtil>().getLockTimeout()).getDuration());
      delayed.then((_) {
        return true;
      });
      lockStreamListener = delayed.asStream().listen((_) {
        try {
          StateContainer.of(context).resetEncryptedSecret();
        } catch (e) {
          log.w(
              "Failed to reset encrypted secret when locking ${e.toString()}");
        } finally {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
        }
      });
    }
  }

  Future<void> cancelLockEvent() async {
    if (lockStreamListener != null) {
      lockStreamListener.cancel();
    }
  }

  // Used to build list items that haven't been removed.
  Widget _buildItem1(BuildContext context, int index, Animation<double> animation) {
    return new FutureBuilder(
        future: FirebaseUtil.getContactWhosAdressBelongsTo(
            _contacts, getUnconfirmedOrHistoryAccountByIndex(index)?.account),

        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if(getUnconfirmedOrHistoryAccountByIndex(index) == null) {
            return Container(width:0.0, height:0.0);
          }

          String displayName = smallScreen(context)
              ? getUnconfirmedOrHistoryAccountByIndex(index)?.getShorterString()
              : getUnconfirmedOrHistoryAccountByIndex(index)?.getShortString();
          if (snapshot.hasData) {
            if (snapshot.data != null) {
              displayName = snapshot.data.name;
            }
          }

          return _buildTransactionCard(
              getUnconfirmedOrHistoryAccountByIndex(index),
              animation,
              displayName,
              context);
        });
  }

  // Used to build list items that haven't been removed.
  /*
  Widget _buildItem(BuildContext context, int index,
      Animation<double> animation) {
    String displayName = smallScreen(context)
        ? _historyListMap[StateContainer
        .of(context)
        .wallet
        .address][index]
        .getShorterString()
        : _historyListMap[StateContainer
        .of(context)
        .wallet
        .address][index]
        .getShortString();
    _contacts.forEach((contact) {
      if (contact.address ==
          _historyListMap[StateContainer
              .of(context)
              .wallet
              .address][index]
              .account) {
        displayName = contact.name;
      }
    });

    return _buildTransactionCard(
        _historyListMap[StateContainer
            .of(context)
            .wallet
            .address][index],
        animation,
        displayName,
        context);
  }
*/

  Widget _getContactsShortcut(BuildContext context) {
    final _media = MediaQuery.of(context).size;
    return FutureBuilder(
        future: getUsersCard(),
        builder: (context, AsyncSnapshot<List<UserModel>> snapshot) {

          return ReactiveRefreshIndicator(
            backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
            child:ListView(
              padding: EdgeInsets.zero,
              physics: BouncingScrollPhysics(),
              children: <Widget>[
                Container(
                  color:  Colors.transparent,
                  width: _media.width*1.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(left: 7),
                        height: screenAwareSize(
                            _media.longestSide <= 775 ? 110 : 80, context),
                        child: NotificationListener<OverscrollIndicatorNotification>(
                          onNotification: (overscroll) {
                            overscroll.disallowGlow();
                          },
                          /** Habosssssssssssssssssssssss**/
                          child: ListView.builder(
                            physics: BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            itemCount: (snapshot?.data?.length ?? 0) + 1,
                            itemBuilder: (BuildContext context, int index) {
                              if (index == 0) {
                                return Padding(
                                    padding: EdgeInsets.only(right: 2),
                                    child: AddButton());
                              }

                              return Padding(
                                padding: EdgeInsets.only(right: 7),
                                child: UserCardWidget(
                                  user: snapshot.data[index-1],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            ),
            onRefresh: _refresh,
            isRefreshing: _isRefreshing,
          );
        }
    );

  }

  void _showPendingRequestsDialogs(List<DocumentSnapshot> docs) {
    if(docs.length == 0) {
      return;
    }
    DocumentSnapshot last_request = docs.removeLast();
    String amount_mbtc = NumberUtil.SatoshiToMilliBTC(last_request.data["amount"].toString());

    sl.get<DBHelper>().getContactWithPhone(last_request.data["sender"]).then((value) {

      AppDialogs.showReceiveConfirmDialog(context, "CONFIRM TRANSACTION", value?.name?? last_request.data["sender"], amount_mbtc, "Confirm",
              () {

        try {
          BitcoinUtil.publishTx(last_request.data["tx_data"]);
          FirebaseUtil.setPendingRequestStatus(last_request.documentID, confirmed : true);
        } catch(x) {
          log.d(x);
        }

        if(docs.length != 0)
        {
          _showPendingRequestsDialogs(docs);
        }

        },
          cancelText: "Deny",
          cancelAction: () {
        FirebaseUtil.setPendingRequestStatus(last_request.documentID, confirmed : false);
        if(docs.length != 0)
        {
          _showPendingRequestsDialogs(docs);
        }
      }
      );
    });
  }


  Widget _getPendingRequestsBadge(BuildContext context) {
    return new FutureBuilder(
        future: FirebaseUtil.getPendingRequestsStream(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData) {
            return StreamBuilder<QuerySnapshot>(
              stream: snapshot.data,
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {

                bool dont_show_counter = !snapshot.hasData || snapshot.data.documents.length == 0;
                //Tranactions Text End

                return AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 80.0,
                    height: mainCardHeight,
                    alignment: AlignmentDirectional(0, -1),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      margin: EdgeInsetsDirectional.only(
                          top: settingsIconMarginTop, start: 5),
                      height: 50,
                      width: 50,
                      child: FlatButton(
                          highlightColor: StateContainer
                              .of(context)
                              .curTheme
                              .text15,
                          splashColor: StateContainer
                              .of(context)
                              .curTheme
                              .text15,
                          onPressed: () {
                            _showPendingRequestsDialogs(snapshot.data.documents);
                          },
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50.0)),
                          padding: EdgeInsets.all(0.0),
                          child:  Stack(
                            children: <Widget>[
                              new Icon(Icons.notifications,
                                  color: StateContainer
                                      .of(context)
                                      .curTheme
                                      .text,
                                  size: 32),
                              new Positioned(
                                right: 0,
                                child: dont_show_counter? Container()  :
                                new Container(
                                  padding: EdgeInsets.all(1),
                                  decoration: new BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: new Text(
                                    snapshot.data.documents.length.toString(),
                                    style: new TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            ],
                          )),
                    )
                );
              },
            );
          } else { return Container();}
        }
    );



  }

  Widget _getPendingRequestsWidget(BuildContext context) {

    return new FutureBuilder(
        future: FirebaseUtil.getPendingRequestsStream(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return StreamBuilder<QuerySnapshot>(
              stream: snapshot.data,
              builder: (BuildContext context,
              AsyncSnapshot<QuerySnapshot> snapshot) {

            //Tranactions Text End
            if (!snapshot.hasData || snapshot.data.documents.length == 0)
              return Container(); //Transactions Text End;

            return GestureDetector(
                onTap: () {
                  _showPendingRequestsDialogs(snapshot.data.documents);
                },

                child: Container(
                    margin: EdgeInsetsDirectional.fromSTEB(
                        30.0, 20.0, 26.0, 0.0),
                    child: Row(
                      children: <Widget>[
                        Text(
                          CaseChange.toUpperCase(
                              "You have ${snapshot.data.documents.length} pending requests",
                              context),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w900,
                            color: StateContainer.of(context).curTheme.text,
                          ),
                        ),
                      ],
                    )
                )
            );

            Container(
                margin: EdgeInsetsDirectional.fromSTEB(
                    30.0, 20.0, 26.0, 0.0),
                child: Row(
                    children: <Widget>[
                      Text(
                        CaseChange.toUpperCase(
                            "You have ${snapshot.data.documents.length} pending requests",
                            context),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w900,
                          color: StateContainer.of(context).curTheme.text,
                        ),
                      ),
                    ]
                )
            );

            //

          },
    );
            } else {
          return Container(); //Transactions Text End;
        }
        }
    );



  }
  // Return widget for list


  Widget _getListWidget(BuildContext context) {

    // Setup history list
    if (!_listKeyMap.containsKey(StateContainer
        .of(context)
        .wallet
        ?.address)) {
      _listKeyMap.putIfAbsent(StateContainer
          .of(context)
          .wallet
          ?.address,
              () => GlobalKey<AnimatedListState>());


    }

    setState(() {
      _historyListMap.putIfAbsent(
          StateContainer
              .of(context)
              .wallet
              ?.address,
              () =>
              ListModel<AccountHistoryResponseItem>(
                listKey:
                _listKeyMap[StateContainer
                    .of(context)
                    .wallet
                    ?.address],
                initialItems: StateContainer
                    .of(context)
                    .wallet
                    ?.history ?? [],
              ));


      _unconfirmedListMap[StateContainer
          .of(context)
          .wallet
          ?.address] = ListModel<AccountHistoryResponseItem>(
                      listKey:
                      _listKeyMap[StateContainer
                          .of(context)
                          .wallet
                          ?.address ],
                      initialItems: StateContainer
                          .of(context)
                          .wallet
                          ?.unconfirmed,
      );
    });


    return ReactiveRefreshIndicator(
      backgroundColor: StateContainer
          .of(context)
          .curTheme
          .backgroundDark,
      child: AnimatedList(
        key: _listKeyMap[StateContainer.of(context).wallet?.address],
        padding: EdgeInsetsDirectional.fromSTEB(0, 5.0, 0, 15.0),
        initialItemCount:
            _historyListMap.length == 0 ? 0
            :
            (_historyListMap[StateContainer
            .of(context)
            .wallet
            ?.address]?.length ?? 0) +
            (_unconfirmedListMap[StateContainer
            .of(context)
            .wallet
            ?.address]?.length ?? 0) ,
        itemBuilder: _buildItem1,
      ),
      onRefresh: _refresh,
      isRefreshing: _isRefreshing,
    );
  }

  // Refresh list
  Future<void> _refresh() async {
    setState(() {
      _isRefreshing = true;
    });
    sl.get<HapticUtil>().success();
    StateContainer.of(context).requestUpdate();
    // Hide refresh indicator after 3 seconds if no server response
    Future.delayed(new Duration(seconds: 3), () {
      setState(() {
        _isRefreshing = false;
      });
    });
  }

  ///
  /// Because there's nothing convenient like DiffUtil, some manual logic
  /// to determine the differences between two lists and to add new items.
  ///
  /// Depends on == being overriden in the AccountHistoryResponseItem class
  ///
  /// Required to do it this way for the animation
  ///
  void diffAndUpdateHistoryList(List<AccountHistoryResponseItem> newList) {
    if (newList == null ||
        newList.length == 0 ||
        _historyListMap[StateContainer
            .of(context)
            .wallet
            .address] == null)
      return;
    // Get items not in current list, and add them from top-down
    newList.reversed
        .where((item) =>
    !_historyListMap[StateContainer
        .of(context)
        .wallet
        .address]
        .items
        .contains(item))
        .forEach((historyItem) {
      setState(() {
        _historyListMap[StateContainer
            .of(context)
            .wallet
            .address]
            .insertAtTop(historyItem);
      });
    });
    // Re-subscribe if missing data
    if (StateContainer
        .of(context)
        .wallet
        .loading) {
      StateContainer.of(context).requestSubscribe();
    }
  }


  void diffAndUpdateUnconfirmedList(List<AccountHistoryResponseItem> newList) {
    setState(() {
      _unconfirmedListMap[StateContainer
          .of(context)
          .wallet
          .address] = ListModel<AccountHistoryResponseItem>(
        listKey:
        _listKeyMap[StateContainer
            .of(context)
            .wallet
            .address],
        initialItems: StateContainer
            .of(context)
            .wallet
            .unconfirmed,
      );

      newList.forEach((item)
      {
        _unconfirmedListMap[StateContainer
            .of(context)
            .wallet
            .address].insertAtTop(item);
      });


    });

    /*
    if (newList == null ||
        newList.length == 0 ||
        _historyListMap[StateContainer
            .of(context)
            .wallet
            .address] == null)
      return;
    // Get items not in current list, and add them from top-down
    newList.reversed
        .where((item) =>
    !_unconfirmedListMap[StateContainer
        .of(context)
        .wallet
        .address]
        .items
        .contains(item))
        .forEach((unconfirmedItem) {
      setState(() {
        _unconfirmedListMap[StateContainer
            .of(context)
            .wallet
            .address]
            .insertAtTop(unconfirmedItem);
      });
    });
    // Re-subscribe if missing data
    if (StateContainer
        .of(context)
        .wallet
        .loading) {
      StateContainer.of(context).requestSubscribe();
    }

  */
  }


  Future<void> handleDeepLink(link) async {
    Address address = Address(link);
    if (address.isValid()) {
      String amount;
      String contactName;
      if (address.amount != null) {
        BigInt amountBigInt = BigInt.parse(address.amount);
        // Require minimum 1 rai to send, and make sure sufficient balance
        if (amountBigInt != null &&
            StateContainer
                .of(context)
                .wallet
                .accountBalance > amountBigInt &&
            amountBigInt >= BigInt.from(10).pow(24)) {
          amount = address.amount;
        }
      }
      // See if a contact
      AppContact contact =
      await sl.get<DBHelper>().getContactWithAddress(address.address);
      if (contact != null) {
        contactName = contact.name;
      }
      // Remove any other screens from stack
      Navigator.of(context).popUntil(RouteUtils.withNameLike('/home'));
      if (amount != null) {
        // Go to send confirm with amount
        Sheets.showAppHeightNineSheet(
            context: context,
            widget: SendConfirmSheet(
                amountRaw: amount,
                destination: address.address,
                contact: contact));
      } else {
        // Go to send with address
        Sheets.showAppHeightNineSheet(
            context: context,
            widget: SendSheet(
                localCurrency: StateContainer
                    .of(context)
                    .curCurrency,
                contact: contact,
                address: address.address));
      }
    } else if (MantaWallet.parseUrl(link) != null) {
      // Manta URI handling
      try {
        _showMantaAnimation();
        // Get manta payment request
        MantaWallet manta = MantaWallet(link);
        PaymentRequestMessage paymentRequest =
        await MantaUtil.getPaymentDetails(manta);
        if (mantaAnimationOpen) {
          Navigator.of(context).pop();
        }
        MantaUtil.processPaymentRequest(context, manta, paymentRequest);
      } catch (e) {
        if (mantaAnimationOpen) {
          Navigator.of(context).pop();
        }
        UIUtil.showSnackbar(AppLocalization
            .of(context)
            .mantaError, context);
      }
    }
  }

  void _showMantaAnimation() {
    mantaAnimationOpen = true;
    Navigator.of(context).push(AnimationLoadingOverlay(
        AnimationType.MANTA,
        StateContainer
            .of(context)
            .curTheme
            .animationOverlayStrong,
        StateContainer
            .of(context)
            .curTheme
            .animationOverlayMedium,
        onPoppedCallback: () => mantaAnimationOpen = false));
  }

  void paintQrCode({String address}) {
    //address = "habhabhabhabhabhabhabhabhabhabhabhabhabhab";
    QrPainter painter = QrPainter(
      data:
      address,
      version: 6,
      gapless: false,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );
    painter.toImageData(MediaQuery
        .of(context)
        .size
        .width).then((byteData) {
      setState(() {
        receive = ReceiveSheet(
            qrWidget: Container(width: MediaQuery
                .of(context)
                .size
                .width / 2.675,
                child: Image.memory(byteData.buffer.asUint8List())),
            publicKey: address);
      });
    });
  }

  @override
  Widget build(BuildContext context) {



    return AppScaffold(

      resizeToAvoidBottomPadding: false,
      key: _scaffoldKey,
      backgroundColor: StateContainer
          .of(context)
          .curTheme
          .background,
      drawer: SizedBox(
        width: UIUtil.drawerWidth(context),
        child: AppDrawer(
          child: SettingsSheet(),
        ),
      ),
      body: SafeArea(
        minimum: EdgeInsets.only(
            top: MediaQuery
                .of(context)
                .size
                .height * 0.045,
            bottom: MediaQuery
                .of(context)
                .size
                .height * 0.035),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  //Everything else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      //Main Card
                      _buildMainCard(context, _scaffoldKey),

                      //Main Card End

//                      Container(
//                        margin: EdgeInsetsDirectional.fromSTEB(
//                            60.0, 20.0, 26.0, 0.0),
//                        child: Row(
//                          children: <Widget>[
//                            Text(
//                              CaseChange.toUpperCase(
//                                  AppLocalization.of(context).transactions,
//                                  context),
//                              textAlign: TextAlign.center,
//                              style: TextStyle(
//                                fontSize: 14.0,
//                                fontWeight: FontWeight.w100,
//                                color: StateContainer.of(context).curTheme.text,
//                              ),
//                            ),
//                          ],
//                        ),
//                      ), //Transactions Text End


                      //Contacts Text
                      _getPendingRequestsWidget(context),



                      Container(
                        margin: EdgeInsetsDirectional.fromSTEB(
                            30.0, 20.0, 26.0, 0.0),
                        child: Row(
                          children: <Widget>[
                            Text(
                              CaseChange.toUpperCase(
                                  AppLocalization.of(context).contacts,
                                  context),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w100,
                                color: StateContainer.of(context).curTheme.text,
                              ),
                            ),
                          ],
                        ),
                      ), //Transactions Text End

                      //Transactions List

                      Container(
                          height: 100,

                        child:Stack(


                          children: <Widget>[

                            _getContactsShortcut(context),
                           // _getListWidget(context),

                            //List Top Gradient End
                            // List Top Gradient End

                            //List Bottom Gradient
                            /*
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 30.0,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      StateContainer
                                          .of(context)
                                          .curTheme
                                          .background00,
                                      StateContainer
                                          .of(context)
                                          .curTheme
                                          .background
                                    ],
                                    begin: AlignmentDirectional(0.5, -1),
                                    end: AlignmentDirectional(0.5, 0.5),
                                  ),
                                ),
                              ),
                            ), //List Bottom Gradient End
                             */
                          ],
                        ),
                        ),

                      Container(
                        margin: EdgeInsetsDirectional.fromSTEB(
                            30.0, 20.0, 26.0, 0.0),
                        child: Row(
                          children: <Widget>[
                            Text(
                              CaseChange.toUpperCase(
                                  AppLocalization.of(context).transactions,
                                  context),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w100,
                                color: StateContainer.of(context).curTheme.text,
                              ),
                            ),
                          ],
                        ),
                      ), //Transactions Text End
                      //Transactions List

                      Expanded(

                        child: Stack(

                          alignment: Alignment.topCenter,
                          children: <Widget>[

                            //_getContactsShortcut(context),
                            _getListWidget(context),

                            //List Top Gradient End
                     // List Top Gradient End

                            //List Bottom Gradient
                            /*
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 50.0,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      StateContainer
                                          .of(context)
                                          .curTheme
                                          .background00,
                                      StateContainer
                                          .of(context)
                                          .curTheme
                                          .background
                                    ],
                                    begin: AlignmentDirectional(0.5, -1),
                                    end: AlignmentDirectional(0.5, 0.5),
                                  ),
                                ),
                              ),
                            ), //List Bottom Gradient End
                            */

                          ],
                        ),
                      ), //Transactions List End
                      //Buttons background
                      SizedBox(
                        height: 30,
                        width: MediaQuery
                            .of(context)
                            .size
                            .width,
                      ), //Buttons background
                    ],
                  ),
                  // Buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            StateContainer
                                .of(context)
                                .curTheme
                                .boxShadowButton
                          ],
                        ),
                        height: 55,
                        width: (MediaQuery
                            .of(context)
                            .size
                            .width - 42) / 2,
                        margin: EdgeInsetsDirectional.only(
                            start: 14, top: 0.0, end: 7.0),
                        child: FlatButton(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100.0)),
                          color: receive != null
                              ? StateContainer
                              .of(context)
                              .curTheme
                              .primary
                              : StateContainer
                              .of(context)
                              .curTheme
                              .primary60,
                          child: AutoSizeText(
                            AppLocalization
                                .of(context)
                                .receive,
                            textAlign: TextAlign.center,
                            style: AppStyles.textStyleButtonPrimary(context),
                            maxLines: 1,
                            stepGranularity: 0.5,
                          ),
                          onPressed: () {

                            _getUnusedPublicAddressAndPaintQR(context, true).then((_)
                                {
                                Sheets.showAppHeightEightSheet(
                                context: context, widget: receive);
                                });
                          },
                          highlightColor: receive != null
                              ? StateContainer
                              .of(context)
                              .curTheme
                              .background40
                              : Colors.transparent,
                          splashColor: receive != null
                              ? StateContainer
                              .of(context)
                              .curTheme
                              .background40
                              : Colors.transparent,
                        ),
                      ),
                      AppPopupButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Transaction Card/List Item
  Widget _buildTransactionCard(AccountHistoryResponseItem item,
      Animation<double> animation, String displayName, BuildContext context) {
    String text;
    IconData icon;
    Color iconColor;
    if (item.type == BlockTypes.SEND) {
      text = AppLocalization
          .of(context)
          .sent;
      icon = AppIcons.sent;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .text60;
    }
    else if (item.type == BlockTypes.RECEIVE) {
      text = AppLocalization
          .of(context)
          .received;
      icon = AppIcons.received;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .primary60;
    }
    else if (item.type == BlockTypes.SEND_UNCONFIRMED) {
      text = AppLocalization
          .of(context)
          .sent_unconfirmed;
      icon = AppIcons.sent;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .text60;
    }
    else if (item.type == BlockTypes.RECEIVE_UNCONFIRMED) {
      text = AppLocalization
          .of(context)
          .received_unconfirmed;
      icon = AppIcons.received;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .primary60;
    }
      return Slidable(
      delegate: SlidableScrollDelegate(),
      actionExtentRatio: 0.35,
      movementDuration: Duration(milliseconds: 300),
      enabled: StateContainer
          .of(context)
          .wallet != null &&
          StateContainer
              .of(context)
              .wallet
              .accountBalance > BigInt.zero,
      //enabled: true,
      onTriggered: (preempt) {
        if (preempt) {
          setState(() {
            releaseAnimation = true;
          });
        } else {
          // See if a contact
          sl
              .get<DBHelper>()
              .getContactWithAddress(item.account)
              .then((contact) {
            // Go to send with address
            Sheets.showAppHeightNineSheet(
                context: context,
                widget: SendSheet(
                  localCurrency: StateContainer
                      .of(context)
                      .curCurrency,
                  contact: contact,
                  address: item.account,
                  quickSendAmount: item.amount,
                ));
          });
        }
      },
      onAnimationChanged: (animation) {
        if (animation != null) {
          _fanimationPosition = animation.value;
          if (animation.value == 0.0 && releaseAnimation) {
            setState(() {
              releaseAnimation = false;
            });
          }
        }
      },
      secondaryActions: <Widget>[
        SlideAction(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            margin: EdgeInsetsDirectional.only(
                end: MediaQuery
                    .of(context)
                    .size
                    .width * 0.15,
                top: 4,
                bottom: 4),
            child: Container(
              alignment: AlignmentDirectional(-0.5, 0),
              constraints: BoxConstraints.expand(),
              child: FlareActor("assets/pulltosend_animation.flr",
                  animation: "pull",
                  fit: BoxFit.contain,
                  controller: this,
                  color: StateContainer
                      .of(context)
                      .curTheme
                      .primary),
            ),
          ),
        ),
      ],
      child: _SizeTransitionNoClip(
        sizeFactor: animation,
        child: Container(
          margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
          decoration: BoxDecoration(
            color: StateContainer
                .of(context)
                .curTheme
                .backgroundDark,
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: [StateContainer
                .of(context)
                .curTheme
                .boxShadow
            ],
          ),
          child: FlatButton(
            highlightColor: StateContainer
                .of(context)
                .curTheme
                .text15,
            splashColor: StateContainer
                .of(context)
                .curTheme
                .text15,
            color: StateContainer
                .of(context)
                .curTheme
                .backgroundDark,
            padding: EdgeInsets.all(0.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            onPressed: () {
              Sheets.showAppHeightEightSheet(
                  context: context,
                  widget: TransactionDetailsSheet(
                      hash: item.hash,
                      address: item.account,
                      displayName: displayName),
                  animationDurationMs: 175);
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                            margin: EdgeInsetsDirectional.only(end: 16.0),
                            child: Icon(icon, color: iconColor, size: 20)),
                        Container(
                          width: MediaQuery
                              .of(context)
                              .size
                              .width / 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                text,
                                textAlign: TextAlign.start,
                                style:
                                AppStyles.textStyleTransactionType(context),
                              ),
                              RichText(
                                textAlign: TextAlign.start,
                                text: TextSpan(
                                  text: '',
                                  children: [
                                    TextSpan(
                                      text: item.getFormattedAmount(),
                                      style:
                                      AppStyles.textStyleTransactionAmount(
                                          context),
                                    ),
                                    TextSpan(
                                      text: " mBTC",
                                      style: AppStyles.textStyleTransactionUnit(
                                          context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width / 2.4,
                      child: Text(
                        displayName,
                        textAlign: TextAlign.end,
                        style: AppStyles.textStyleTransactionAddress(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } //Transaction Card End

  // Dummy Transaction Card
  Widget _buildDummyTransactionCard(String type, String amount, String address,
      BuildContext context) {
    String text;
    IconData icon;
    Color iconColor;
    if (type == AppLocalization
        .of(context)
        .sent) {
      text = AppLocalization
          .of(context)
          .sent;
      icon = AppIcons.sent;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .text60;
    } else {
      text = AppLocalization
          .of(context)
          .received;
      icon = AppIcons.received;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .primary60;
    }
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer
            .of(context)
            .curTheme
            .boxShadow
        ],
      ),
      child: FlatButton(
        onPressed: () {
          return null;
        },
        highlightColor: StateContainer
            .of(context)
            .curTheme
            .text15,
        splashColor: StateContainer
            .of(context)
            .curTheme
            .text15,
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        padding: EdgeInsets.all(0.0),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Center(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                        margin: EdgeInsetsDirectional.only(end: 16.0),
                        child: Icon(icon, color: iconColor, size: 20)),
                    Container(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width / 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            text,
                            textAlign: TextAlign.start,
                            style: AppStyles.textStyleTransactionType(context),
                          ),
                          RichText(
                            textAlign: TextAlign.start,
                            text: TextSpan(
                              text: '',
                              children: [
                                TextSpan(
                                  text: amount,
                                  style: AppStyles.textStyleTransactionAmount(
                                      context),
                                ),
                                TextSpan(
                                  text: " NANO",
                                  style: AppStyles.textStyleTransactionUnit(
                                      context),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: MediaQuery
                      .of(context)
                      .size
                      .width / 2.4,
                  child: Text(
                    address,
                    textAlign: TextAlign.end,
                    style: AppStyles.textStyleTransactionAddress(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } //Dummy Transaction Card End


  TextSpan _getContactsHeaderSpan(BuildContext context) {
    final _media = MediaQuery
        .of(context)
        .size;
    String workingStr;
    if (StateContainer
        .of(context)
        .selectedAccount == null ||
        StateContainer
            .of(context)
            .selectedAccount
            .index == 0) {
      workingStr = AppLocalization
          .of(context)
          .exampleCardIntro;
    } else {
      workingStr = AppLocalization
          .of(context)
          .newAccountIntro;
    }
    if (!workingStr.contains("NANO")) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    // Colorize NANO
    List<String> splitStr = workingStr.split("NANO");
    if (splitStr.length != 2) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    return TextSpan(
      text: '',
      children: [
        TextSpan(
          text: splitStr[0],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
        TextSpan(
          text: "BTC",
          style: AppStyles.textStyleTransactionWelcomePrimary(context),
        ),
        TextSpan(
          text: splitStr[1],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
      ],
    );
  }

  // Welcome Card
  TextSpan _getExampleHeaderSpan(BuildContext context) {
    String workingStr;
    if (StateContainer
        .of(context)
        .selectedAccount == null ||
        StateContainer
            .of(context)
            .selectedAccount
            .index == 0) {
      workingStr = AppLocalization
          .of(context)
          .exampleCardIntro;
    } else {
      workingStr = AppLocalization
          .of(context)
          .newAccountIntro;
    }
    if (!workingStr.contains("BITCOIN")) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    // Colorize NANO
    List<String> splitStr = workingStr.split("BITCOIN");
    if (splitStr.length != 2) {
      return TextSpan(
        text: workingStr,
        style: AppStyles.textStyleTransactionWelcome(context),
      );
    }
    return TextSpan(
      text: '',
      children: [
        TextSpan(
          text: splitStr[0],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
        TextSpan(
          text: "BITCOIN",
          style: AppStyles.textStyleTransactionWelcomePrimary(context),
        ),
        TextSpan(
          text: splitStr[1],
          style: AppStyles.textStyleTransactionWelcome(context),
        ),
      ],
    );
  }

  Widget _buildLoadingTransactionCard(String type, String amount,
      String address, BuildContext context) {
    String text;
    IconData icon;
    Color iconColor;
    if (type == "Sent") {
      text = "Senttt";
      icon = AppIcons.dotfilled;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .text20;
    } else {
      text = "Receiveddd";
      icon = AppIcons.dotfilled;
      iconColor = StateContainer
          .of(context)
          .curTheme
          .primary20;
    }
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(40.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer
            .of(context)
            .curTheme
            .boxShadow
        ],
      ),
      child: FlatButton(
        onPressed: () {
          return null;
        },
        highlightColor: StateContainer
            .of(context)
            .curTheme
            .text15,
        splashColor: StateContainer
            .of(context)
            .curTheme
            .text15,
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        padding: EdgeInsets.all(0.0),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Center(
          child: Padding(
            padding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // Transaction Icon
                    Opacity(
                      opacity: _opacityAnimation.value,
                      child: Container(
                          margin: EdgeInsetsDirectional.only(end: 16.0),
                          child: Icon(icon, color: iconColor, size: 20)),
                    ),
                    Container(
                      width: MediaQuery
                          .of(context)
                          .size
                          .width / 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Transaction Type Text
                          Container(
                            child: Stack(
                              alignment: AlignmentDirectional(-1, 0),
                              children: <Widget>[
                                Text(
                                  text,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: "NunitoSans",
                                    fontSize: AppFontSizes.small,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.transparent,
                                  ),
                                ),
                                Opacity(
                                  opacity: _opacityAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: StateContainer
                                          .of(context)
                                          .curTheme
                                          .text45,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      text,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontFamily: "NunitoSans",
                                        fontSize: AppFontSizes.small - 4,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Amount Text
                          Container(
                            child: Stack(
                              alignment: AlignmentDirectional(-1, 0),
                              children: <Widget>[
                                Text(
                                  amount,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      fontFamily: "NunitoSans",
                                      color: Colors.transparent,
                                      fontSize: AppFontSizes.smallest,
                                      fontWeight: FontWeight.w600),
                                ),
                                Opacity(
                                  opacity: _opacityAnimation.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: StateContainer
                                          .of(context)
                                          .curTheme
                                          .primary20,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      amount,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                          fontFamily: "NunitoSans",
                                          color: Colors.transparent,
                                          fontSize: AppFontSizes.smallest - 3,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Address Text
                Container(
                  width: MediaQuery
                      .of(context)
                      .size
                      .width / 2.4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        child: Stack(
                          alignment: AlignmentDirectional(1, 0),
                          children: <Widget>[
                            Text(
                              address,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: AppFontSizes.smallest,
                                fontFamily: 'OverpassMono',
                                fontWeight: FontWeight.w100,
                                color: Colors.transparent,
                              ),
                            ),
                            Opacity(
                              opacity: _opacityAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: StateContainer
                                      .of(context)
                                      .curTheme
                                      .text20,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  address,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: AppFontSizes.smallest - 3,
                                    fontFamily: 'OverpassMono',
                                    fontWeight: FontWeight.w100,
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContacts(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer
            .of(context)
            .curTheme
            .boxShadow
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0)),
                color: StateContainer
                    .of(context)
                    .curTheme
                    .primary,
                boxShadow: [StateContainer
                    .of(context)
                    .curTheme
                    .boxShadow
                ],
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 15.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: _getContactsHeaderSpan(context),
                ),
              ),
            ),
            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0)),
                color: StateContainer
                    .of(context)
                    .curTheme
                    .primary,
              ),
            ),
          ],
        ),
      ),
    );
  } // Welcome Card End


  Widget _buildWelcomeTransactionCard(BuildContext context) {
    final _media = MediaQuery
        .of(context)
        .size;

    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(14.0, 4.0, 14.0, 4.0),
      decoration: BoxDecoration(
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer
            .of(context)
            .curTheme
            .boxShadow
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.0),
                    bottomLeft: Radius.circular(10.0)),
                color: StateContainer
                    .of(context)
                    .curTheme
                    .primary,
                boxShadow: [StateContainer
                    .of(context)
                    .curTheme
                    .boxShadow
                ],
              ),
            ),
            Flexible(

              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14.0, horizontal: 15.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: _getExampleHeaderSpan(context),
                ),
              ),
            ),

            Container(
              width: 7.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(10.0),
                    bottomRight: Radius.circular(10.0)),
                color: StateContainer
                    .of(context)
                    .curTheme
                    .primary,
              ),
            ),
          ],
        ),
      ),
    );
  } // Welcome Card End

  // Loading Transaction Card
  // Loading Transaction Card End

  //Main Card
  Widget _buildMainCard(BuildContext context, _scaffoldKey) {
    return Container(
      decoration: BoxDecoration(
        color: StateContainer
            .of(context)
            .curTheme
            .backgroundDark,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [StateContainer
            .of(context)
            .curTheme
            .boxShadow
        ],
      ),
      margin: EdgeInsets.only(
          left: 14.0,
          right: 14.0,
          top: MediaQuery
              .of(context)
              .size
              .height * 0.005),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 80.0,
            height: mainCardHeight,
            alignment: AlignmentDirectional(-1, -1),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: EdgeInsetsDirectional.only(
                  top: settingsIconMarginTop, start: 5),
              height: 50,
              width: 50,
              child: FlatButton(
                  highlightColor: StateContainer
                      .of(context)
                      .curTheme
                      .text15,
                  splashColor: StateContainer
                      .of(context)
                      .curTheme
                      .text15,
                  onPressed: () {
                    _scaffoldKey.currentState.openDrawer();
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0)),
                  padding: EdgeInsets.all(0.0),
                  child: Icon(AppIcons.settings,
                      color: StateContainer
                          .of(context)
                          .curTheme
                          .text,
                      size: 24)),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            height: mainCardHeight,
            curve: Curves.easeInOut,
            child: _getBalanceWidget(),
          ),

          _getPendingRequestsBadge(context)

          // Nnnnn
          /*
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 80.0,
            height: mainCardHeight,
            alignment: Alignment(0, 0),
            /* child: Container(
              width: 70.0,
              height: 70.0,
              margin: EdgeInsetsDirectional.fromSTEB(0, 6, 10, 4),
              child: SvgPicture.network(
                'https://natricon-go-server.appditto.com/api/svg?address=' +
                    StateContainer.of(context).wallet.address,
                placeholderBuilder: (BuildContext context) => Container(
                    padding: const EdgeInsets.all(10.0),
                    child: const CircularProgressIndicator()),
              ),
            ), */
          ),

           */
        ],
      ),
    );
  } //Main Card

  // Get balance display
  Widget _getBalanceWidget() {
    if (StateContainer
        .of(context)
        .wallet == null ||
        StateContainer
            .of(context)
            .wallet
            .loading) {
      // Placeholder for balance text
      return Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _priceConversion == PriceConversion.BTC
                ? Container(
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  Text(
                    "1234567",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: "NunitoSans",
                        fontSize: AppFontSizes.small,
                        fontWeight: FontWeight.w600,
                        color: Colors.transparent),
                  ),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer
                            .of(context)
                            .curTheme
                            .text20,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        "1234567",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: "NunitoSans",
                            fontSize: AppFontSizes.small - 3,
                            fontWeight: FontWeight.w600,
                            color: Colors.transparent),
                      ),
                    ),
                  ),
                ],
              ),
            )
                : SizedBox(),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery
                      .of(context)
                      .size
                      .width - 225),
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  AutoSizeText(
                    "1234567",
                    style: TextStyle(
                        fontFamily: "NunitoSans",
                        fontSize: AppFontSizes.largestc,
                        fontWeight: FontWeight.w900,
                        color: Colors.transparent),
                    maxLines: 1,
                    stepGranularity: 0.1,
                    minFontSize: 1,
                  ),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer
                            .of(context)
                            .curTheme
                            .primary60,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: AutoSizeText(
                        "1234567",
                        style: TextStyle(
                            fontFamily: "NunitoSans",
                            fontSize: AppFontSizes.largestc - 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.transparent),
                        maxLines: 1,
                        stepGranularity: 0.1,
                        minFontSize: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _priceConversion == PriceConversion.BTC
                ? Container(
              child: Stack(
                alignment: AlignmentDirectional(0, 0),
                children: <Widget>[
                  Text(
                    "1234567",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: "NunitoSans",
                        fontSize: AppFontSizes.small,
                        fontWeight: FontWeight.w600,
                        color: Colors.transparent),
                  ),
                  Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: StateContainer
                            .of(context)
                            .curTheme
                            .text20,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        "1234567",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: "NunitoSans",
                            fontSize: AppFontSizes.small - 3,
                            fontWeight: FontWeight.w600,
                            color: Colors.transparent),
                      ),
                    ),
                  ),
                ],
              ),
            )
                : SizedBox(),
          ],
        ),
      );
    }
    // Balance texts
    return GestureDetector(
      onTap: () {
        if (_priceConversion == PriceConversion.BTC) {
          // Hide prices
          setState(() {
            _priceConversion = PriceConversion.NONE;
            mainCardHeight = 64;
            settingsIconMarginTop = 7;
          });
          sl.get<SharedPrefsUtil>().setPriceConversion(PriceConversion.NONE);
        } else if (_priceConversion == PriceConversion.NONE) {
          // Cyclce to hidden
          setState(() {
            _priceConversion = PriceConversion.HIDDEN;
            mainCardHeight = 64;
            settingsIconMarginTop = 7;
          });
          sl.get<SharedPrefsUtil>().setPriceConversion(PriceConversion.HIDDEN);
        } else if (_priceConversion == PriceConversion.HIDDEN) {
          // Cycle to BTC price
          setState(() {
            mainCardHeight = 120;
            settingsIconMarginTop = 5;
          });
          Future.delayed(Duration(milliseconds: 150), () {
            setState(() {
              _priceConversion = PriceConversion.BTC;
            });
          });
          sl.get<SharedPrefsUtil>().setPriceConversion(PriceConversion.BTC);
        }
      },
      child: Container(
        alignment: Alignment.center,
        width: MediaQuery
            .of(context)
            .size
            .width - 190,
        color: Colors.transparent,
        child: _priceConversion == PriceConversion.HIDDEN
            ?
        // BTC logo
        Center(
            child: Container(
                child: Icon(AppIcons.btc,
                    size: 32,
                    color: StateContainer
                        .of(context)
                        .curTheme
                        .primary)))
            : Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _priceConversion == PriceConversion.BTC
                  ? Text(
                  StateContainer
                      .of(context)
                      .wallet
                      .getLocalCurrencyPrice(
                      StateContainer
                          .of(context)
                          .curCurrency,
                      locale: StateContainer
                          .of(context)
                          .currencyLocale),
                  textAlign: TextAlign.center,
                  style: AppStyles.textStyleCurrencyAlt(context))
                  : SizedBox(height: 0),
              Container(
                margin: EdgeInsetsDirectional.only(end: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      constraints: BoxConstraints(
                          maxWidth:
                          MediaQuery
                              .of(context)
                              .size
                              .width - 200),
                      child: AutoSizeText.rich(
                        TextSpan(
                          children: [
                            // Currency Icon
                            TextSpan(
                              text: "m₿",
                              style: TextStyle(
                                fontFamily: 'AppIcons',
                                color: StateContainer
                                    .of(context)
                                    .curTheme
                                    .primary,
                                fontSize: _priceConversion ==
                                    PriceConversion.BTC
                                    ? 26.0
                                    : 20,
                              ),
                            ),
                            // Main balance text
                            TextSpan(
                              text: StateContainer
                                  .of(context)
                                  .wallet
                                  .getAccountBalanceDisplay(),
                              style: _priceConversion ==
                                  PriceConversion.BTC
                                  ? AppStyles.textStyleCurrency(context)
                                  : AppStyles.textStyleCurrencySmaller(
                                  context),
                            ),
                            /*
                                  TextSpan(
                                    text: StateContainer.of(context)
                                        .wallet.getUnconfirmedTotalAmountDisplay(),
                                    style: _priceConversion ==
                                        PriceConversion.BTC
                                        ? AppStyles.textStyleCurrency(context)
                                        : AppStyles.textStyleCurrencySmaller(
                                        context),
                                  ),
                                  */

                          ],
                        ),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize:
                            _priceConversion == PriceConversion.BTC
                                ? 28
                                : 22),
                        stepGranularity: 0.1,
                        minFontSize: 1,
                        maxFontSize:
                        _priceConversion == PriceConversion.BTC
                            ? 28
                            : 22,
                      ),
                    ),
                  ],
                ),
              ),

              _priceConversion == PriceConversion.BTC
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  /*
                              Icon(AppIcons.btc,
                                  //_priceConversion == PriceConversion.BTC
                                  //    ? AppIcons.btc
                                  //    : AppIcons.nanocurrency,
                                  color:
                                  _priceConversion == PriceConversion.NONE
                                      ? Colors.transparent
                                      : StateContainer.of(context)
                                      .curTheme
                                      .text60,
                                  size: 14),

                               */
                  StateContainer
                      .of(context)
                      .wallet
                      .hasUnconfirmed() && StateContainer
                      .of(context)
                      .wallet.getSumUnconfirmed() != BigInt.from(0)
                      ?
                  Text("(${StateContainer
                      .of(context)
                      .wallet
                      .getUnconfirmedTotalAmountDisplay()} ${AppLocalization
                      .of(context)
                      .unconfirmed})",
                      textAlign: TextAlign.center,
                      style:
                      AppStyles.textStyleCurrencyAlt(context))
                      :
                  Text(""),


                ],
              )
                  :

              SizedBox(height: 0),


            ],
          ),
        ),
      ),
    );
  }

  AccountHistoryResponseItem getUnconfirmedOrHistoryAccountByIndex(int index) {

    // index = index - 1;
    int num_unconfirmed = _unconfirmedListMap[StateContainer
        .of(context)
        .wallet
        .address].length;

    int num_history = _historyListMap[StateContainer
        .of(context)
        .wallet
        .address].length;

    if (index >= 0 && index < num_unconfirmed) {
      return _unconfirmedListMap[StateContainer
          .of(context)
          .wallet
          .address][index];
    } else if (index >= num_unconfirmed && (index - num_unconfirmed) < num_history) {
      return _historyListMap[StateContainer
          .of(context)
          .wallet
          .address][index - num_unconfirmed];
    } else {
      
      return null;
    }
  }
}

class TransactionDetailsSheet extends StatefulWidget {
  final String hash;
  final String address;
  final String displayName;

  TransactionDetailsSheet({this.hash, this.address, this.displayName})
      : super();

  _TransactionDetailsSheetState createState() =>
      _TransactionDetailsSheetState();
}

class _TransactionDetailsSheetState extends State<TransactionDetailsSheet> {
  // Current state references
  bool _addressCopied = false;
  // Timer reference so we can cancel repeated events
  Timer _addressCopiedTimer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height * 0.035,
      ),
      child: Container(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Column(
              children: <Widget>[
                // A stack for Copy Address and Add Contact buttons
                Stack(
                  children: <Widget>[
                    // A row for Copy Address Button
                    Row(
                      children: <Widget>[
                        AppButton.buildAppButton(
                            context,
                            // Share Address Button
                            _addressCopied
                                ? AppButtonType.SUCCESS
                                : AppButtonType.PRIMARY,
                            _addressCopied
                                ? AppLocalization.of(context).addressCopied
                                : AppLocalization.of(context).copyAddress,
                            Dimens.BUTTON_TOP_EXCEPTION_DIMENS, onPressed: () {
                          Clipboard.setData(
                              new ClipboardData(text: widget.address));
                          if (mounted) {
                            setState(() {
                              // Set copied style
                              _addressCopied = true;
                            });
                          }
                          if (_addressCopiedTimer != null) {
                            _addressCopiedTimer.cancel();
                          }
                          _addressCopiedTimer =
                              new Timer(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              setState(() {
                                _addressCopied = false;
                              });
                            }
                          });
                        }),
                      ],
                    ),
                    // A row for Add Contact Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          margin: EdgeInsetsDirectional.only(
                              top: Dimens.BUTTON_TOP_EXCEPTION_DIMENS[1],
                              end: Dimens.BUTTON_TOP_EXCEPTION_DIMENS[2]),
                          child: Container(
                            height: 55,
                            width: 55,
                            // Add Contact Button
                            child: !widget.displayName.startsWith("@")
                                ? FlatButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Sheets.showAppHeightNineSheet(
                                          context: context,
                                          widget: AddContactSheet(
                                              phone: widget.address));
                                    },
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100.0)),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 10.0, horizontal: 10),
                                    child: Icon(AppIcons.addcontact,
                                        size: 35,
                                        color: _addressCopied
                                            ? StateContainer.of(context)
                                                .curTheme
                                                .successDark
                                            : StateContainer.of(context)
                                                .curTheme
                                                .backgroundDark),
                                  )
                                : SizedBox(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // A row for View Details button
                Row(
                  children: <Widget>[
                    AppButton.buildAppButton(
                        context,
                        AppButtonType.PRIMARY_OUTLINE,
                        AppLocalization.of(context).viewDetails,
                        Dimens.BUTTON_BOTTOM_DIMENS, onPressed: () {
                      Navigator.of(context).push(
                          MaterialPageRoute(builder: (BuildContext context) {
                        return UIUtil.showBlockExplorerWebview(
                            context, widget.hash);
                      }));
                    }),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// This is used so that the elevation of the container is kept and the
/// drop shadow is not clipped.
///
class _SizeTransitionNoClip extends AnimatedWidget {
  final Widget child;

  const _SizeTransitionNoClip(
      {@required Animation<double> sizeFactor, this.child})
      : super(listenable: sizeFactor);

  @override
  Widget build(BuildContext context) {
    return new Align(
      alignment: const AlignmentDirectional(-1.0, -1.0),
      widthFactor: null,
      heightFactor: (this.listenable as Animation<double>).value,
      child: child,
    );
  }
}
