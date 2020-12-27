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
          Firestore.instance.collection("users").document(uid).collection("receive_publickeys_used").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );
          Firestore.instance.collection("users").document(uid).collection("receive_publickeys_unused").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );
          Firestore.instance.collection("users").document(uid).collection("change_publickeys_used").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );

          Firestore.instance.collection("users").document(uid).collection("change_publickeys_unused").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );

          Firestore.instance.collection("users").document(uid).collection("pending_requests").getDocuments().then((value) =>
              value.documents.forEach((element) {element.reference.delete();})
          );

          Firestore.instance.collection("users").document(uid).delete();
          sl.get<Logger>().d(uid + " has just been deleted");
        });
      }
    });
  }



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

  static Future<int> getNumUsedReceivePublicKeys() async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(uid).collection("receive_publickeys_used");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }

  static Future<int> getNumUnusedReceivePublicKeys() async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("receive_publickeys_unused");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }

  static Future<int> getNumPendingRequests() async
  {
    var _Firestore = Firestore.instance;
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    var _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("pending_requests");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }

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


  static Future<int> getNumUnusedChangePublicKeys() async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("change_publickeys_unused");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }

  static Future<int> getNumUsedChangePublicKeys() async
  {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("change_publickeys_used");
    return (await _localRecAddrRef.getDocuments())?.documents.length ?? 0;
  }
  /* Deprecated
  static Future<int> getLastChangePublicKeyId(String localPhoneNumber) async
  {
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(
        localPhoneNumber).collection("change_publickeys");
    var docs = await _localRecAddrRef.getDocuments();
    int max_key_id = -1;

    for (var doc in docs.documents) {
      int id = int.parse(doc.documentID);
      if (id > max_key_id) {
        max_key_id = id;
      }
    }
    return max_key_id;
  }


  static Future<int> getLastRecievePublicKeyId(String localPhoneNumber) async
  {
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(
        localPhoneNumber).collection("receive_publickeys");
    var docs = await _localRecAddrRef.getDocuments();
    int max_key_id = -1;

    for (var doc in docs.documents) {
      int id = int.parse(doc.documentID);
      if (id > max_key_id) {
        max_key_id = id;
      }
    }
    return max_key_id;
  }

   */

  static Future<void> markContactPublicAddressAsUsed(String uid, String unused_publickey) async {

    /*
    String uid = await getUidByPhoneFromLookup(contactPhoneNumber);
    if(uid == null) {
      return;
    }
    */

    var _Firestore = Firestore.instance;
    CollectionReference _localRecAddrRef = _Firestore.collection("users").document(uid).collection("receive_publickeys_unused");
    // Remove from used

    await Firestore.instance.runTransaction((Transaction myTransaction) async {
      await myTransaction.delete(_localRecAddrRef.document(unused_publickey));
    });

    //await _localRecAddrRef.document(unused_publickey).delete();
    // Move to used
    _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("receive_publickeys_used");

    await _localRecAddrRef.document(unused_publickey).setData({"hab": true});

  }

  static Future<String> getLocalUnusedPublicAddress({bool markUsed : false}) async {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    return getContactUnusedPublicAddressByUid(uid, markUsed:markUsed);
  }


  static Future<String> getContactUnusedPublicAddress(String phone, {bool markUsed : false}) async {
    String uid = await getUidByPhoneFromLookup(phone);
    if(uid == null) {
      return null;
    }
    return getContactUnusedPublicAddressByUid(uid, markUsed:markUsed);
  }


  static Future<String> getContactUnusedPublicAddressByUid(String uid, {bool markUsed : false}) async {

    var _Firestore = Firestore.instance;
    CollectionReference _localRecAddrRef = _Firestore.collection("users").document(uid).collection("receive_publickeys_unused");
    var docs = (await _localRecAddrRef.getDocuments()).documents;

    if(docs.length == 0) {
      throw("No available public key for contact!");
    }
    String unused_publickey = docs[0].documentID;

    if (markUsed) {
      markContactPublicAddressAsUsed(uid, unused_publickey);
    }

    return unused_publickey;
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

  static Future<void> addUserRecievePublicKeys(List<String> pks) async {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    var _Firestore = Firestore.instance;

    var _localRecAddrRef = _Firestore.collection("users").document(uid);
    _localRecAddrRef.setData({'hab' : true}, merge:true);

    var _localRecAddrRef1 = _localRecAddrRef.collection("receive_publickeys_unused");

    pks.forEach((value) {
      _localRecAddrRef1
          .document(value)
          .setData({'hab' : true});
    });


    /*


    var _localRecAddrRef = _Firestore.collection("users").document(localPhoneNumber);
    _localRecAddrRef.setData({'hab' : true});

    var _localRecAddrRef1 = _localRecAddrRef.collection("receive_publickeys_unused");

    pks.forEach((value) {
      _localRecAddrRef1
          .document(value)
          .setData({'hab' : true});
    });

     */
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

  static Future<void> addUserChangePublicKeys(
      List<String> pks) async {

    var _Firestore = Firestore.instance;
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    var _localRecAddrRef = _Firestore.collection("users").document(uid);
    _localRecAddrRef.setData({'hab' : true}, merge:true);

    var _localRecAddrRef1 = _localRecAddrRef.collection("change_publickeys_unused");

    pks.forEach((value) {
      _localRecAddrRef1
          .document(value)
          .setData({'hab':true});
    });

  }

  static Future<void> markChangeAddressAsUsed(String unused_changekey) async {
    var _Firestore = Firestore.instance;
    String uid = (await FirebaseAuth.instance.currentUser()).uid;

    CollectionReference _localRecAddrRef = _Firestore.collection("users").document(uid).collection("change_publickeys_unused");

    // Remove from used
    await _localRecAddrRef.document(unused_changekey).delete();

    // Move to unused
    _localRecAddrRef = _Firestore.collection("users").document(
        uid).collection("change_publickeys_used");

    await _localRecAddrRef.document(unused_changekey).setData({"hab": true});
  }

  static Future<String> getUnusedChangeAddress({bool markUsed : true}) async {
    String uid = (await FirebaseAuth.instance.currentUser()).uid;
    var _Firestore = Firestore.instance;
    var _localRecAddrRef = _Firestore.collection("users").document(uid).collection("change_publickeys_unused");
    var docs = (await _localRecAddrRef.getDocuments()).documents;

    if(docs.length == 0) {
      throw("No available change key!");
    }

    var change_key = docs[0].documentID;

    if(markUsed) {
      markChangeAddressAsUsed(change_key);
    }

    return change_key;
  }

  static Future<AppContact> getContactWhosAdressBelongsTo(List<AppContact> contacts, String pubKey) async
  {
    return null;
    // No permissions to do that, to intrusive.
  }

}