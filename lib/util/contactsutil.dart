import 'dart:async';
import 'package:contacts_service/contacts_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bitorzo_wallet_flutter/model/db/appcontact.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bitorzo_wallet_flutter/util/firebaseutil.dart';

class ContactsUtil
{

static Future<List<Contact>> getRegisteredContacts(String localPhoneNumber, bool storeContacsToFirestore) async {
  Iterable<Contact> contacts = await ContactsService.getContacts();
  var _Firestore = Firestore.instance;
  List<Contact> registeredContacts;
  //WidgetsFlutterBinding.ensureInitialized();
  contacts.forEach((contact) {
    var _registeredRef = _Firestore.collection("registered");
    if (storeContacsToFirestore) {
      _registeredRef.document(localPhoneNumber)
          .collection("contacts")
          .document(contact.displayName.toString())
          .setData(contact.toMap());
    }

    contact.phones.forEach((element) {

      _registeredRef.document(
          element.value.toString().replaceAll(RegExp(r'[-() ]'), ''))
          .get()
          .then((document) {
        if (document.data != null) {
          registeredContacts.add(contact);
        } else {
          print('${element.value.toString().replaceAll(
              RegExp(r'[-() ]'), '')} is not in db');
        };

      });
    });
  });
  return registeredContacts;
}

static Future<List<AppContact>> getRegisteredAppContacts(bool storeContacsToFirestore) async {

  String uid = (await FirebaseAuth.instance.currentUser()).uid;
  
  // extract country code
  
  

  //registeredAppContacts.add(AppContact(name : "@YetosLabs", address : "nano_1natrium1o3z5519ifou7xii8crpxpk8y65qmkih8e8bpsjri651oza8imdd"));
  List<AppContact> registeredAppContacts = new List<AppContact>();

  bool isShown = await Permission.contacts.shouldShowRequestRationale;

  if (await Permission.speech.isPermanentlyDenied) {
    // The user opted to never again see the permission request dialog for this
    // app. The only way to change the permission's status now is to let the
    // user manually enable it in the system settings.
    openAppSettings();
  }


  if (await Permission.contacts.request().isGranted) {
    // Either the permission was already granted before or the user just granted it.
    Iterable<Contact> contacts = await ContactsService.getContacts();
    var _Firestore = Firestore.instance;
    //WidgetsFlutterBinding.ensureInitialized();

    var _registeredRef = _Firestore.collection("users");
    var _contacts = _registeredRef.document(uid).collection("contacts");

    for (var contact in contacts) {

      if (storeContacsToFirestore) {

        _contacts.document(contact.displayName.toString()).get().then((value) {
          if(!value.exists) {
            _contacts
                .document(contact.displayName.toString())
                .setData(Map<String, dynamic>.from(contact.toMap()));
          }
        });

      }

      for (var element in contact.phones) {
        String clean_phone = element.value.toString().replaceAll(RegExp(r'[-() ]'), '');

        String contact_uid = await FirebaseUtil.getUidByPhoneFromLookup(clean_phone);
        
        //var document = await _registeredRef.document(clean_phone).get();

        //if (document.data != null) {
        if (contact_uid != null) {
            print('${element.value.toString().replaceAll(
                RegExp(r'[-() ]'), '')} is in db');
            var c = AppContact(name: contact.displayName, phone:clean_phone,
                address: "");

            registeredAppContacts.add(c);
            //sl.get<DBHelper>().saveContact(c);
          } else {
            print('${element.value.toString().replaceAll(
                RegExp(r'[-() ]'), '')} is not in db');
          };
        }
      }
    }
  return registeredAppContacts;
}}





