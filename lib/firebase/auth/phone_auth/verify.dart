import 'package:bitorzo_wallet_flutter/util/firebaseutil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bitorzo_wallet_flutter/model/available_language.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/providers/phone_auth.dart';
import 'package:bitorzo_wallet_flutter/ui/before_scan_screen.dart';
import 'package:bitorzo_wallet_flutter/ui/home_page.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_backup_confirm.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_backup_safety.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_backup_seed.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_import_seed.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_password.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_password_on_launch.dart';
import 'package:bitorzo_wallet_flutter/ui/intro/intro_welcome.dart';
import 'package:bitorzo_wallet_flutter/ui/lock_screen.dart';
import 'package:bitorzo_wallet_flutter/ui/password_lock_screen.dart';
import 'package:bitorzo_wallet_flutter/ui/util/routes.dart';
import 'package:bitorzo_wallet_flutter/utils/constants.dart';
import 'package:bitorzo_wallet_flutter/utils/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import '../../../service_locator.dart';
import '../../../appstate_container.dart';
import '../../../localization.dart';
import '../../../main.dart';
import '../../../styles.dart';

class PhoneAuthVerify extends StatefulWidget {
  /*
   *  cardBackgroundColor & logo values will be passed to the constructor
   *  here we access these params in the _PhoneAuthState using "widget"
   */
  //final Color cardBackgroundColor = Color(0xFFFCA967);
  final Color cardBackgroundColor = Color(0xFF6874C2);
  final String logo = Assets.firebase;
  final String appName = "Bitorzo";

  @override
  _PhoneAuthVerifyState createState() => _PhoneAuthVerifyState();
}

class _PhoneAuthVerifyState extends State<PhoneAuthVerify> {
  double _height, _width, _fixedPadding;

  FocusNode focusNode1 = FocusNode();
  FocusNode focusNode2 = FocusNode();
  FocusNode focusNode3 = FocusNode();
  FocusNode focusNode4 = FocusNode();
  FocusNode focusNode5 = FocusNode();
  FocusNode focusNode6 = FocusNode();
  String code = "";

  @override
  void initState() {
    super.initState();
  }

  final scaffoldKey =
  GlobalKey<ScaffoldState>(debugLabel: "scaffold-verify-phone");

