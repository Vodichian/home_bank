import 'package:flutter_test/flutter_test.dart';
import 'package:home_bank/models/pending_transaction.dart'; // Adjust import path as needed

void main() {
  // --- Test Data ---
  const String testPendingId = 'test-pending-id-123';
  const double testAmount = 100.0;
  // Changed ID types to int where applicable
  const int testInitiatingUserId = 101;
  const String testInitiatingUserUsername = 'Initiator Username';
  const int testTargetAccountId = 202;
  const String testTargetAccountNickname = 'Target Account Nickname';
  const int testSourceAccountId = 303;
  const String testSourceAccountNickname = 'Source Account Nickname';
  const int testRecipientUserId = 404;
  const String testRecipientUserUsername = 'Recipient Username';
  const int testMerchantId = 789; // Was already int
  const String testMerchantName = 'Test Merchant';
  const String testNotes = 'Test transaction notes';
  final DateTime fixedTestTimestamp =
      DateTime(2023, 11, 15, 10, 30, 0); // Fixed for predictable JSON

  group('PendingTransaction Enum Helpers', () {
    test('pendingTransactionTypeToString works correctly', () {
      expect(pendingTransactionTypeToString(PendingTransactionType.addFunds),
          'addFunds');
      expect(pendingTransactionTypeToString(PendingTransactionType.withdrawal),
          'withdrawal');
      expect(pendingTransactionTypeToString(PendingTransactionType.transfer),
          'transfer');
      expect(pendingTransactionTypeToString(PendingTransactionType.payment),
          'payment');
    });

    test('pendingTransactionTypeFromString works correctly', () {
      expect(pendingTransactionTypeFromString('addFunds'),
          PendingTransactionType.addFunds);
      expect(pendingTransactionTypeFromString('withdrawal'),
          PendingTransactionType.withdrawal);
      expect(pendingTransactionTypeFromString('transfer'),
          PendingTransactionType.transfer);
      expect(pendingTransactionTypeFromString('payment'),
          PendingTransactionType.payment);
    });

    test('pendingTransactionTypeFromString throws for unknown type', () {
      expect(() => pendingTransactionTypeFromString('unknownType'),
          throwsArgumentError);
    });
  });

  group('PendingTransaction Named Constructors', () {
    // --- AddFunds ---
    test('addFunds constructor creates correct object', () {
      final transaction = PendingTransaction.addFunds(
        pendingId: testPendingId,
        amount: testAmount,
        initiatingUserId: testInitiatingUserId,
        // Now int
        initiatingUserUsername: testInitiatingUserUsername,
        targetSavingsAccountId: testTargetAccountId,
        // Now int
        targetSavingsAccountNickname: testTargetAccountNickname,
        notes: testNotes,
      );

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.addFunds);
      expect(transaction.amount, testAmount);
      expect(transaction.initiatingUserId, testInitiatingUserId);
      expect(transaction.initiatingUserUsername, testInitiatingUserUsername);
      expect(transaction.targetAccountId, testTargetAccountId);
      expect(transaction.targetAccountNickname, testTargetAccountNickname);
      expect(transaction.notes, testNotes);
      // Check that fields for other types are null
      expect(transaction.sourceAccountId, isNull);
      expect(transaction.recipientUserId, isNull);
      expect(transaction.merchantId, isNull);
    });

    // --- Withdrawal ---
    test('withdrawal constructor creates correct object', () {
      final transaction = PendingTransaction.withdrawal(
        pendingId: testPendingId,
        amount: testAmount,
        initiatingUserId: testInitiatingUserId,
        // Now int
        initiatingUserUsername: testInitiatingUserUsername,
        sourceSavingsAccountId: testSourceAccountId,
        // Now int
        sourceSavingsAccountNickname: testSourceAccountNickname,
        notes: testNotes,
      );

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.withdrawal);
      expect(transaction.amount, testAmount);
      expect(transaction.initiatingUserId, testInitiatingUserId);
      expect(transaction.sourceAccountId, testSourceAccountId);
      expect(transaction.sourceAccountNickname, testSourceAccountNickname);
      // Check that fields for other types are null
      expect(transaction.targetAccountId, isNull);
      expect(transaction.recipientUserId, isNull);
      expect(transaction.merchantId, isNull);
    });

    // --- Transfer ---
    test('transfer constructor creates correct object', () {
      final transaction = PendingTransaction.transfer(
        pendingId: testPendingId,
        amount: testAmount,
        initiatingUserId: testInitiatingUserId,
        // Now int
        initiatingUserUsername: testInitiatingUserUsername,
        sourceSavingsAccountId: testSourceAccountId,
        // Now int
        sourceSavingsAccountNickname: testSourceAccountNickname,
        recipientUserId: testRecipientUserId,
        // Now int
        recipientUserUsername: testRecipientUserUsername,
        notes: testNotes,
      );

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.transfer);
      expect(transaction.amount, testAmount);
      expect(transaction.initiatingUserId, testInitiatingUserId);
      expect(transaction.sourceAccountId, testSourceAccountId);
      expect(transaction.recipientUserId, testRecipientUserId);
      // Check that fields for other types are null
      expect(transaction.merchantId, isNull);
    });

    // --- Payment ---
    test('payment constructor creates correct object', () {
      final transaction = PendingTransaction.payment(
        pendingId: testPendingId,
        amount: testAmount,
        initiatingUserId: testInitiatingUserId,
        // Now int
        initiatingUserUsername: testInitiatingUserUsername,
        sourceSavingsAccountId: testSourceAccountId,
        // Now int
        sourceSavingsAccountNickname: testSourceAccountNickname,
        merchantId: testMerchantId,
        // Stays int
        merchantName: testMerchantName,
        notes: testNotes,
      );

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.payment);
      expect(transaction.amount, testAmount);
      expect(transaction.initiatingUserId, testInitiatingUserId);
      expect(transaction.sourceAccountId, testSourceAccountId);
      expect(transaction.merchantId, testMerchantId);
      // Check that fields for other types are null
      expect(transaction.targetAccountId, isNull);
      expect(transaction.recipientUserId, isNull);
    });
  });

  group('PendingTransaction JSON Serialization/Deserialization', () {
    late PendingTransaction sampleAddFundsTx;

    setUp(() {
      final jsonMap = {
        'id': testPendingId,
        'type': 'addFunds',
        'amount': testAmount,
        'requestTimestamp': fixedTestTimestamp.toIso8601String(),
        'initiatingUserId': testInitiatingUserId, // Now int
        'initiatingUserUsername': testInitiatingUserUsername,
        'targetAccountId': testTargetAccountId, // Now int
        'targetAccountNickname': testTargetAccountNickname,
        'sourceAccountId': null,
        'sourceAccountNickname': null,
        'recipientUserId': null,
        'recipientUserUsername': null,
        'merchantId': null,
        'merchantName': null,
        'notes': testNotes,
      };
      sampleAddFundsTx = PendingTransaction.fromJson(jsonMap);
    });

    test('toJson creates correct map', () {
      final json = sampleAddFundsTx.toJson();

      expect(json['id'], testPendingId);
      expect(json['type'], 'addFunds');
      expect(json['amount'], testAmount);
      expect(json['requestTimestamp'], fixedTestTimestamp.toIso8601String());
      expect(json['initiatingUserId'], testInitiatingUserId); // Expect int
      expect(json['initiatingUserUsername'], testInitiatingUserUsername);
      expect(json['targetAccountId'], testTargetAccountId); // Expect int
      expect(json['targetAccountNickname'], testTargetAccountNickname);
      expect(json['notes'], testNotes);
      expect(json['sourceAccountId'], isNull);
    });

    test('fromJson creates correct object', () {
      final jsonMap = {
        'id': testPendingId,
        'type': 'withdrawal',
        'amount': 250.0,
        'requestTimestamp': fixedTestTimestamp.toIso8601String(),
        'initiatingUserId': testInitiatingUserId, // Now int
        'sourceAccountId': testSourceAccountId, // Now int
        'notes': 'Withdrawal notes',
      };

      final transaction = PendingTransaction.fromJson(jsonMap);

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.withdrawal);
      expect(transaction.amount, 250.0);
      expect(transaction.requestTimestamp, fixedTestTimestamp);
      expect(transaction.initiatingUserId, testInitiatingUserId); // Expect int
      expect(transaction.sourceAccountId, testSourceAccountId); // Expect int
      expect(transaction.notes, 'Withdrawal notes');
      expect(transaction.initiatingUserUsername, isNull);
      expect(transaction.targetAccountId, isNull);
    });

    test('toJsonString creates correct JSON string', () {
      final jsonString = sampleAddFundsTx.toJsonString();
      expect(jsonString, contains('"id":"$testPendingId"'));
      expect(jsonString, contains('"type":"addFunds"'));
      expect(jsonString, contains('"amount":$testAmount'));
      expect(
          jsonString,
          contains(
              '"initiatingUserId":$testInitiatingUserId')); // Check int serialization
      expect(
          jsonString,
          contains(
              '"targetAccountId":$testTargetAccountId')); // Check int serialization
      expect(
          jsonString,
          contains(
              '"requestTimestamp":"${fixedTestTimestamp.toIso8601String()}"'));
    });

    test('fromJsonString creates correct object', () {
      // Note: JSON numbers are just numbers, Dart handles parsing them to int/double.
      final jsonString = '''
        {
          "id": "$testPendingId",
          "type": "payment",
          "amount": 75.50,
          "requestTimestamp": "${fixedTestTimestamp.toIso8601String()}",
          "initiatingUserId": $testInitiatingUserId,
          "sourceAccountId": $testSourceAccountId,
          "merchantId": $testMerchantId,
          "merchantName": "$testMerchantName"
        }
      ''';

      final transaction = PendingTransaction.fromJsonString(jsonString);

      expect(transaction.id, testPendingId);
      expect(transaction.type, PendingTransactionType.payment);
      expect(transaction.amount, 75.50);
      expect(transaction.requestTimestamp, fixedTestTimestamp);
      expect(transaction.initiatingUserId, testInitiatingUserId); // Expect int
      expect(transaction.sourceAccountId, testSourceAccountId); // Expect int
      expect(transaction.merchantId, testMerchantId);
      expect(transaction.merchantName, testMerchantName);
      expect(transaction.notes, isNull);
    });

    test('fromJson handles all nullable fields correctly when null', () {
      final jsonMap = {
        'id': 'minimal-id',
        'type': 'addFunds',
        'amount': 1.0,
        'requestTimestamp': fixedTestTimestamp.toIso8601String(),
        'initiatingUserId': 999, // int
        'targetAccountId': 888, // int
        // All other optional fields are null
      };
      final transaction = PendingTransaction.fromJson(jsonMap);
      expect(transaction.id, 'minimal-id');
      expect(transaction.type, PendingTransactionType.addFunds);
      expect(transaction.initiatingUserId, 999);
      expect(transaction.targetAccountId, 888);
      expect(transaction.initiatingUserUsername, isNull);
      expect(transaction.targetAccountNickname, isNull);
      expect(transaction.sourceAccountId, isNull);
      expect(transaction.sourceAccountNickname, isNull);
      expect(transaction.recipientUserId, isNull);
      expect(transaction.recipientUserUsername, isNull);
      expect(transaction.merchantId, isNull);
      expect(transaction.merchantName, isNull);
      expect(transaction.notes, isNull);
    });
  });

  group('PendingTransaction Description Getter', () {
    test('description for addFunds is correct', () {
      final tx = PendingTransaction.addFunds(
          pendingId: 'id1',
          amount: 50,
          initiatingUserId: 1,
          targetSavingsAccountId: 101,
          targetSavingsAccountNickname: 'My Savings');
      expect(tx.description, 'Add Funds of \$50.00 to My Savings');

      final txNoNickname = PendingTransaction.addFunds(
          pendingId: 'id2',
          amount: 50,
          initiatingUserId: 1,
          targetSavingsAccountId: 102); // Just ID
      expect(
          txNoNickname.description, 'Add Funds of \$50.00 to Account ID: 102');
    });

    test('description for withdrawal is correct', () {
      final tx = PendingTransaction.withdrawal(
          pendingId: 'id1',
          amount: 30,
          initiatingUserId: 1,
          sourceSavingsAccountId: 201,
          sourceSavingsAccountNickname: 'Checking');
      expect(tx.description, 'Withdraw \$30.00 from Checking');

      final txNoNickname = PendingTransaction.withdrawal(
          pendingId: 'id2',
          amount: 30,
          initiatingUserId: 1,
          sourceSavingsAccountId: 202); // Just ID
      expect(txNoNickname.description, 'Withdraw \$30.00 from Account ID: 202');
    });

    test('description for transfer is correct', () {
      final tx = PendingTransaction.transfer(
        pendingId: 'id1',
        amount: 100,
        initiatingUserId: 1,
        sourceSavingsAccountId: 301,
        sourceSavingsAccountNickname: 'My Source',
        recipientUserId: 2,
        recipientUserUsername: 'John Doe',
      );
      expect(tx.description,
          'Transfer \$100.00 from My Source to John Doe');

      final txPartialNames = PendingTransaction.transfer(
        pendingId: 'id2',
        amount: 100,
        initiatingUserId: 1,
        sourceSavingsAccountId: 302,
        // Source ID
        recipientUserId: 3,
      );
      expect(txPartialNames.description,
          'Transfer \$100.00 from Account ID: 302 to User ID: 3');
    });

    test('description for payment is correct', () {
      final tx = PendingTransaction.payment(
          pendingId: 'id1',
          amount: 20,
          initiatingUserId: 1,
          sourceSavingsAccountId: 501,
          sourceSavingsAccountNickname: 'Debit Card',
          merchantId: 123,
          merchantName: 'Coffee Shop');
      expect(tx.description, 'Pay \$20.00 to Coffee Shop from Debit Card');

      final txMerchantIdOnly = PendingTransaction.payment(
          pendingId: 'id2',
          amount: 20,
          initiatingUserId: 1,
          sourceSavingsAccountId: 502,
          // Source ID only
          merchantId: 124 // Merchant ID only
          // merchantName is null
          );
      expect(txMerchantIdOnly.description,
          'Pay \$20.00 to Merchant ID: 124 from Account ID: 502');
    });
  });
}
