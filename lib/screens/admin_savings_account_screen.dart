import 'package:flutter/material.dart';
import 'package:bank_server/bank.dart'; // For SavingsAccount and User
import 'package:home_bank/bank/bank_facade.dart'; // For BankFacade
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For formatting
import 'package:home_bank/utils/globals.dart'; // For logger

class AdminSavingsAccountScreen extends StatefulWidget {
  final SavingsAccount savingsAccount;

  const AdminSavingsAccountScreen({super.key, required this.savingsAccount});

  @override
  State<AdminSavingsAccountScreen> createState() => _AdminSavingsAccountScreenState();
}

class _AdminSavingsAccountScreenState extends State<AdminSavingsAccountScreen> {
  late BankFacade _bankFacade;
  late TextEditingController _interestRateController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Store the initial rate to compare against, and to reset the controller if needed.
  // This will also be updated upon successful save.
  late double _currentInterestRateOnScreen;

  // Helper to format the rate string, removing trailing zeros
  String _formatRateString(double rate) {
    String asString = rate.toString();
    if (asString.contains('.')) {
      asString = asString.replaceAll(RegExp(r'0*$'), ''); // Remove trailing zeros
      if (asString.endsWith('.')) {
        asString = asString.substring(0, asString.length - 1); // Remove trailing decimal point
      }
    }
    return asString;
  }

  @override
  void initState() {
    super.initState();
    _bankFacade = Provider.of<BankFacade>(context, listen: false);
    _currentInterestRateOnScreen = widget.savingsAccount.interestRate;
    _interestRateController = TextEditingController(text: _formatRateString(_currentInterestRateOnScreen));
  }

  @override
  void dispose() {
    _interestRateController.dispose();
    super.dispose();
  }

  Future<void> _saveInterestRate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newRateString = _interestRateController.text;
    final newRate = double.tryParse(newRateString);

    if (newRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid interest rate format.')),
      );
      return;
    }

    // Compare with the rate currently displayed/edited, which reflects the latest successful save or initial load
    if (newRate == _currentInterestRateOnScreen) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest rate is unchanged from the current value.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // The method in BankFacade will be named updateInterestRate as per request.
      final success = await _bankFacade.updateInterestRate(
        widget.savingsAccount.accountNumber,
        newRate,
      );

      if (mounted) { // Check if widget is still in the tree
        if (success) {
          _currentInterestRateOnScreen = newRate; // Update our reference for the current saved rate
           // Update controller with potentially formatted new rate
          _interestRateController.text = _formatRateString(newRate);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interest rate updated successfully!')),
          );
          // The parent screen (InvestmentOversightScreen) listens to a stream of accounts.
          // When the BankClient updates the rate on the server, the server should ideally
          // push an update through the stream _bankFacade.listenAllSavingsAccounts().
          // This would cause InvestmentOversightScreen to rebuild its list, and if the user
          // navigates back, they'd see the updated rate there.
          // If this screen itself needs to reflect that the underlying 'widget.savingsAccount'
          // from its parent is now "stale" compared to the server, it would require
          // listening to a stream for this specific account, or re-fetching.
          // For simplicity, we'll assume the stream on the parent screen will handle eventual consistency.
        } else {
          _interestRateController.text = _formatRateString(_currentInterestRateOnScreen); // Revert controller to last known good rate
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update interest rate. Server reported failure.')),
          );
        }
      }
    } catch (e) {
      logger.e("Error updating interest rate: $e", error: e);
       if (mounted) {
        _interestRateController.text = _formatRateString(_currentInterestRateOnScreen); // Revert on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating interest rate: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.savingsAccount;
    final dateFormat = DateFormat.yMd().add_jms();
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account Details'), // Title remains as per your request
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Padding around the content
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Make cards stretch
            children: <Widget>[
              // Card for Account Information
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 16.0), // Space below this card
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                color: theme.colorScheme.surfaceContainerHighest, // Card background color
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildInfoTile('Nickname:', account.nickname.isNotEmpty ? account.nickname : 'N/A'),
                      _buildInfoTile('Owner:', '${account.owner.fullName} (${account.owner.username})'),
                      _buildInfoTile('Account Number:', account.accountNumber.toString()),
                      _buildInfoTile('Owner Is Admin:', account.owner.isAdmin.toString()),
                      _buildInfoTile('Balance:', currencyFormat.format(account.balance)),
                      _buildInfoTile('Created:', dateFormat.format(account.created)),
                      _buildInfoTile(
                        'Last Interest Accrued:',
                        account.lastInterestAccruedDate != null
                            ? dateFormat.format(account.lastInterestAccruedDate!)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),

              // Card for Interest Rate Management
              Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                color: theme.colorScheme.surfaceContainerHighest, // Card background color
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: <Widget>[
                      TextFormField(
                        controller: _interestRateController,
                        decoration: InputDecoration(
                          labelText: 'Interest Rate (e.g., 0.05 for 5%)',
                          hintText: 'Current: ${_formatRateString(_currentInterestRateOnScreen)}',
                          border: const OutlineInputBorder(),
                          suffixIcon: _isLoading 
                              ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) 
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an interest rate.';
                          }
                          final rate = double.tryParse(value);
                          if (rate == null) {
                            return 'Invalid number format.';
                          }
                          if (rate < 0) {
                            return 'Interest rate cannot be negative.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Center( // Keeping the button centered as per original design
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Save Interest Rate'),
                          onPressed: _isLoading ? null : _saveInterestRate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            backgroundColor: theme.colorScheme.primary, // Button background
                            foregroundColor: theme.colorScheme.onPrimary, // Button text/icon
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), // Adjusted style
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
