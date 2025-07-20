import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_transaction.dart' as pt;
import '../utils/globals.dart';
import '../config/server_definitions.dart';

class BankFacade extends ChangeNotifier {
  final BankClient _client = BankClient();

  User? _currentUser;
  ServerConfig _currentServerConfig;
  static const String _lastServerTypeKey = 'last_server_type';

  // Private constructor for internal use with factory
  BankFacade._(this._currentServerConfig);

  // Factory constructor to initialize asynchronously
  static Future<BankFacade> create() async {
    final prefs = await SharedPreferences.getInstance();
    final lastServerTypeName = prefs.getString(_lastServerTypeKey);
    ServerType initialServerType = ServerType.test; // Default to test

    if (lastServerTypeName == ServerType.live.name) {
      initialServerType = ServerType.live;
    }
    // No need to explicitly check for test, as it's the default

    final initialConfig = initialServerType == ServerType.live
        ? liveServerConfig
        : testServerConfig;
    return BankFacade._(initialConfig);
  }

  User? get currentUser => _currentUser;

  ServerConfig get currentServerConfig => _currentServerConfig;

  bool get isConnected => _client.isConnected;

  Future<void> initialize() async {
    if (isConnected) {
      await _client
          .disconnect(); // Disconnect if already connected (e.g., after a switch)
    }
    _currentUser = null; // Clear user on new connection/re-initialization
    logger.i(
        "Attempting to connect to: ${_currentServerConfig.name} (${_currentServerConfig.address})");
    try {
      await _client.connect(address: _currentServerConfig.address);
      logger.i("Successfully connected to: ${_currentServerConfig.name}");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastServerTypeKey, _currentServerConfig.type.name);
    } catch (e) {
      logger.e("Failed to connect to ${_currentServerConfig.name}: $e");
      rethrow; // Propagate error for UI to handle
    }
    notifyListeners(); // Notify about connection state change (and currentUser reset)
  }

  Future<void> switchServer(ServerType serverType) async {
    if (_currentServerConfig.type == serverType) {
      logger.i("Already on ${serverType.name}. No switch needed.");
      if (!isConnected) {
        // If on the correct server but not connected, try to connect
        await initialize();
      }
      return;
    }

    logger.i("Switching to ${serverType.name} server...");
    if (isConnected) {
      await disconnect(); // Gracefully disconnect from the current server
    }

    _currentServerConfig =
        (serverType == ServerType.live) ? liveServerConfig : testServerConfig;
    _currentUser = null; // Clear user session when switching servers
    notifyListeners(); // Notify about config change immediately

    await initialize(); // Attempt to connect to the new server
  }

  // --- Login needs to be aware of connection state ---
  Future<void> login(String username, String password) async {
    if (!isConnected) {
      // Attempt to initialize/connect if not connected.
      // This could happen if the app starts, tries to connect to last server, fails,
      // and user then tries to log in.
      logger.w("Login attempt while disconnected. Trying to connect first...");
      try {
        await initialize(); // This will use _currentServerConfig
      } catch (e) {
        logger.e("Connection failed during login attempt: $e");
        throw AuthenticationError(
            'Connection failed. Please check server status or switch servers.');
      }
    }
    // Proceed with login if connection is now established
    _currentUser = await _client.login(username, password);
    notifyListeners();
  }

  /// Logs out the current user by clearing their session locally.
  /// Does not disconnect from the server.
  Future<void> logout() async {
    logger.i(
        "BankFacade: Logging out user ${_currentUser?.username ?? 'N/A'}. Connection will remain active.");
    _currentUser = null;
    notifyListeners(); // Crucial for GoRouter and UI updates
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

  /// Retrieves a [User] by their ID.
  ///
  /// Throws [AuthenticationError] if the user is not logged in.
  Future<User> getUser(int userId) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.getUser(userId, _currentUser!);
  }

  /// Updates an existing [User].
  ///
  /// Throws [AuthenticationError] if the user is not logged in.
  /// Throws [AuthenticationError] if the user does not have permission to
  /// update the specified user.
  Future<int> updateUser(User updatedUser) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    }
    return await _client.saveUser(updatedUser, _currentUser!);
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

  /// Disconnects from the server and clears the current user session.
  Future<void> disconnect() async {
    if (isConnected) {
      logger.i(
          "BankFacade: Disconnecting from server ${_currentServerConfig.name}...");
      await _client.disconnect();
      logger.i("BankFacade: Successfully disconnected from server.");
    } else {
      logger.i("BankFacade: disconnect() called, but already disconnected.");
    }
    _currentUser = null; // Also clear user on full disconnect
    notifyListeners(); // Notify about connection and auth state change
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

  /// Listens for real-time updates to transactions based on specified query parameters.
  ///
  /// This method uses the currently logged-in user (`_currentUser`) for authorization.
  /// - If `_currentUser` is an admin, they can query all transactions subject to filters.
  /// - If `_currentUser` is not an admin, the query is implicitly filtered by the
  ///   `BankClient` and server to only include their personal transactions.
  ///
  /// Parameters:
  ///   - [queryParameters]: An object containing filters, sorting options, and limit.
  ///
  /// Returns a stream of lists of [BankTransaction]s that match the query.
  /// Returns an error stream if the user is not logged in or if an error occurs.
  Stream<List<BankTransaction>> searchTransactions(
      TransactionQueryParameters queryParameters) {
    if (_currentUser == null) {
      logger.w(
          'BankFacade.searchTransactions: Attempted to search transactions without a logged-in user.');
      return Stream.error(AuthenticationError(
          'User is not logged in. Cannot search transactions.'));
    }

    // The BankClient's searchTransactions method will handle the core logic
    // of applying filters and respecting admin/user roles based on the provided _currentUser.
    try {
      logger.i(
          'BankFacade: Searching transactions for user ${_currentUser!.username} (Admin: ${_currentUser!.isAdmin}, UserID: ${_currentUser!.userId}) with params: ${queryParameters.toJson()}');
      // Pass _currentUser as the authorizing user to the client method.
      return _client.searchTransactions(_currentUser!, queryParameters);
    } catch (e, s) {
      logger.e(
          'BankFacade: Error initiating transaction search for user ${_currentUser!.username}: $e',
          error: e,
          stackTrace: s);
      // Propagate error as a stream error for the UI to handle.
      return Stream.error(
          Exception('Failed to initiate transaction search: $e'));
    }
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
          authUser: adminUser, // Admin authorizing/performing the fund addition
          note: pendingTx.notes,
        );

      case pt.PendingTransactionType.withdrawal:
        // 'authUser' in BankTransaction.withdrawal is the admin authorizing.
        return BankTransaction.withdrawal(
          sourceUser: initiatingUser,
          // User from whose account funds are withdrawn
          amount: pendingTx.amount,
          authUser: adminUser, // Admin authorizing the withdrawal
          note: pendingTx.notes,
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
          note: pendingTx.notes,
          authUser: adminUser
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
          note: pendingTx.notes,
          authUser: adminUser
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
          await _client.submit(bankTransactionToSubmit);

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

  Future<ServerInfo> getServerInfo() async {
    return await _client.getServerInfo();
  }
}
