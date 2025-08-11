import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:home_bank/bank/bank_facade.dart';
import 'package:bank_server/bank.dart';
import 'package:home_bank/models/pending_transaction.dart';
import 'package:home_bank/utils/globals.dart';
import 'package:home_bank/widgets/qr_scanner_dialog_presenter.dart';

class TransactionApprovalScreen extends StatefulWidget {
  final PendingTransaction pendingTransaction;

  const TransactionApprovalScreen({
    super.key,
    required this.pendingTransaction,
  });

  @override
  State<TransactionApprovalScreen> createState() =>
      _TransactionApprovalScreenState();
}

class _TransactionApprovalScreenState extends State<TransactionApprovalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  User? _currentAdminUser;
  bool _isLoading = false;
  String? _loginError;
  bool _isAdminLoginSuccessful = false;

  late BankFacade _bankFacade;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
  }

  @override
  void dispose() {
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loginAdminForApproval() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _loginError = null;
      _isAdminLoginSuccessful = false;
    });

    try {
      final String username = _adminUsernameController.text;
      final String password = _adminPasswordController.text;

      final User admin =
          await _bankFacade.authenticateAdmin(username, password);

      _currentAdminUser = admin;
      _isAdminLoginSuccessful = true;
    } on AuthenticationError catch (e) {
      logger.e('Admin Authentication Error: ${e.message}');
      _loginError = e.message;
      _currentAdminUser = null;
      _isAdminLoginSuccessful = false;
    } catch (e) {
      logger.e('Admin Login Failed: $e');
      _loginError = 'An unexpected error occurred during admin login.';
      _currentAdminUser = null;
      _isAdminLoginSuccessful = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanAdminQRCodeWithPresenter() async {
    if (!mounted) return;

    final credentials = await QrScannerDialogPresenter.show(
      context,
      dialogTitle: 'Scan Admin QR Code',
      logger: logger,
    );

    if (!mounted) return; // Check mount status again after await

    if (credentials != null && credentials['username'] != null && credentials['password'] != null) {
      _adminUsernameController.text = credentials['username']!;
      _adminPasswordController.text = credentials['password']!;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin credentials populated! Authenticating...')),
      );
      _loginAdminForApproval();
    } else {
      logger.i('Admin QR scan cancelled or failed to retrieve credentials.');
    }
  }

  void _sendApprovalResult(bool isApproved, {String? rejectionReason}) {
    if (_currentAdminUser == null && isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin not logged in. Cannot approve.')),
      );
      return;
    }

    final Map<String, dynamic> result = {
      'isApproved': isApproved,
      'adminUser': _currentAdminUser,
      'pendingTransaction': widget.pendingTransaction,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (!isApproved) {
      result['reason'] = rejectionReason ?? 'Rejected by admin';
    }
    logger.i('Popping TransactionApprovalScreen with result: $result');
    context.pop(result);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTransactionDetailsCard(PendingTransaction tx) {
    // Original _buildTransactionDetailsCard content
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Transaction Details:',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 16),
            _detailRow('Type:', tx.type.name),
            _detailRow('Amount:', '\$${tx.amount.toStringAsFixed(2)}'),
            if (tx.initiatingUserUsername != null)
              _detailRow('Initiating User:', tx.initiatingUserUsername!),
            if (tx.targetAccountNickname != null)
              _detailRow('Target Account Name:', tx.targetAccountNickname!),
            if (tx.sourceAccountId != null)
              _detailRow('Source Account ID:', tx.sourceAccountId!.toString()),
            if (tx.sourceAccountNickname != null)
              _detailRow('Source Account Name:', tx.sourceAccountNickname!),
            if (tx.recipientUserId != null)
              _detailRow('Recipient User ID:', tx.recipientUserId!.toString()),
            if (tx.recipientUserUsername != null)
              _detailRow('Recipient User:', tx.recipientUserUsername!),
            if (tx.merchantId != null)
              _detailRow('Merchant ID:', tx.merchantId.toString()),
            if (tx.merchantName != null)
              _detailRow('Merchant Name:', tx.merchantName!),
            if (tx.notes != null && tx.notes!.isNotEmpty)
              _detailRow('Notes:', tx.notes!),
            const SizedBox(height: 8),
            Center(
                child: Text(tx.description,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectionDialog() async {
    // Original _showRejectionDialog content
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reject Transaction'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Optional: Reason for rejection',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Confirm Rejection',
                  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      _sendApprovalResult(false,
          rejectionReason: result.isNotEmpty
              ? result
              : 'Rejected by admin without explicit reason');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Approval'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.pop({
              'status': 'cancelled_by_admin_ui',
              'pendingTransaction': widget.pendingTransaction
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Approve Transaction',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),

            _buildTransactionDetailsCard(widget.pendingTransaction),
            const SizedBox(height: 24),

            if (!_isAdminLoginSuccessful) ...[
              Text('Admin Login',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _adminUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter admin username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adminPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Admin Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter admin password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (Platform.isAndroid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Admin QR'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _scanAdminQRCodeWithPresenter, // Use the new method
                        ),
                      ),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Login for Approval'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: _loginAdminForApproval,
                      ),
                    if (_loginError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _loginError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (_isAdminLoginSuccessful && _currentAdminUser != null) ...[
              Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_user,
                        size: 48, color: Colors.green[700]),
                    const SizedBox(height: 8),
                    Text(
                      'Admin "${_currentAdminUser!.username}" Authenticated',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.green[800]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.thumb_down_alt),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () {
                        _showRejectionDialog();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.thumb_up_alt),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => _sendApprovalResult(true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
