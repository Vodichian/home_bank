import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';


class BankFacade extends ChangeNotifier {
  final String test; // Added variable 'test'
  final BankClient _client = BankClient();

  User? _currentUser;

  BankFacade({required this.test}); // TODO: Remove this test property

  initialize() async {
    await _client.connect();
  }

  Future<List<User>> getUsers() {
    if (_currentUser == null) {
      throw AuthenticationError('Authenticated user is required');
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
      throw AuthenticationError('Authenticated user is required');
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

  Stream<List<User>> users() {
    if (_currentUser == null) {
      throw AuthenticationError('Authenticated user is required');
    }
    return _client.users(_currentUser!);
  }
}
