import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';

class BankFacade extends ChangeNotifier {
  final String test; // Added variable 'test'
  final BankClient _client = BankClient();

  BankFacade({required this.test}); // TODO: Remove this test property

  initialize() async {
    await _client.connect();
  }

  Future<List<User>> getUsers() {
    return _client.getUsers();
  }

  Future<bool> hasUsername(String username) async {
    List<User> userList = await getUsers();
    return userList.any((user) => user.username == username);
  }

  /// Create a new [User]. The [id] of the newly created user is returned, or
  /// an exception on failure.
  Future<int> createUser(
      String fullName, String username, String? imagePath) async {
    String failMessage = await _validate(fullName, username);
    if (failMessage.isEmpty) {
      User newUser = User(fullName: fullName, userId: 0, username: username);
      int id = await _client.createUser(newUser);
      return id;
    } else {
      throw Exception(failMessage);
    }
  }

  Future<bool> deleteUser(User user) async {
    return await _client.deleteUser(user);
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

  Stream<List<User>> users() {
    return _client.users();
  }
}
