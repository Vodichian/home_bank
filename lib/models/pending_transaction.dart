import 'dart:convert'; // For jsonEncode and jsonDecode
// import 'package:uuid/uuid.dart'; // If you're using it directly here

// Assuming PendingTransactionType is defined in the same file or imported
enum PendingTransactionType {
  addFunds,
  withdrawal,
  transfer,
  payment,
}

// Helper to convert enum to string and back
String pendingTransactionTypeToString(PendingTransactionType type) {
  return type.name; // Uses the enum value's name (e.g., "addFunds")
}

PendingTransactionType pendingTransactionTypeFromString(String typeString) {
  return PendingTransactionType.values.firstWhere(
        (e) => e.name == typeString,
    orElse: () =>
    throw ArgumentError('Unknown PendingTransactionType: $typeString'),
  );
}


class PendingTransaction {
  final String id; // This remains String, typically a UUID
  final PendingTransactionType type;
  final double amount;
  final DateTime requestTimestamp;
  final int initiatingUserId;
  final String? initiatingUserUsername;

  final int? targetAccountId;
  final String? targetAccountNickname;
  final int? sourceAccountId;
  final String? sourceAccountNickname;

  final int? recipientUserId;
  final String? recipientUserUsername;

  final int? merchantId;
  final String? merchantName;

  final String? notes;

  PendingTransaction._({
    required this.id,
    required this.type,
    required this.amount,
    required this.requestTimestamp,
    required this.initiatingUserId,
    this.initiatingUserUsername,
    this.targetAccountId,
    this.targetAccountNickname,
    this.sourceAccountId,
    this.sourceAccountNickname,
    this.recipientUserId,
    this.recipientUserUsername,
    this.merchantId,
    this.merchantName,
    this.notes,
  }) {
    // Basic validation based on type
    switch (type) {
      case PendingTransactionType.addFunds:
        assert(targetAccountId !=
            null, 'targetAccountId is required for AddFunds.');
        break;
      case PendingTransactionType.withdrawal:
        assert(sourceAccountId !=
            null, 'sourceAccountId is required for Withdrawal.');
        break;
      case PendingTransactionType.transfer:
        assert(sourceAccountId !=
            null, 'sourceAccountId is required for Transfer.');
        assert(recipientUserId !=
            null, 'recipientUserId is required for Transfer.');
        assert(targetAccountId !=
            null, "targetAccountId (recipient's savings) is required for Transfer.");
        break;
      case PendingTransactionType.payment:
        assert(sourceAccountId !=
            null, 'sourceAccountId is required for Payment.');
        assert(merchantId != null, 'merchantId is required for Payment.');
        break;
    }
  }

  // --- Named Constructors ---
  factory PendingTransaction.addFunds({
    required String pendingId,
    required double amount,
    required int initiatingUserId,
    String? initiatingUserUsername,
    required int targetSavingsAccountId,
    String? targetSavingsAccountNickname,
    String? notes,
  }) {
    return PendingTransaction._(
      id: pendingId,
      type: PendingTransactionType.addFunds,
      amount: amount,
      requestTimestamp: DateTime.now(),
      initiatingUserId: initiatingUserId,
      initiatingUserUsername: initiatingUserUsername,
      targetAccountId: targetSavingsAccountId,
      targetAccountNickname: targetSavingsAccountNickname,
      notes: notes,
    );
  }

  factory PendingTransaction.withdrawal({
    required String pendingId,
    required double amount,
    required int initiatingUserId,
    String? initiatingUserUsername,
    required int sourceSavingsAccountId,
    String? sourceSavingsAccountNickname,
    String? notes,
  }) {
    return PendingTransaction._(
      id: pendingId,
      type: PendingTransactionType.withdrawal,
      amount: amount,
      requestTimestamp: DateTime.now(),
      initiatingUserId: initiatingUserId,
      initiatingUserUsername: initiatingUserUsername,
      sourceAccountId: sourceSavingsAccountId,
      sourceAccountNickname: sourceSavingsAccountNickname,
      notes: notes,
    );
  }

