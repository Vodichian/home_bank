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

  late double _currentInterestRateOnScreen;

  // State for Accrued Interest
  double? _accruedInterest;
  bool _isFetchingInterest = true; // Initialize to true
  String? _fetchInterestError;

  String _formatRateString(double rate) {
    String asString = rate.toString();
    if (asString.contains('.')) {
      asString = asString.replaceAll(RegExp(r'0*$'), '');
      if (asString.endsWith('.')) {
        asString = asString.substring(0, asString.length - 1);
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
    _fetchAccruedInterest(); // Fetch accrued interest
  }

  Future<void> _fetchAccruedInterest() async {
    if (!mounted) return;
    setState(() {
      _isFetchingInterest = true;
      _fetchInterestError = null; 
    });
    try {
      final interest = await _bankFacade.getInterestAccrued(
        ownerUserId: widget.savingsAccount.owner.userId,
      );
      if (mounted) {
        setState(() {
          _accruedInterest = interest;
          _isFetchingInterest = false;
        });
      }
    } catch (e) {
      logger.e("Error fetching accrued interest for user ${widget.savingsAccount.owner.userId}: $e");
      if (mounted) {
        setState(() {
          _fetchInterestError = "Failed to load interest: ${e.toString()}";
          _isFetchingInterest = false;
        });
      }
    }
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
      final success = await _bankFacade.updateInterestRate(
        widget.savingsAccount.accountNumber,
        newRate,
      );
      if (mounted) {
        if (success) {
          _currentInterestRateOnScreen = newRate;
          _interestRateController.text = _formatRateString(newRate);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Interest rate updated successfully!')),
          );
        } else {
          _interestRateController.text = _formatRateString(_currentInterestRateOnScreen);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update interest rate. Server reported failure.')),
          );
        }
      }
    } catch (e) {
      logger.e("Error updating interest rate: $e", error: e);
       if (mounted) {
        _interestRateController.text = _formatRateString(_currentInterestRateOnScreen);
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

    Color balanceColor;
    if (account.balance > 0) {
      balanceColor = Colors.green;
    } else if (account.balance < 0) {
      balanceColor = Colors.red;
    } else {
      balanceColor = theme.textTheme.bodyMedium?.color ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
    }
    final TextStyle balanceTextStyle = theme.textTheme.bodyMedium!.copyWith(
      color: balanceColor,
      fontWeight: FontWeight.bold,
    );

    Color interestRateHintColor;
    if (_currentInterestRateOnScreen > 0) {
      interestRateHintColor = Colors.green;
    } else if (_currentInterestRateOnScreen < 0) {
      interestRateHintColor = Colors.red;
    } else {
      interestRateHintColor = theme.hintColor;
    }

    String accruedInterestDisplayValue;
    TextStyle accruedInterestTextStyle;
    if (_isFetchingInterest) {
      accruedInterestDisplayValue = "Calculating...";
      accruedInterestTextStyle = theme.textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic);
    } else if (_fetchInterestError != null) {
      accruedInterestDisplayValue = _fetchInterestError!;
      accruedInterestTextStyle = theme.textTheme.bodyMedium!.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.bold);
    } else if (_accruedInterest != null) {
      accruedInterestDisplayValue = currencyFormat.format(_accruedInterest);
      Color accruedValueColor;
      if (_accruedInterest! > 0) {
        accruedValueColor = Colors.green;
      } else if (_accruedInterest! < 0) {
        accruedValueColor = Colors.red;
      } else {
        accruedValueColor = theme.textTheme.bodyMedium?.color ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
      }
      accruedInterestTextStyle = theme.textTheme.bodyMedium!.copyWith(
        color: accruedValueColor,
        fontWeight: FontWeight.bold,
      );
    } else {
      accruedInterestDisplayValue = "N/A";
      accruedInterestTextStyle = theme.textTheme.bodyMedium!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account Details'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildInfoTile('Nickname:', account.nickname.isNotEmpty ? account.nickname : 'N/A'),
                      _buildInfoTile('Owner:', '${account.owner.fullName} (${account.owner.username})'),
                      _buildInfoTile('Account Number:', account.accountNumber.toString()),
                      _buildInfoTile('Owner Is Admin:', account.owner.isAdmin.toString()),
                      _buildInfoTile(
                        'Balance:',
                        currencyFormat.format(account.balance),
                        specificValueStyle: balanceTextStyle,
                      ),
                      _buildInfoTile(
                        'Total Accrued Interest:',
                        accruedInterestDisplayValue,
                        specificValueStyle: accruedInterestTextStyle,
                      ),
                      _buildInfoTile('Created:', dateFormat.format(account.created)),
                      _buildInfoTile(
                        'Last Interest Accrued On:',
                        account.lastInterestAccruedDate != null
                            ? dateFormat.format(account.lastInterestAccruedDate!)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextFormField(
                        controller: _interestRateController,
                        decoration: InputDecoration(
                          labelText: 'Interest Rate (e.g., 0.05 for 5%)',
                          labelStyle: TextStyle(color: theme.colorScheme.primary),
                          hintText: 'Current: ${_formatRateString(_currentInterestRateOnScreen)}',
                          hintStyle: TextStyle(color: interestRateHintColor),
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
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_alt_outlined),
                          label: const Text('Save Interest Rate'),
                          onPressed: _isLoading ? null : _saveInterestRate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
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

  Widget _buildInfoTile(String label, String value, {TextStyle? specificValueStyle}) {
    final theme = Theme.of(context);
    TextStyle? finalValueStyle;
    if (specificValueStyle != null) {
      finalValueStyle = specificValueStyle;
    } else if (label == 'Owner:') {
      finalValueStyle = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      );
    } else {
      finalValueStyle = theme.textTheme.bodyMedium;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: finalValueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
