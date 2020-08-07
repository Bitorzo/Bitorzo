import 'package:flutter/material.dart';
import 'package:bitorzo_wallet_flutter/model/db/appdb.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';
import 'package:bitorzo_wallet_flutter/src/models/credit_card_model.dart';
import 'package:bitorzo_wallet_flutter/src/models/payment_model.dart';
import 'package:bitorzo_wallet_flutter/src/models/user_model.dart';
import 'package:bitorzo_wallet_flutter/service_locator.dart';

List<CreditCardModel> getCreditCards()  {
  List<CreditCardModel> creditCards = [];
  creditCards.add(CreditCardModel(
      "4616900007729988",
      "https://resources.mynewsdesk.com/image/upload/ojf8ed4taaxccncp6pcp.png",
      "06/23",
      "192"));
  creditCards.add(CreditCardModel(
      "3015788947523652",
      "https://resources.mynewsdesk.com/image/upload/ojf8ed4taaxccncp6pcp.png",
      "04/25",
      "217"));
  return creditCards;
}

Future<List<UserModel>> getUsersCard() async {

  List<UserModel> userCards = [];

  for (var contact in await sl.get<DBHelper>().getContacts()) {
    userCards.add(UserModel(contact,  "../assets/users/gillian.jpeg"));
  }


  return userCards;
}

List<PaymentModel> getPaymentsCard() {
  List<PaymentModel> paymentCards = [


  ];

  return paymentCards;
}