  factory PendingTransaction.transfer({
    required String pendingId,
    required double amount,
    required int initiatingUserId,
    String? initiatingUserUsername,
    required int sourceSavingsAccountId,
    String? recipientUserUsername,
    required int recipientUserId,
    required int recipientSavingsAccountId,
    String? sourceSavingsAccountNickname,
    String? recipientSavingsAccountNickname,
    String? notes,
  }) {
    return PendingTransaction._(
      id: pendingId,
      type: PendingTransactionType.transfer,
      amount: amount,
      requestTimestamp: DateTime.now(),
      initiatingUserId: initiatingUserId,
      initiatingUserUsername: initiatingUserUsername,
      sourceAccountId: sourceSavingsAccountId,
      sourceAccountNickname: sourceSavingsAccountNickname,
      recipientUserId: recipientUserId,
      recipientUserUsername: recipientUserUsername,
      targetAccountId: recipientSavingsAccountId,
      // This is the recipient's account
      targetAccountNickname: recipientSavingsAccountNickname,
      notes: notes,
    );
  }

  factory PendingTransaction.payment({
    required String pendingId,
    required double amount,
    required int initiatingUserId,
    String? initiatingUserUsername,
    required int sourceSavingsAccountId,
    String? sourceSavingsAccountNickname,
    required int merchantId,
    String? merchantName,
    String? notes,
  }) {
    return PendingTransaction._(
      id: pendingId,
      type: PendingTransactionType.payment,
      amount: amount,
      requestTimestamp: DateTime.now(),
      initiatingUserId: initiatingUserId,
      initiatingUserUsername: initiatingUserUsername,
      sourceAccountId: sourceSavingsAccountId,
      sourceAccountNickname: sourceSavingsAccountNickname,
      merchantId: merchantId,
      merchantName: merchantName,
      notes: notes,
    );
  }

  // --- JSON Serialization ---

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': pendingTransactionTypeToString(type),
      'amount': amount,
      'requestTimestamp': requestTimestamp.toIso8601String(),
      'initiatingUserId': initiatingUserId,
      // Will be serialized as number
      'initiatingUserUsername': initiatingUserUsername,
      'targetAccountId': targetAccountId,
      // Will be serialized as number or null
      'targetAccountNickname': targetAccountNickname,
      'sourceAccountId': sourceAccountId,
      // Will be serialized as number or null
      'sourceAccountNickname': sourceAccountNickname,
      'recipientUserId': recipientUserId,
      // Will be serialized as number or null
      'recipientUserUsername': recipientUserUsername,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'notes': notes,
    };
  }


  // --- JSON String Serialization ---
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // --- JSON String Deserialization (Factory Constructor) ---
  factory PendingTransaction.fromJsonString(String jsonString) {
    return PendingTransaction.fromJson(jsonDecode(jsonString));
  }

  // --- JSON Deserialization (Factory Constructor) ---
  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    return PendingTransaction._(
      id: json['id'] as String,
      type: pendingTransactionTypeFromString(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      requestTimestamp: DateTime.parse(json['requestTimestamp'] as String),
      initiatingUserId: json['initiatingUserId'] as int,
      // Parse as int
      initiatingUserUsername: json['initiatingUserUsername'] as String?,
      targetAccountId: json['targetAccountId'] as int?,
      // Parse as int?
      targetAccountNickname: json['targetAccountNickname'] as String?,
      sourceAccountId: json['sourceAccountId'] as int?,
      // Parse as int?
      sourceAccountNickname: json['sourceAccountNickname'] as String?,
      recipientUserId: json['recipientUserId'] as int?,
      // Parse as int?
      recipientUserUsername: json['recipientUserUsername'] as String?,
      merchantId: json['merchantId'] as int?,
      merchantName: json['merchantName'] as String?,
      notes: json['notes'] as String?,
    );
  }


  // --- Helper Methods (Optional) ---
  String get description {
    // Updated to reflect potential int IDs if nicknames are null
    switch (type) {
      case PendingTransactionType.addFunds:
        return 'Add Funds of \$${amount.toStringAsFixed(
            2)} to ${targetAccountNickname ?? 'Account ID: $targetAccountId'}';
      case PendingTransactionType.withdrawal:
        return 'Withdraw \$${amount.toStringAsFixed(
            2)} from ${sourceAccountNickname ??
            'Account ID: $sourceAccountId'}';
      case PendingTransactionType.transfer:
        return 'Transfer \$${amount.toStringAsFixed(
            2)} from ${sourceAccountNickname ??
            'Account ID: $sourceAccountId'} to ${recipientUserUsername ??
            'User ID: $recipientUserId'} (${targetAccountNickname ??
            'Account ID: $targetAccountId'})';
      case PendingTransactionType.payment:
        return 'Pay \$${amount.toStringAsFixed(2)} to ${merchantName ??
            'Merchant ID: $merchantId'} from ${sourceAccountNickname ??
            'Account ID: $sourceAccountId'}';
    }
  }
}