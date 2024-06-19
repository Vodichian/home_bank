import 'package:flutter/material.dart';
import 'package:home_bank/bank/user.dart';

class Bank extends ChangeNotifier {
  final String test; // Added variable 'test'
  final _users = [];

  // final _users = [
  //   User(fullName: "Victoria Tran-McDonald", userId: 1, username: 'Tori'),
  //   User(fullName: "Willben Tran-McDonald", userId: 2, username: 'Will')
  // ];

  Bank({required this.test}); // TODO: Remove this test property

  List<User> users() {
    return List.from(_users);
  }

  bool hasUsername(String username) {
    return _users.any((user) => user.username == username);
  }

  User createUser(String fullName, String username, String? imagePath) {
    String failMessage = _validate(fullName, username);
    if (failMessage.isEmpty) {
      var userId = _generateId();
      User newUser =
          User(fullName: fullName, userId: userId, username: username);
      _users.add(newUser);
      return newUser;
    } else {
      throw Exception(failMessage);
    }
  }

  String _validate(String fullName, String username) {
    if (fullName.isEmpty) {
      return 'Full name is a required field';
    }
    if (username.isEmpty) {
      return 'Username is a required field';
    }
    if (hasUsername(username)) {
      return 'Username $username is already taken';
    }
    return '';
  }

  /// Generates a unique ID
  ///
  /// This simply returns the incremented value of the largest existing
  /// userId
  int _generateId() {
    if (_users.isEmpty) {
      return 1; // start with 1
    }
    int largestId = _users[0].userId;
    for (final user in _users) {
      if (user.userId > largestId) {
        largestId = user.userId;
      }
    }
    return largestId + 1;
  }
}
