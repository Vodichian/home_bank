import 'package:flutter/material.dart';
import 'package:home_bank/bank/user.dart';


class Bank extends ChangeNotifier {
  final String test; // Added variable 'test'
  final _users = [
    User(fullName: "Victoria Tran-McDonald", userId: "1"),
    User(fullName: "Willben Tran-McDonald", userId: "2")
  ];

  Bank({required this.test}); // TODO: Remove this test property

  List<User> users() {
    return List.from(_users);
  }
}