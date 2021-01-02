import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';
import 'package:random_string/random_string.dart';
import '../service_locator.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bitorzo_wallet_flutter/data_models/country.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class FirebaseUtil {
  final Logger log = sl.get<Logger>();

  static Future<void> deleteUserData() async {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    sl.get<Logger>().d(uid.toString() + " is going to be deleted!");
    Firestore.instance.collection("users").document(uid).get().then((doc) {
      if(doc != null && doc.exists) {


        Firestore.instance.collection("users_backups").document(uid).setData(doc.data).then((hab) {

          // deletes the old document

          Firestore.instance.collection("users").document(uid).collection("pending_requests").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );

          Firestore.instance.collection("users").document(uid).delete();
          sl.get<Logger>().d(uid + " has just been deleted");
        });
      }
    });
  }

  /*
  static Future<void> addPendingRequest(String remotePhoneNumber, int amount, String tx_data) async
  {

    String localPhoneNumber = (await FirebaseAuth.instance.currentUser()).phoneNumber;
    String uid = await getUidByPhoneFromLookup(remotePhoneNumber);
    if(uid == null) {
      return;
    }

    var _Firestore = Firestore.instance;
    _Firestore.collection("users").document(
        uid).collection("pending_requests").document()
        .setData({"amount" : amount, "sender": localPhoneNumber, "tx_data": tx_data});

    // return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }
  */
  /*
  static Future<int> getNumPendingRequests() async
  {
    var _Firestore = Firestore.instance;
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    var _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("pending_requests");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }
  */
  static Future<Stream<QuerySnapshot>> getPendingRequestsStream() async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    return Firestore.instance.collection('users').document(uid).collection('pending_requests').snapshots();
  }

  static Future<void> setPendingRequestStatus(String reqDocId, {confirmed : true}) async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    var pendingReqDoc = await Firestore.instance.collection('users')
        .document(uid)
        .collection('pending_requests')
        .document(reqDocId).get();

    if(confirmed) {
      Firestore.instance.collection('users')
          .document(uid)
          .collection('confirmed_requests')
          .document(reqDocId).setData(pendingReqDoc.data);
    } else {
      Firestore.instance.collection('users')
          .document(uid)
          .collection('denied_requests')
          .document(reqDocId).setData(pendingReqDoc.data);
    }

    // Delete pending request
    await Firestore.instance.collection('users')
        .document(uid)
        .collection('pending_requests')
        .document(reqDocId).delete();

  }


  static Future<bool> isContactAppUser(String contactPhoneNumber) async {

    String uid = await getUidByPhoneFromLookup(contactPhoneNumber);
    if(uid == null) {
      return false;
    }

    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(uid);

    var doc = await _localRecAddrRef.get();
    return doc.exists;
  }

  static Future<String> getUidByPhoneFromLookup(String phoneNum) async {

    // Get users country code first
    String local_phone_number = (await FirebaseAuth.instance.currentUser()).phoneNumber;

    if(!phoneNum.startsWith("+")) {
      var _file = await rootBundle.loadString('data/country_phone_codes.json');
      var _countriesJson = json.decode(_file);
      Country country;
      for (var c in _countriesJson) {
        country = Country.fromJson(c);
        if (local_phone_number.startsWith(country.dialCode)) {
          break;
        }
      }

      if(phoneNum.startsWith("0")) {
        // Add local country with chuncked number
        phoneNum = country.dialCode + phoneNum.substring(1);
      }
    }

    var uids = await Firestore.instance.collection('lookup_by_phone').document(phoneNum).collection("uids").getDocuments();

    if(uids.documents.length == 0 ) {
      return null;
    }

    // Get first UID
    return uids?.documents[0]?.documentID ?? null;

  }

  static Future<void> addUidPhonePairToLookupTable() async {

    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    String phone = (await FirebaseAuth.instance.currentUser()).phoneNumber;

    var _Firestore = Firestore.instance;


    var _localRecAddrRef = _Firestore.collection("lookup_by_phone").document(phone);

    if((await _localRecAddrRef.get()).exists) {
      // Mapping already exists (can't update by rule)
      return;
    }

    _localRecAddrRef.setData({'uid' : uid});

    _localRecAddrRef = _Firestore.collection("lookup_by_phone").document(phone).collection("uids").document(uid);
    _localRecAddrRef.setData({'uid' : uid});

  }

  static Future<AppContact> getContactWhosAdressBelongsTo(List<AppContact> contacts, String pubKey) async
  {
    return null;
    // No permissions to do that, to intrusive.
  }

}