  @override
  Widget build(BuildContext context) {
    //  Fetching height & width parameters from the MediaQuery
    //  _logoPadding will be a constant, scaling it according to device's size
    _height = MediaQuery.of(context).size.height;
    _width = MediaQuery.of(context).size.width;
    _fixedPadding = _height * 0.025;

    final phoneAuthDataProvider =
    Provider.of<PhoneAuthDataProvider>(context, listen: false);

    phoneAuthDataProvider.setMethods(
      onStarted: onStarted,
      onError: onError,
      onFailed: onFailed,
      onVerified: onVerified,
      onCodeResent: onCodeResent,
      onCodeSent: onCodeSent,
      onAutoRetrievalTimeout: onAutoRetrievalTimeOut,
    );

    /*
     *  Scaffold: Using a Scaffold widget as parent
     *  SafeArea: As a precaution - wrapping all child descendants in SafeArea, so that even notched phones won't loose data
     *  Center: As we are just having Card widget - making it to stay in Center would really look good
     *  SingleChildScrollView: There can be chances arising where
     */
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.white.withOpacity(0.95),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: _getBody(),
          ),
        ),
      ),
    );
  }

  /*
   *  Widget hierarchy ->
   *    Scaffold -> SafeArea -> Center -> SingleChildScrollView -> Card()
   *    Card -> FutureBuilder -> Column()
   */
  Widget _getBody() => Card(
        color: StateContainer.of(context).curTheme.backgroundDark,
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        child: SizedBox(
          height: _height * 8 / 10,
          width: _width * 8 / 10,
          child: _getColumnBody(),
        ),
      );

  Widget _getColumnBody() => Column(
        children: <Widget>[
          //  Logo: scaling to occupy 2 parts of 10 in the whole height of device
          Padding(
            padding: EdgeInsets.all(_fixedPadding),
            child:  PhoneAuthWidgets.getLogo(
                logoPath: widget.logo, height: _height * 0.2),

          ),

          // AppName:
          Text(widget.appName,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.0,
                  fontWeight: FontWeight.w700)),

          SizedBox(height: 20.0),

          //  Info text
          Row(
            children: <Widget>[
              SizedBox(width: 16.0),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: 'Please enter the ',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w400)),
                      TextSpan(
                          text: 'One Time Password',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700)),
                      TextSpan(
                        text: ' sent to your mobile',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16.0),
            ],
          ),

          SizedBox(height: 16.0),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              getPinField(key: "1", focusNode: focusNode1),
              SizedBox(width: 5.0),
              getPinField(key: "2", focusNode: focusNode2),
              SizedBox(width: 5.0),
              getPinField(key: "3", focusNode: focusNode3),
              SizedBox(width: 5.0),
              getPinField(key: "4", focusNode: focusNode4),
              SizedBox(width: 5.0),
              getPinField(key: "5", focusNode: focusNode5),
              SizedBox(width: 5.0),
              getPinField(key: "6", focusNode: focusNode6),
              SizedBox(width: 5.0),
            ],
          ),

          SizedBox(height: 32.0),

          RaisedButton(
            elevation: 16.0,
            onPressed: signIn,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'VERIFY',
                style: TextStyle(
                    color: StateContainer.of(context).curTheme.backgroundDark, fontSize: 18.0),
              ),
            ),
            //color: Colors.white,
            color: Colors.deepPurple,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0)),
          )
        ],
      );

  _showSnackBar(String text) {
    final snackBar = SnackBar(
      content: Text('$text'),
      duration: Duration(seconds: 2),
    );
//    if (mounted) Scaffold.of(context).showSnackBar(snackBar);
    scaffoldKey.currentState.showSnackBar(snackBar);
  }

  signIn() {
    if (code.length != 6) {
      _showSnackBar("Invalid OTP");
    }
    Provider.of<PhoneAuthDataProvider>(context, listen: false)
        .verifyOTPAndLogin(smsCode: code);
  }

  // This will return pin field - it accepts only single char
  Widget getPinField({String key, FocusNode focusNode}) => SizedBox(
        height: 40.0,
        width: 35.0,
        child: TextField(
          key: Key(key),
          expands: false,
//          autofocus: key.contains("1") ? true : false,
          autofocus: false,
          focusNode: focusNode,
          onChanged: (String value) {
            if (value.length == 1) {
              code += value;
              switch (code.length) {
                case 1:
                  FocusScope.of(context).requestFocus(focusNode2);
                  break;
                case 2:
                  FocusScope.of(context).requestFocus(focusNode3);
                  break;
                case 3:
                  FocusScope.of(context).requestFocus(focusNode4);
                  break;
                case 4:
                  FocusScope.of(context).requestFocus(focusNode5);
                  break;
                case 5:
                  FocusScope.of(context).requestFocus(focusNode6);
                  break;
                default:
                  FocusScope.of(context).requestFocus(FocusNode());
                  break;
              }
            }
          },
          maxLengthEnforced: false,
          textAlign: TextAlign.center,
          cursorColor: Colors.white,
          keyboardType: TextInputType.number,
          style: TextStyle(
              fontSize: 20.0, fontWeight: FontWeight.w600, color: Colors.deepPurple),
//          decoration: InputDecoration(
//              contentPadding: const EdgeInsets.only(
//                  bottom: 10.0, top: 10.0, left: 4.0, right: 4.0),
//              focusedBorder: OutlineInputBorder(
//                  borderRadius: BorderRadius.circular(5.0),
//                  borderSide:
//                      BorderSide(color: Colors.blueAccent, width: 2.25)),
//              border: OutlineInputBorder(
//                  borderRadius: BorderRadius.circular(5.0),
//                  borderSide: BorderSide(color: Colors.white))),
        ),
      );

  onStarted() {
    _showSnackBar("PhoneAuth started");
//    _showSnackBar(phoneAuthDataProvider.message);
  }

  onCodeSent() {
    _showSnackBar("OPT sent");
//    _showSnackBar(phoneAuthDataProvider.message);
  }

  onCodeResent() {
    _showSnackBar("OPT resent");
//    _showSnackBar(phoneAuthDataProvider.message);
  }

  onVerified() async {
    _showSnackBar(
        "${Provider
            .of<PhoneAuthDataProvider>(context, listen: false)
            .message}");

    String phone = Provider.of<PhoneAuthDataProvider>(context, listen: false).phone;

    // await sl.get<DBHelper>().saveMyNumber(phone);


    // Restart user's firebase records (maybe a new key will be imported/created)
    await FirebaseUtil.deleteUserData();


    await Future.delayed(Duration(seconds: 1));
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (BuildContext context) =>
        OKToast(
          textStyle: AppStyles.textStyleSnackbar(context),
          backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Bitorzo',
            theme: ThemeData(
              dialogBackgroundColor:
              StateContainer.of(context).curTheme.backgroundDark,
              primaryColor: StateContainer.of(context).curTheme.primary,
              accentColor: StateContainer.of(context).curTheme.primary10,
              backgroundColor: StateContainer.of(context).curTheme.backgroundDark,
              fontFamily: 'NunitoSans',
              brightness: Brightness.dark,
            ),
            localizationsDelegates: [
              AppLocalizationsDelegate(StateContainer.of(context).curLanguage),
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate
            ],
            locale: StateContainer.of(context).curLanguage == null || StateContainer.of(context).curLanguage.language == AvailableLanguage.DEFAULT
                ? null
                : StateContainer.of(context).curLanguage.getLocale(),
            supportedLocales: [
              const Locale('en', 'US'), // English
              const Locale('he', 'IL'), // Hebrew
              const Locale('de', 'DE'), // German
              const Locale('bg'), // Bulgarian
              const Locale('es'), // Spanish
              const Locale('hi'), // Hindi
              const Locale('hu'), // Hungarian
              const Locale('hi'), // Hindi
              const Locale('id'), // Indonesian
              const Locale('it'), // Italian
              const Locale('ja'), // Japanese
              const Locale('ko'), // Korean
              const Locale('ms'), // Malay
              const Locale('nl'), // Dutch
              const Locale('pl'), // Polish
              const Locale('pt'), // Portugese
              const Locale('ro'), // Romanian
              const Locale('ru'), // Russian
              const Locale('sl'), // Slovenian
              const Locale('sv'), // Swedish
              const Locale('tl'), // Tagalog
              const Locale('tr'), // Turkish
              const Locale('vi'), // Vietnamese
              const Locale.fromSubtags(
                  languageCode: 'zh', scriptCode: 'Hans'), // Chinese Simplified
              const Locale.fromSubtags(
                  languageCode: 'zh', scriptCode: 'Hant'), // Chinese Traditional
              const Locale('ar'), // Arabic
              const Locale('lv'), // Latvian
              // Currency-default requires country included
              const Locale("es", "AR"),
              const Locale("en", "AU"),
              const Locale("pt", "BR"),
              const Locale("en", "CA"),
              const Locale("de", "CH"),
              const Locale("es", "CL"),
              const Locale("zh", "CN"),
              const Locale("cs", "CZ"),
              const Locale("da", "DK"),
              const Locale("fr", "FR"),
              const Locale("en", "GB"),
              const Locale("zh", "HK"),
              const Locale("hu", "HU"),
              const Locale("id", "ID"),
              const Locale("he", "IL"),
              const Locale("hi", "IN"),
              const Locale("ja", "JP"),
              const Locale("ko", "KR"),
              const Locale("es", "MX"),
              const Locale("ta", "MY"),
              const Locale("en", "NZ"),
              const Locale("tl", "PH"),
              const Locale("ur", "PK"),
              const Locale("pl", "PL"),
              const Locale("ru", "RU"),
              const Locale("sv", "SE"),
              const Locale("zh", "SG"),
              const Locale("th", "TH"),
              const Locale("tr", "TR"),
              const Locale("en", "TW"),
              const Locale("es", "VE"),
              const Locale("en", "ZA"),
              const Locale("en", "US"),
              const Locale("es", "AR"),
              const Locale("de", "AT"),
              const Locale("fr", "BE"),
              const Locale("de", "BE"),
              const Locale("nl", "BE"),
              const Locale("tr", "CY"),
              const Locale("et", "EE"),
              const Locale("fi", "FI"),
              const Locale("fr", "FR"),
              const Locale("el", "GR"),
              const Locale("es", "AR"),
              const Locale("en", "IE"),
              const Locale("it", "IT"),
              const Locale("es", "AR"),
              const Locale("lv", "LV"),
              const Locale("lt", "LT"),
              const Locale("fr", "LU"),
              const Locale("en", "MT"),
              const Locale("nl", "NL"),
              const Locale("pt", "PT"),
              const Locale("sk", "SK"),
              const Locale("sl", "SI"),
              const Locale("es", "ES"),
              const Locale("ar", "AE"), // UAE
              const Locale("ar", "SA"), // Saudi Arabia
              const Locale("ar", "KW"), // Kuwait
            ],
            initialRoute: '/',
            onGenerateRoute: (RouteSettings settings) {
              switch (settings.name) {
                case '/':
                  return NoTransitionRoute(
                    builder: (_) => Splash(),
                    settings: settings,
                  );
                case '/home':
                  return NoTransitionRoute(
                    builder: (_) => AppHomePage(priceConversion: settings.arguments),
                    settings: settings,
                  );
                case '/home_transition':
                  return NoPopTransitionRoute(
                    builder: (_) => AppHomePage(priceConversion: settings.arguments),
                    settings: settings,
                  );
                case '/intro_welcome':
                  return NoTransitionRoute(
                    builder: (_) => IntroWelcomePage(),
                    settings: settings,
                  );
                case '/intro_password_on_launch':
                  return MaterialPageRoute(
                    builder: (_) => IntroPasswordOnLaunch(seed: settings.arguments),
                    settings: settings,
                  );
                case '/intro_password':
                  return MaterialPageRoute(
                    builder: (_) => IntroPassword(seed: settings.arguments),
                    settings: settings,
                  );
                case '/intro_backup':
                  return MaterialPageRoute(
                    builder: (_) => IntroBackupSeedPage(encryptedSeed: settings.arguments),
                    settings: settings,
                  );
                case '/intro_backup_safety':
                  return MaterialPageRoute(
                    builder: (_) => IntroBackupSafetyPage(),
                    settings: settings,
                  );
                case '/intro_backup_confirm':
                  return MaterialPageRoute(
                    builder: (_) => IntroBackupConfirm(),
                    settings: settings,
                  );
                case '/intro_import':
                  return MaterialPageRoute(
                    builder: (_) => IntroImportSeedPage(),
                    settings: settings,
                  );
                case '/lock_screen':
                  return NoTransitionRoute(
                    builder: (_) => AppLockScreen(),
                    settings: settings,
                  );
                case '/lock_screen_transition':
                  return MaterialPageRoute(
                    builder: (_) => AppLockScreen(),
                    settings: settings,
                  );
                case '/password_lock_screen':
                  return NoTransitionRoute(
                    builder: (_) => AppPasswordLockScreen(),
                    settings: settings,
                  );
                case '/before_scan_screen':
                  return NoTransitionRoute(
                    builder: (_) => BeforeScanScreen(),
                    settings: settings,
                  );
                default:
                  return null;
              }
            },
          ),
        )
    ));
  }

  onFailed() async{
    _showSnackBar("PhoneAuth failed");
  }

  onError() {
//    _showSnackBar(phoneAuthDataProvider.message);
    _showSnackBar(
        "PhoneAuth error ${Provider
            .of<PhoneAuthDataProvider>(context, listen: false)
            .message}");
  }

  onAutoRetrievalTimeOut() {
    _showSnackBar("PhoneAuth autoretrieval timeout");
//    _showSnackBar(phoneAuthDataProvider.message);
  }
}
