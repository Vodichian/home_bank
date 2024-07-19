import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';

class BankFacade extends ChangeNotifier {
  final String test; // Added variable 'test'
  // final _users = [];
  BankClient client = BankClient();

  // final _users = [
  //   User(fullName: "Victoria Tran-McDonald", userId: 1, username: 'Tori'),
  //   User(fullName: "Willben Tran-McDonald", userId: 2, username: 'Will')
  // ];

  BankFacade({required this.test}); // TODO: Remove this test property

  initialize() async {
    await client.connect();
  }

  Future<List<User>> users() {
    return client.getUsers();
  }

  Future<bool> hasUsername(String username) async {
    List<User> userList = await users();
    return userList.any((user) => user.username == username);
  }

  Future<User> createUser(String fullName, String username, String? imagePath) async {
    String failMessage = await _validate(fullName, username);
    if (failMessage.isEmpty) {
      // var userId = _generateId();
      User newUser =
          User(fullName: fullName, userId: 0, username: username);
      client.createUser(newUser);
      return newUser;
    } else {
      throw Exception(failMessage);
    }
  }

  Future<String> _validate(String fullName, String username) async {
    if (fullName.isEmpty) {
      return 'Full name is a required field';
    }
    if (username.isEmpty) {
      return 'Username is a required field';
    }
    if (await hasUsername(username)) {
      return 'Username $username is already taken';
    }
    return '';
  }

  /// Generates a unique ID
  ///
  /// This simply returns the incremented value of the largest existing
  /// userId
  // int _generateId() {
  //   if (_users.isEmpty) {
  //     return 1; // start with 1
  //   }
  //   int largestId = _users[0].userId;
  //   for (final user in _users) {
  //     if (user.userId > largestId) {
  //       largestId = user.userId;
  //     }
  //   }
  //   return largestId + 1;
  // }
}
