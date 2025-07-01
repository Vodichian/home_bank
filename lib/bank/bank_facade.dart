import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';

import '../models/pending_transaction.dart' as pt;
import '../utils/globals.dart';

class BankFacade extends ChangeNotifier {
  /// Server's address, i.e 'localhost' or '192.168.1.1'
  final String address; // Added variable 'test'
  final BankClient _client = BankClient();

  User? _currentUser;

  BankFacade({this.address = '192.168.1.40'});

  User? get currentUser => _currentUser;

  // BankFacade({this.address = 'localhost'});

  Future<void> initialize() async {
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
    } else if (!_currentUser!.isAdmin) {
      throw AuthenticationError('An admin is required to delete a user');
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

  /// Authenticates credentials as an admin, returning the user if successful.
  ///
  /// Throws [AuthenticationError] on failure
  Future<User> authenticateAdmin(String username, String password) async {
    User user = await _client.login(username, password);
    if (user.isAdmin) {
      return user;
    } else {
      throw AuthenticationError('User is not an admin');
    }
  }

  Stream<List<User>> users() {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return _client.users(_currentUser!);
  }

  Future<void> disconnect() async {
    await _client.disconnect();
  }

  /// Retrieves the [SavingsAccount] of the currently logged in user.
  Future<SavingsAccount> getSavings() async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.getSavingsAccountByOwner(_currentUser!);
  }

  /// Listens for real-time updates to the SavingsAccount of the currently logged-in user.
  ///
  /// Emits new [SavingsAccount] states whenever changes occur on the server.
  /// Throws [AuthenticationError] if the user is not logged in.
  Stream<SavingsAccount> listenSavingsAccount() {
    if (_currentUser == null) {
      // Option 1: Throw immediately if not logged in
      throw AuthenticationError(
          'User is not logged in to listen to savings account.');
      // Option 2: Return an error stream
      // return Stream.error(AuthenticationError('User is not logged in to listen to savings account.'));
    }
    // Assuming the user is always listening to their OWN savings account.
    // If an admin could listen to others, you'd need to pass ownerUserId.
    // This is a definite possibility down the road.
    return _client.listenSavingsAccount(_currentUser!, _currentUser!.userId);
  }

