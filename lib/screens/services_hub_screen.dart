import 'package:flutter/material.dart';
import 'package:home_bank/screens/transfer_money_screen.dart';
import 'package:home_bank/screens/withdraw_funds_screen.dart';
import 'package:home_bank/utils/globals.dart';
import 'add_funds_screen.dart';

// Assuming AddFundsSheet is in a separate file or you'll define it
// import 'add_funds_sheet.dart'; // Or similar

class ServicesHubScreen extends StatelessWidget {
  const ServicesHubScreen({super.key});

  void _navigateToAddFunds(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFundsScreen()),
    ).then((result) {
      // This 'then' block will execute when AddFundsScreen is popped.
      // 'result' will be the value passed to Navigator.pop(context, result)
      // from AddFundsScreen. We set it to 'true' on successful fund addition.
      if (result == true && context.mounted) {
        // Optional: Refresh data if needed, e.g., if this screen shows a balance
        // context.read<BankFacade>().fetchLatestBalance(); // Example
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Funds action completed successfully.')), // Updated message
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
                  Text('Funds withdrawn successfully.')), // Specific message
        );
        logger.d("Withdraw Funds screen popped with success.");
      } else if (context.mounted) {
        // Ensure context is mounted
        logger.d(
            "Withdraw Funds screen popped (no action, failed, or cancelled).");
        // Optionally, show a generic message if needed, or nothing
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Withdraw funds action concluded.')),
        // );
      }
    });
    logger.d("Navigating to Withdraw Funds Screen");
  }

  void _navigateToPayments(BuildContext context) {
    logger.d("Navigate to Payments");
    // TODO: Implement Payments screen/modal (likely involving merchant list)
    // Example: context.push('/payments-screen');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payments action (placeholder).')),
    );
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
        // Optionally, show a generic message if needed
      }
    });
    logger.d("Navigating to Transfer Money Screen");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Services'), // Clearer title
        automaticallyImplyLeading:
            false, // No back button for a tab's root screen
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
        // Consider adding foregroundColor and backgroundColor from theme
        // foregroundColor: Theme.of(context).colorScheme.onPrimary,
        // backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// Placeholder for AddFundsSheet (ensure you have your actual implementation)
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
      // TODO: Actual logic to add funds via BankFacade
      logger.d('Adding funds: ${_amountController.text}');
      Navigator.pop(context, true); // Pop with true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // For keyboard
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
            const SizedBox(height: 10), // Space for keyboard
          ],
        ),
      ),
    );
  }
}
