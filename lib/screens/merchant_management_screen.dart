import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart';

class MerchantManagementScreen extends StatefulWidget {
  const MerchantManagementScreen({super.key});

  @override
  State<MerchantManagementScreen> createState() =>
      _MerchantManagementScreenState();
}

class _MerchantManagementScreenState extends State<MerchantManagementScreen> {
  late BankFacade _bankFacade;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();

    // Initial check (though GoRouter redirect handles primary guarding)
    final currentUser = _bankFacade.currentUser;
    if (currentUser == null || !currentUser.isAdmin) {
      logger.w(
          "MerchantManagementScreen accessed or built without admin privileges. Should be prevented by GoRouter redirect.");
      // Fallback redirect if accessed directly without going through router guards
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_bankFacade.currentUser == null) {
            context.go('/login');
          } else if (!_bankFacade.currentUser!.isAdmin) {
            context.go('/home');
          }
        }
      });
    }
  }

  void _showMerchantFormDialog({Merchant? merchantToEdit}) {
    final isEditing = merchantToEdit != null;
    final nameController =
        TextEditingController(text: merchantToEdit?.name ?? '');
    final descriptionController =
        TextEditingController(text: merchantToEdit?.description ?? '');
    // Account number is usually assigned by the server and not editable
    // Balance is managed by transactions, not directly edited here.

    final formKey = GlobalKey<FormState>();

    final adminUser = _bankFacade.currentUser;
    if (adminUser == null || !adminUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Admin privileges required to manage merchants.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isEditing
              ? 'Edit Merchant: ${merchantToEdit.name}'
              : 'Create New Merchant'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Merchant Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Merchant name cannot be empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Description cannot be empty';
                      }
                      return null;
                    },
                  ),
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        "Account Number: ${merchantToEdit.accountNumber}\nBalance: \$${merchantToEdit.balance.toStringAsFixed(2)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text(isEditing ? 'Save Changes' : 'Create Merchant'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    final name = nameController.text;
                    final description = descriptionController.text;

                    if (isEditing) {
                      final updatedMerchant = Merchant(
                        accountNumber: merchantToEdit.accountNumber,
                        name: name,
                        description: description,
                        createdAt: merchantToEdit.createdAt,
                        balance: merchantToEdit.balance,
                      );
                      // TODO: Implement BankFacade.updateMerchant method
                      await _bankFacade.updateMerchant(updatedMerchant);
                      logger.i(
                          "Merchant ${updatedMerchant.name} updated successfully by ${adminUser.username}.");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Merchant ${updatedMerchant.name} updated.')),
                        );
                      }
                    } else {
                      await _bankFacade.createMerchant(name, description);
                      logger.i(
                          "Merchant $name created successfully by ${adminUser.username}.");
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Merchant $name created.')),
                        );
                      }
                    }
                    if (context.mounted) {
                      Navigator.of(dialogContext).pop(); // Close dialog
                    }
                  } catch (e) {
                    logger.e(
                        "Error saving merchant by ${adminUser.username}: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteMerchant(Merchant merchantToDelete) {
    final adminUser = _bankFacade.currentUser;
    if (adminUser == null || !adminUser.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin privileges required.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete merchant "'
              '${merchantToDelete.name}" (Account: '
              '${merchantToDelete.accountNumber})? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  await _bankFacade.deleteMerchant(merchantToDelete);
                  logger.i(
                      "Merchant ${merchantToDelete.name} deleted successfully by ${adminUser.username}.");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Merchant ${merchantToDelete.name} deleted.')),
                    );
                  }
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop(); // Close confirm dialog
                  }
                } catch (e) {
                  logger.e(
                      "Error deleting merchant ${merchantToDelete.name} by ${adminUser.username}: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _bankFacade.currentUser;
    if (currentUser == null || !currentUser.isAdmin) {
      // ... (access denied widget remains the same)
    }

    final ThemeData theme = Theme.of(context); // Get theme for styling

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Management'),
      ),
      body: StreamBuilder<List<Merchant>>(
        stream: _bankFacade.merchants(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            logger.e("Error fetching merchants: ${snapshot.error}");
            return Center(
                child: Text('Error loading merchants: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No merchants found.'));
          }

          final merchants = snapshot.data!;

          // Using ListView.builder with padding for Cards
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            // Add padding around the list for cards
            itemCount: merchants.length,
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              return Card(
                elevation: 3, // Add some shadow
                margin: const EdgeInsets.symmetric(
                    vertical: 8.0, horizontal: 4.0), // Margin for each card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0), // Rounded corners
                ),
                child: InkWell(
                  // Make the whole card tappable for editing
                  onTap: () =>
                      _showMerchantFormDialog(merchantToEdit: merchant),
                  borderRadius: BorderRadius.circular(10.0),
                  // Match card's border radius
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                merchant.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Balance prominently displayed
                            Text(
                              '\$${merchant.balance.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: merchant.balance >= 0
                                    ? theme
                                        .colorScheme.primary // Or Colors.green
                                    : theme.colorScheme.error, // Or Colors.red
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Description made more prominent
                        if (merchant.description.isNotEmpty)
                          Text(
                            merchant.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.85),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            'No description provided.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Created: ${merchant.createdAt.toLocal().toString().substring(0, 10)}', // Just date
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Edit Merchant',
                                  color: theme.colorScheme.secondary,
                                  onPressed: () => _showMerchantFormDialog(
                                      merchantToEdit: merchant),
                                  padding: EdgeInsets.zero,
                                  // Reduce default padding
                                  constraints:
                                      const BoxConstraints(), // Reduce default constraints
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete,
                                      size: 20, color: theme.colorScheme.error),
                                  tooltip: 'Delete Merchant',
                                  onPressed: () =>
                                      _confirmDeleteMerchant(merchant),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMerchantFormDialog(),
        tooltip: 'Create New Merchant',
        child: const Icon(Icons.add),
      ),
    );
  }
}
