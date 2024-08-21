import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';


class BankFacade extends ChangeNotifier {
  /// Server's address, i.e 'localhost' or '192.168.1.1'
  final String address; // Added variable 'test'
  final BankClient _client = BankClient();

  User? _currentUser;

  BankFacade({this.address = 'localhost'});

  initialize() async {
    await _client.connect(address: address);
  }

  Future<List<User>> getUsers() {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return _client.getUsers(_currentUser!);
  }

  Future<bool> hasUsername(String username) async {
    return await _client.usernameExists(username);
  }

  /// Create a new [User]. The [id] of the newly created user is returned, or
  /// an exception on failure.
  Future<int> createUser(String username, String password) async {
    String failMessage = await _validate(username, password);
    if (failMessage.isEmpty) {
      int id = await _client.createUser(username, password);
      return id;
    } else {
      throw Exception(failMessage);
    }
  }

  Future<bool> deleteUser(User user) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.deleteUser(user, _currentUser!);
  }

  Future<String> _validate(String username, String password) async {
    if (password.isEmpty) {
      return 'Password is a required field';
    }
    if (username.isEmpty) {
      return 'Username is a required field';
    }
    if (await hasUsername(username)) {
      return 'Username $username is already taken';
    }
    return '';
  }

  /// Logins into to the system.
  ///
  /// Throws [AuthenticationError] on failure
  Future<void> login(String username, String password) async {
    _currentUser = await _client.login(username, password);
  }

  Stream<List<User>> users() {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return _client.users(_currentUser!);
  }
}