  Future<Merchant> getMerchant(int accountNumber) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.getMerchant(accountNumber, _currentUser!);
  }

  Future<List<Merchant>> getMerchants() async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.getMerchants(_currentUser!);
  }

  Stream<List<Merchant>> merchants() {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return _client.merchants(_currentUser!);
  }

  Stream<List<BankTransaction>> transactions() {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return _client.transactions(_currentUser!);
  }

  /// Converts a [PendingTransaction] to a [BankTransaction].
  Future<BankTransaction> _convertPendingToBankTransaction(
      pt.PendingTransaction pendingTx, User adminUser) async {
    // 1. Determine the initiatingUser (sourceUser for most operations)
    User initiatingUser;
    if (_currentUser != null &&
        _currentUser!.userId == pendingTx.initiatingUserId) {
      initiatingUser = _currentUser!;
    } else {
      try {
        logger.d(
            "Fetching initiating user (ID: ${pendingTx.initiatingUserId}) for transaction conversion, authorized by admin: ${adminUser.username}");
        initiatingUser =
            await _client.getUser(pendingTx.initiatingUserId, adminUser);
      } catch (e) {
        logger.e(
            "Failed to fetch initiating user (ID: ${pendingTx.initiatingUserId}): $e");
        throw StateError(
            "Could not retrieve initiating user details for transaction. ${e.toString()}");
      }
    }

    // 2. Use the appropriate BankTransaction factory based on pendingTx.type
    switch (pendingTx.type) {
      case pt.PendingTransactionType.addFunds:
        // For addFunds, the 'sourceUser' in BankTransaction is the user whose account is being credited.
        // The 'authUser' in BankTransaction.addFunds factory is the admin performing the action.
        return BankTransaction.addFunds(
          sourceUser: initiatingUser, // User whose account is being funded
          amount: pendingTx.amount,
          authUser:
              adminUser, // Admin authorizing/performing the direct fund addition
        );

      case pt.PendingTransactionType.withdrawal:
        // 'authUser' in BankTransaction.withdrawal is the admin authorizing.
        return BankTransaction.withdrawal(
          sourceUser: initiatingUser,
          // User from whose account funds are withdrawn
          amount: pendingTx.amount,
          authUser: adminUser, // Admin authorizing the withdrawal
        );

      case pt.PendingTransactionType.transfer:
        if (pendingTx.recipientUserId == null) {
          throw ArgumentError(
              "Recipient user ID cannot be null for a transfer.");
        }
        // Fetch the targetUser for the transfer
        User targetUser;
        try {
          logger.d(
              "Fetching target user (ID: ${pendingTx.recipientUserId}) for transfer, authorized by admin: ${adminUser.username}");
          targetUser =
              await _client.getUser(pendingTx.recipientUserId!, adminUser);
        } catch (e) {
          logger.e(
              "Failed to fetch target user (ID: ${pendingTx.recipientUserId}): $e");
          throw StateError(
              "Could not retrieve target user details for transfer. ${e.toString()}");
        }
        return BankTransaction.transfer(
          sourceUser: initiatingUser, // User sending the funds
          amount: pendingTx.amount,
          targetUser: targetUser, // User receiving the funds
        );

      case pt.PendingTransactionType.payment:
        if (pendingTx.merchantId == null) {
          throw ArgumentError("Merchant ID cannot be null for a payment.");
        }
        // Fetch the Merchant object
        Merchant targetMerchant;
        try {
          logger.d(
              "Fetching merchant (ID: ${pendingTx.merchantId}) for payment, authorized by admin: ${adminUser.username}");
          // Pass adminUser as the authUser for getMerchant, assuming it's required
          targetMerchant =
              await _client.getMerchant(pendingTx.merchantId!, adminUser);
        } catch (e) {
          logger
              .e("Failed to fetch merchant (ID: ${pendingTx.merchantId}): $e");
          throw StateError(
              "Could not retrieve merchant details for payment. ${e.toString()}");
        }
        return BankTransaction.payment(
          sourceUser: initiatingUser, // User making the payment
          amount: pendingTx.amount,
          merchant: targetMerchant, // Merchant receiving the payment
        );
    }
  }

  Future<BankTransaction> processTransaction(
      pt.PendingTransaction pendingTx, User adminUser) async {
    if (_currentUser == null &&
        pendingTx.initiatingUserId != adminUser.userId) {
      logger.w(
          'BankFacade.processTransaction: _currentUser is null. Admin ${adminUser.username} is processing for user ${pendingTx.initiatingUserId}.');
    } else if (_currentUser != null &&
        pendingTx.initiatingUserId != _currentUser!.userId) {
      logger.w(
          'BankFacade.processTransaction: Initiating user (${pendingTx.initiatingUserId}) is different from current user (${_currentUser!.username}). Admin: ${adminUser.username}.');
    }

    try {
      // 1. Convert PendingTransaction to BankTransaction
      logger.i(
          "Converting PendingTransaction (ID: ${pendingTx.id}, Type: ${pendingTx.type}) to BankTransaction, authorized by ${adminUser.username}");
      BankTransaction bankTransactionToSubmit =
          await _convertPendingToBankTransaction(pendingTx, adminUser);

      logger.i(
          "Submitting BankTransaction (Type: ${bankTransactionToSubmit.transactionType}, Amount: ${bankTransactionToSubmit.amount}) for PendingTx ID: ${pendingTx.id}, UserID: ${bankTransactionToSubmit.sourceUser.userId}, Admin: ${adminUser.username}");

      // 2. Submit the BankTransaction using BankClient's submit method
      // The submit method returns the transaction ID assigned by the server.
      int newTransactionId =
          await _client.submit(bankTransactionToSubmit, adminUser);

      logger.i(
          "BankTransaction submitted successfully. Server assigned ID: $newTransactionId for PendingTx ID: ${pendingTx.id}");

      // 3. Return the submitted BankTransaction (or fetch it by new ID for confirmation)
      // For simplicity, we'll update the ID of our local object and return it.
      // Ideally, the server's response for `submit` might return the full BankTransaction DTO.
      // If `_client.submit` only returns an ID, you might want to call `_client.getBankTransaction(newTransactionId, adminUser)`
      // to get the complete, persisted transaction details.
      // For now, let's assume we can create a representative BankTransaction object or just use the ID.
      // Let's return the original object with the ID updated, and server-set fields like timestamp might differ.

      // To provide the most accurate BankTransaction object back, it's best to fetch it.
      // This ensures all server-set fields (like actual timestamp, balanceAfter, server-assigned ID) are correct.
      return await _client.getBankTransaction(newTransactionId, adminUser);
    } on BankError catch (e) {
      logger.e(
          'BankFacade.processTransaction: BankError for PendingTx ID ${pendingTx.id} (Type: ${pendingTx.type}) - ${e.message}');
      rethrow;
    } on ArgumentError catch (e) {
      // Catch validation errors from _convertPendingToBankTransaction
      logger.e(
          'BankFacade.processTransaction: ArgumentError for PendingTx ID ${pendingTx.id} (Type: ${pendingTx.type}) - ${e.message}');
      throw StateError(
          "Transaction data is invalid: ${e.message}"); // Convert to StateError for UI
    } catch (e) {
      logger.e(
          'BankFacade.processTransaction: Generic error for PendingTx ID ${pendingTx.id} (Type: ${pendingTx.type}) - $e');
      rethrow;
    }
  }

  Future<void> updateMerchant(Merchant updatedMerchant) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    } else if (!_currentUser!.isAdmin) {
      throw AuthenticationError('An admin is required to update a merchant');
    }
    throw StateError("Not implemented");
    // await _client.updateMerchant(updatedMerchant, _currentUser!);
  }

  Future<void> createMerchant(
    String name,
    String description,
  ) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    } else if (!_currentUser!.isAdmin) {
      throw AuthenticationError('An admin is required to create a merchant');
    }
    Merchant merchant = Merchant(name: name, description: description);
    await _client.addMerchant(merchant, _currentUser!);
  }

  Future<void> deleteMerchant(Merchant merchantToDelete) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    } else if (!_currentUser!.isAdmin) {
      throw AuthenticationError('An admin is required to delete a merchant');
    }
    await _client.removeMerchant(merchantToDelete, _currentUser!);
  }
}
