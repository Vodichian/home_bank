import 'package:flutter/material.dart';
import 'package:home_bank/screens/conversion_calculator_screen.dart'; // Added import
import 'package:home_bank/screens/payment_screen.dart';
import 'package:home_bank/screens/transfer_money_screen.dart';
import 'package:home_bank/screens/withdraw_funds_screen.dart';
import 'package:home_bank/utils/globals.dart';
import 'add_funds_screen.dart';

class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  void _navigateToAddFunds(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFundsScreen()),
    ).then((result) {
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Funds action completed successfully.')), 
        );
        logger.d("Add Funds screen popped with success.");
      } else {
        logger.d("Add Funds screen popped (no action or failed).");
      }
    });
    logger.d("Navigating to Add Funds Screen");
  }

  void _navigateToWithdraw(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WithdrawFundsScreen()),
    ).then((result) {
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Funds withdrawn successfully.')), 
        );
        logger.d("Withdraw Funds screen popped with success.");
      } else if (context.mounted) {
        logger.d(
            "Withdraw Funds screen popped (no action, failed, or cancelled).");
      }
    });
    logger.d("Navigating to Withdraw Funds Screen");
  }

  void _navigateToPayments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentScreen()), 
    ).then((result) {
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment action completed successfully.')),
        );
        logger.d("Payment screen popped with success.");
      } else if (context.mounted) {
        logger.d("Payment screen popped (no action, failed, or cancelled).");
      }
    });
    logger.d("Navigating to Payment Screen");
  }

  void _navigateToTransfer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransferMoneyScreen()),
    ).then((result) {
      if (result == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Money transfer action completed successfully.')),
        );
        logger.d("Transfer Money screen popped with success.");
      } else if (context.mounted) {
        logger.d(
            "Transfer Money screen popped (no action, failed, or cancelled).");
      }
    });
    logger.d("Navigating to Transfer Money Screen");
  }

  // New navigation method
  void _navigateToCurrencyConverter(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConversionCalculatorScreen()),
    ).then((_) { // No specific result handling needed for now
      logger.d("Currency Converter screen popped.");
    });
    logger.d("Navigating to Currency Converter Screen");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Services'), 
        automaticallyImplyLeading:
            false, 
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            _ServiceButton(
              icon: Icons.add_circle_outline,
              label: 'Add Funds',
              onTap: () => _navigateToAddFunds(context),
            ),
            const SizedBox(height: 16),
            _ServiceButton(
              icon: Icons.remove_circle_outline,
              label: 'Withdraw Funds',
              onTap: () => _navigateToWithdraw(context),
            ),
            const SizedBox(height: 16),
            _ServiceButton(
              icon: Icons.payment,
              label: 'Make a Payment',
              onTap: () => _navigateToPayments(context),
            ),
            const SizedBox(height: 16),
            _ServiceButton(
              icon: Icons.swap_horiz,
              label: 'Transfer Money',
              onTap: () => _navigateToTransfer(context),
            ),
            const SizedBox(height: 16), // Added space
            _ServiceButton(
              icon: Icons.currency_exchange, // New button
              label: 'Currency Converter',
              onTap: () => _navigateToCurrencyConverter(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 18)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class AddFundsSheet extends StatefulWidget {
  const AddFundsSheet({super.key});

  @override
  State<AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<AddFundsSheet> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      logger.d('Adding funds: ${_amountController.text}');
      Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, 
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Add Funds', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount.';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid positive amount.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Confirm'),
            ),
            const SizedBox(height: 10), 
          ],
        ),
      ),
    );
  }
}
