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
  bool _hasAttemptedFirstInitialize = false; // Added flag
  final Map<String, double> _conversionRates = {};

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

  bool get hasAttemptedFirstInitialize =>
      _hasAttemptedFirstInitialize; // Added getter

  Future<void> initialize() async {
    try {
      if (isConnected) {
        await _client
            .disconnect(); // Disconnect if already connected (e.g., after a switch)
      }
      _currentUser = null; // Clear user on new connection/re-initialization
      logger.i(
          "Attempting to connect to: ${_currentServerConfig.name} (${_currentServerConfig.address})");
      await _client.connect(address: _currentServerConfig.address);
      logger.i("Successfully connected to: ${_currentServerConfig.name}");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastServerTypeKey, _currentServerConfig.type.name);
    } catch (e) {
      logger.e("Failed to connect to ${_currentServerConfig.name}: $e");
      rethrow; // Propagate error for UI to handle
    } finally {
      _hasAttemptedFirstInitialize = true;
      notifyListeners(); // Notify about connection state change (and currentUser reset) and first initialize attempt
    }
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
    // No need to set _hasAttemptedFirstInitialize here as initialize() will be called
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

  /// Checks if the current user is authenticated.
  bool get isAuthenticated => _currentUser != null;

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

  /// When fetching users for a dropdown
  Future<List<User>> getSelectableUsers() async {
    final allUsers = await _client.getUsers(currentUser!);
    return allUsers.where((user) => !user.isSystemAccount).toList();
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
      // Option 1: Throw immediately
      throw AuthenticationError('User is not logged in to stream users.');
      // Option 2: Return an error stream (often better for UI handling)
      // return Stream.error(AuthenticationError('User is not logged in to stream users.'));
    }

    // Assume _client.users(_currentUser!) returns the raw stream from the gRPC client
    // We will .map() this stream to transform its emitted lists.
    return _client.users(_currentUser!).map((userList) {
      // Apply the same filtering logic used in getSelectableUsers
      // This ensures consistency between the initial fetch and subsequent stream updates.
      logger.d(
          "BankFacade: Stream 'users()' - Raw list count: ${userList.length}");
      final filteredList = userList.where((user) {
        // Your conditions for a "selectable" or "non-system" user
        // For example, if 'isSystemAccount' is the flag:
        return !user.isSystemAccount;
        // If you also want to exclude the current user from this generic stream,
        // you could add: && user.userId != _currentUser!.userId
        // However, usually, a generic 'users' stream provides all (non-system) users,
        // and the UI layer decides if the current user should be filtered out for a specific context.
        // For a transfer screen, filtering the current user in the UI is common.
      }).toList();
      logger.d(
          "BankFacade: Stream 'users()' - Filtered list count: ${filteredList.length}");
      return filteredList;
    }).handleError((error) {
      // Optional: Log errors from the underlying stream
      logger.e("BankFacade: Error in users stream: $error");
      // Rethrow the error so subscribers can also handle it
      throw error;
    });
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

  /// Provides a real-time stream of updates for all [SavingsAccount]s on the server.
  ///
  /// This method is intended for admin use.
  /// The stream emits a new list of [SavingsAccount]s whenever there are changes.
  ///
  /// Throws [AuthenticationError] if the current user is not logged in or is not an admin.
  /// Errors from the underlying client stream are propagated.
  Stream<List<SavingsAccount>> listenAllSavingsAccounts() {
    if (_currentUser == null) {
      throw AuthenticationError(
          'User is not logged in. Cannot listen to all savings accounts.');
    }
    if (!_currentUser!.isAdmin) {
      throw AuthenticationError(
          'User is not an admin. Admin privileges are required to listen to all savings accounts.');
    }
    return _client.listenSavingsAccounts(_currentUser!);
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
            sourceUser: initiatingUser,
            // User sending the funds
            amount: pendingTx.amount,
            targetUser: targetUser,
            // User receiving the funds
            note: pendingTx.notes,
            authUser: adminUser);

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
            sourceUser: initiatingUser,
            // User making the payment
            amount: pendingTx.amount,
            merchant: targetMerchant,
            // Merchant receiving the payment
            note: pendingTx.notes,
            authUser: adminUser);
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
      int newTransactionId = await _client.submit(bankTransactionToSubmit);

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
    await _client.saveMerchant(updatedMerchant, _currentUser!);
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

  /// Retrieves the total interest accrued for a user's account over a specified period.
  ///
  /// This method typically retrieves interest for the currently logged-in user.
  /// If an admin is logged in, they can potentially query for other users,
  /// assuming the `BankClient` and server backend support this (by passing a different `ownerUserId`).
  ///
  /// [ownerUserId]: The ID of the user whose interest is being queried. If null,
  ///                it defaults to the currently logged-in user\'s ID.
  /// [startDate]: Optional start date for the interest calculation period.
  /// [endDate]: Optional end date for the interest calculation period.
  ///
  /// Throws [AuthenticationError] if the user is not logged in, or if the
  /// logged-in user is not authorized to view the interest for the specified `ownerUserId`.
  /// Throws [StateError] for other server-side errors.
  Future<double> getInterestAccrued({
    int? ownerUserId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in.');
    }

    // Default to the current user\'s ID if ownerUserId is not provided.
    final targetUserId = ownerUserId ?? _currentUser!.userId;

    // The BankClient method requires authUser and ownerUserId separately.
    // _currentUser is the authenticated user making the request.
    // targetUserId is the user whose interest we are querying.
    return await _client.getInterestAccrued(
      _currentUser!,
      targetUserId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Retrieves the balance history for a user's savings account over a specified period.
  ///
  /// This method fetches a series of balance snapshots for the user's account,
  /// ending on the given [endDate] and going back for the specified number of [days].
  ///
  /// [userId]: The ID of the user whose balance history is being queried. If null,
  ///           it defaults to the currently logged-in user's ID.
  /// [endDate]: The last date for which to retrieve the balance.
  /// [days]: The number of days of history to retrieve, ending on [endDate].
  ///
  /// Returns a [Future] that completes with a [Map] where keys are [DateTime] objects
  /// representing the date of the balance snapshot, and values are the corresponding
  /// account balance as a [double].
  ///
  /// Throws [AuthenticationError] if the user is not logged in, or if the
  /// logged-in user is not authorized to view the history for the specified `userId`.
  /// Throws [StateError] for other server-side errors.
  Future<Map<DateTime, double>> getBalanceHistory({
    int? userId,
    required DateTime endDate,
    required int days,
  }) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in.');
    }
    final targetUserId = userId ?? _currentUser!.userId;
    return await _client.getBalanceHistory(
        _currentUser!, targetUserId, endDate, days);
  }

  /// Exports the entire bank database to a JSON string.
  /// Requires the current user to be an administrator.
  Future<String> exportDatabaseToJson() async {
    if (_currentUser == null) {
      throw AuthenticationError(
          'User is not logged in. Cannot export database.');
    }
    if (!_currentUser!.isAdmin) {
      throw AuthenticationError(
          'User is not an admin. Admin privileges are required to export the database.');
    }
    // Assuming the _client.exportDatabaseToJson method handles API calls and returns the JSON string
    // or throws an error if the underlying client call fails or returns a fail message.
    logger.i(
        "BankFacade: User ${_currentUser!.username} is exporting database to JSON.");
    try {
      return await _client.exportDatabaseToJson(_currentUser!);
    } catch (e) {
      logger.e("BankFacade: Error exporting database: $e");
      rethrow; // Propagate the error
    }
  }

  /// Imports a bank database from a JSON string.
  /// Requires the current user to be an administrator.
  /// The [jsonData] parameter contains the database content to import.
  Future<bool> importDatabaseFromJson(String jsonData) async {
    if (_currentUser == null) {
      throw AuthenticationError(
          'User is not logged in. Cannot import database.');
    }
    if (!_currentUser!.isAdmin) {
      throw AuthenticationError(
          'User is not an admin. Admin privileges are required to import the database.');
    }
    // Assuming the _client.importDatabaseFromJson method handles API calls and returns a success boolean
    // or throws an error if the underlying client call fails or returns a fail message.
    logger.i(
        "BankFacade: User ${_currentUser!.username} is importing database from JSON.");
    try {
      final success =
          await _client.importDatabaseFromJson(_currentUser!, jsonData);
      if (success) {
        logger.i("BankFacade: Database import successful.");
        // Consider if any local state needs to be refreshed or invalidated after import.
        // For example, if currentUser's details might have changed, you might want to re-fetch them
        // or notify listeners broadly if the whole dataset could have changed.
        // For now, just returning success. A full app refresh or re-login might be
        // a good idea for the UI to suggest to the user after an import.
      } else {
        logger.w(
            "BankFacade: Database import reported as unsuccessful by the client.");
      }
      return success;
    } catch (e) {
      logger.e("BankFacade: Error importing database: $e");
      rethrow; // Propagate the error
    }
  }

  /// Checks for available client updates on the server.
  ///
  /// Returns a [Future] that completes with a [ClientUpdateInfo] object if an
  /// update is available, or `null` if the client is already up-to-date.
  ///
  /// Throws a [StateError] if the client is not connected to the server.
  Future<ClientUpdateInfo?> checkForUpdate() async {
    // The BankClient's checkForUpdate method already handles the logic
    // including the connection state check.
    return await _client.checkForUpdate();
  }

  /// Downloads the client update package for the specified [version].
  ///
  /// The downloaded package is saved to the specified [savePath].
  ///
  /// [version] The [Version] of the client package to download.
  /// [savePath] The local file system path where the downloaded package will be saved.
  ///
  /// Returns a [Future] that completes when the download is finished.
  ///
  /// Throws a [StateError] if the client is not connected, if the requested
  /// package is not found on the server, or for other download errors.
  Future<void> downloadClientPackage(Version version, String savePath) async {
    // The BankClient's downloadClientPackage method handles all the logic
    // including connection state check, file operations, and error handling.
    return await _client.downloadClientPackage(version, savePath);
  }

  /// Converts an amount from one currency to another.
  ///
  /// [fromCurrency] The currency to convert from (e.g., 'USD').
  /// [toCurrency] The currency to convert to (e.g., 'VND').
  /// [amount] The amount to convert.
  ///
  /// Returns a [Future] that completes with the converted amount.
  ///
  /// Throws [StateError] for unsupported conversions or other server-side errors.
  Future<double> getCurrencyConversion(
      String fromCurrency, String toCurrency, double amount) async {
    final key = '$fromCurrency-$toCurrency';
    if (_conversionRates.containsKey(key)) {
      return _conversionRates[key]! * amount;
    }

    final inverseKey = '$toCurrency-$fromCurrency';
    if (_conversionRates.containsKey(inverseKey)) {
      return (1 / _conversionRates[inverseKey]!) * amount;
    }

    final convertedAmount =
        await _client.getCurrencyConversion(fromCurrency, toCurrency, amount);
    final rate = convertedAmount / amount;
    _conversionRates[key] = rate;
    return convertedAmount;
  }

  /// Updates the interest rate for a specific savings account on the server.
  ///
  /// This operation requires administrative privileges. The authUser must be an admin to perform this action.
  ///
  /// accountNumber: The account number of the savings account to update.
  /// newInterestRate: The new interest rate to set (e.g., 0.05 for 5%).
  /// Returns a Future that completes with true if the update was successful.
  ///
  /// Throws:
  ///
  /// AuthenticationError if the authUser is not an admin.
  /// StateError if the newInterestRate is invalid (e.g., negative or too high), if the account does not exist, or for other server-side failures.
  Future<bool> updateInterestRate(int accountNumber, double newInterestRate) async {
    if (_currentUser == null) {
      throw AuthenticationError('User is not logged in');
    } else if (!_currentUser!.isAdmin) {
      throw AuthenticationError('An admin is required to update interest rates');
    }
    return await _client.updateInterestRate(_currentUser!, accountNumber, newInterestRate);
  }
}
