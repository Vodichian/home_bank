// lib/screens/transaction_browser_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bank_server/bank.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // For logger
import 'package:intl/intl.dart'; // For date formatting

// Option B: Define a Client-Side Enum (for client-side type safety and clarity)
enum ClientTransactionType {
  addFunds,
  withdrawal,
  payment,
  transfer,
  // Add any other types you might want to filter by,
  // ensuring their names match what the server might expect as strings.
}

/// Converts a ClientTransactionType to the String format expected by the server.
/// Returns null if the input type is null.
String? clientTransactionTypeToString(ClientTransactionType? type) {
  if (type == null) return null;
  // This relies on the enum value's name matching the server string.
  // e.g., ClientTransactionType.addFunds.name will be "addFunds".
  return type.name;
}

// If you need to map from server strings back to ClientTransactionType (e.g., for display):
ClientTransactionType? clientTransactionTypeFromString(String? typeString) {
  if (typeString == null) return null;
  try {
    return ClientTransactionType.values.firstWhere((e) => e.name == typeString);
  } catch (e) {
    // Handle cases where the string from the server doesn't match any client enum
    // This might happen if the server introduces a new type the client doesn't know about.
    // You could log this or return a default/unknown type.
    logger
        .e('Warning: Unknown transaction type string from server: $typeString');
    return null;
  }
}

/// A widget to display a list of transactions.
class TransactionBrowserScreen extends StatefulWidget {
  const TransactionBrowserScreen({super.key});

  @override
  State<TransactionBrowserScreen> createState() =>
      _TransactionBrowserScreenState();
}

class _TransactionBrowserScreenState extends State<TransactionBrowserScreen> {
  late BankFacade _bankFacade;
  Stream<List<BankTransaction>>? _transactionsStream;
  TransactionQueryParameters _currentQuery =
      TransactionQueryParameters(); // Initial empty query

  // --- Filter State Variables ---
  final TextEditingController _searchController = TextEditingController();

  // For TransactionType Dropdown (using ClientTransactionType)
  final Map<String, ClientTransactionType?> _clientTransactionTypeOptions = {
    'All Types': null,
    // User-friendly display text maps to null (no filter) or an enum value
    'Add Funds': ClientTransactionType.addFunds,
    'Withdrawal': ClientTransactionType.withdrawal,
    'Payment': ClientTransactionType.payment,
    'Transfer': ClientTransactionType.transfer,
  };
  late String
      _selectedTransactionTypeDisplay; // Holds the selected display string, e.g., "Add Funds"

  // For TransactionSortField Dropdown
  final Map<String, TransactionSortField?> _sortFieldOptions = {
    'Default (Date)': TransactionSortField.date, // Or whatever your default is
    'Source User': TransactionSortField.sourceUser,
    'Target User': TransactionSortField.targetUser,
    'Merchant': TransactionSortField.merchant,
    'Amount': TransactionSortField.amount,
    'Transaction Type': TransactionSortField.transactionType,
    'No Sort': null,
  };
  late String _selectedSortFieldDisplay;

  // For SortDirection Dropdown
  final Map<String, SortDirection?> _sortDirectionOptions = {
    'Descending': SortDirection.descending,
    'Ascending': SortDirection.ascending,
    'Default Direction': null, // Or your default
  };
  late String _selectedSortDirectionDisplay;

  // --- End Filter State Variables ---

  bool _isFilterPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();

    // Initialize selected display values for filters
    _selectedTransactionTypeDisplay =
        _clientTransactionTypeOptions.keys.first; // Default to "All Types"
    _selectedSortFieldDisplay = _sortFieldOptions.keys.first; // Default sort
    _selectedSortDirectionDisplay =
        _sortDirectionOptions.keys.first; // Default direction

    _searchController.addListener(() {
      _applyFiltersAndFetch();
    });

    _applyFiltersAndFetch(); // Initial fetch with default filters
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFiltersAndFetch() {
    final ClientTransactionType? selectedClientType =
        _clientTransactionTypeOptions[_selectedTransactionTypeDisplay];
    final TransactionSortField? selectedSortField =
        _sortFieldOptions[_selectedSortFieldDisplay];
    final SortDirection? selectedSortDirection =
        _sortDirectionOptions[_selectedSortDirectionDisplay];

    _currentQuery = TransactionQueryParameters(
      searchString:
          _searchController.text.isNotEmpty ? _searchController.text : null,
      transactionType: clientTransactionTypeToString(selectedClientType),
      sortBy: selectedSortField,
      sortDirection: selectedSortDirection,
      limit: 50, // Default limit, can be made configurable
    );
    _fetchTransactions();
  }

  void _fetchTransactions() {
    if (!mounted) return;
    logger.i(
        "TransactionBrowser: Fetching transactions with query: ${_currentQuery.toJson()}");
    setState(() {
      _transactionsStream = _bankFacade.searchTransactions(_currentQuery);
    });
  }

  void _resetFilters() {
    _searchController.clear(); // Listener will call _applyFiltersAndFetch
    setState(() {
      _selectedTransactionTypeDisplay =
          _clientTransactionTypeOptions.keys.first;
      _selectedSortFieldDisplay = _sortFieldOptions.keys.first;
      _selectedSortDirectionDisplay = _sortDirectionOptions.keys.first;
    });
    // Explicitly call if _searchController.clear() doesn't trigger it (e.g., if listener is removed/changed)
    _applyFiltersAndFetch();
  }

  Widget _buildFilterPanel() {
    ThemeData theme = Theme.of(context);
    return ExpansionPanelList(
      elevation: 2,
      expandedHeaderPadding: EdgeInsets.zero,
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          _isFilterPanelExpanded = !_isFilterPanelExpanded;
        });
      },
      children: [
        ExpansionPanel(
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text('Filters & Sorting',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              leading:
                  Icon(Icons.filter_list_alt, color: theme.colorScheme.primary),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Notes / Details',
                    hintText: 'e.g., Groceries, John Doe',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.canvasColor,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              // _applyFiltersAndFetch will be called by listener
                            },
                          )
                        : null,
                  ),
                  onEditingComplete: _applyFiltersAndFetch,
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Transaction Type',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.canvasColor,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  value: _selectedTransactionTypeDisplay,
                  items: _clientTransactionTypeOptions.keys.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTransactionTypeDisplay = newValue;
                      });
                      _applyFiltersAndFetch();
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Sort By',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.canvasColor,
                          prefixIcon: const Icon(Icons.sort_by_alpha),
                        ),
                        value: _selectedSortFieldDisplay,
                        items: _sortFieldOptions.keys.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedSortFieldDisplay = newValue;
                            });
                            _applyFiltersAndFetch();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Direction',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: theme.canvasColor,
                          prefixIcon: _sortDirectionOptions[
                                      _selectedSortDirectionDisplay] ==
                                  SortDirection.ascending
                              ? const Icon(Icons.arrow_upward)
                              : const Icon(Icons.arrow_downward),
                        ),
                        value: _selectedSortDirectionDisplay,
                        items: _sortDirectionOptions.keys.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedSortDirectionDisplay = newValue;
                            });
                            _applyFiltersAndFetch();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Reset Filters'),
                    onPressed: _resetFilters,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          isExpanded: _isFilterPanelExpanded,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildFilterPanel(),
          ),
          Expanded(
            child: StreamBuilder<List<BankTransaction>>(
              stream: _transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  logger.e(
                      "TransactionBrowserScreen: Error in stream: ${snapshot.error}",
                      stackTrace: snapshot.stackTrace);
                  String errorMessage = 'Error loading transactions.';
                  if (snapshot.error is AuthenticationError) {
                    errorMessage =
                        (snapshot.error as AuthenticationError).message;
                  } else if (snapshot.error
                      .toString()
                      .contains("Failed to initiate")) {
                    errorMessage = 'Could not connect to the server.';
                  } else if (snapshot.error
                          .toString()
                          .contains("Stream broke") ||
                      snapshot.error.toString().contains("Connection lost")) {
                    errorMessage = 'Connection lost. Please try again.';
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.error, size: 48),
                          const SizedBox(height: 10),
                          Text(errorMessage,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            onPressed:
                                _applyFiltersAndFetch, // Retry the fetch with current filters
                          )
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No transactions found.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedTransactionTypeDisplay !=
                                        'All Types' ||
                                    _selectedSortFieldDisplay !=
                                        _sortFieldOptions.keys
                                            .first || // Check if default sort changed
                                    _selectedSortDirectionDisplay !=
                                        _sortDirectionOptions.keys
                                            .first // Check if default direction changed
                                ? 'Try adjusting your filters or search terms.'
                                : 'Your transaction history will appear here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _selectedTransactionTypeDisplay != 'All Types')
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: const Text('Clear Active Filters'),
                                onPressed: _resetFilters,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final transactions = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async {
                    _applyFiltersAndFetch(); // Re-fetch on pull to refresh
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      return _buildTransactionTile(tx, theme);
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(BankTransaction tx, ThemeData theme) {
    final DateFormat dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final User? currentUser =
        _bankFacade.currentUser; // Get current user for context

    bool isCurrentUserSource = false;
    bool isCurrentUserTarget = false;
    Color amountColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    String amountPrefix = '';
    String transactionTitle = 'Transaction';
    String subtitleDetails = '';

    if (currentUser != null) {
      isCurrentUserSource = tx.sourceUser.userId == currentUser.userId;
      isCurrentUserTarget = tx.targetUser?.userId == currentUser.userId;
    }

    // Determine title, subtitle, and amount color based on transaction type
    // and whether the current user is source or target
    switch (clientTransactionTypeFromString(tx.transactionType)) {
      case ClientTransactionType.addFunds:
        transactionTitle = 'Funds Added';
        amountColor = Colors.green.shade700;
        amountPrefix = '+ ';
        subtitleDetails = 'To: Your Account (Self)';
        break;
      case ClientTransactionType.withdrawal:
        transactionTitle = 'Withdrawal';
        amountColor = Colors.red.shade700;
        amountPrefix = '- ';
        subtitleDetails = 'From: Your Account (Self)';
        break;
      case ClientTransactionType.payment:
        transactionTitle = 'Payment to ${tx.merchant?.name ?? 'Merchant'}';
        if (isCurrentUserSource) {
          amountColor = Colors.red.shade700;
          amountPrefix = '- ';
          subtitleDetails = 'To: ${tx.merchant?.name ?? 'Unknown Merchant'}';
        } else {
          // This case (current user is merchant) is less likely for this app's user type
          // but included for completeness if admin views merchant transactions
          amountColor = Colors.green.shade700;
          amountPrefix = '+ ';
          subtitleDetails = 'From: ${tx.sourceUser.username}';
        }
        break;
      case ClientTransactionType.transfer:
        if (isCurrentUserSource) {
          transactionTitle = 'Transfer Sent';
          amountColor = Colors.red.shade700;
          amountPrefix = '- ';
          subtitleDetails = 'To: ${tx.targetUser?.username ?? 'Unknown User'}';
        } else if (isCurrentUserTarget) {
          transactionTitle = 'Transfer Received';
          amountColor = Colors.green.shade700;
          amountPrefix = '+ ';
          subtitleDetails = 'From: ${tx.sourceUser.username}';
        } else {
          // Admin viewing a transfer between other users
          transactionTitle = 'Transfer';
          subtitleDetails =
              'From: ${tx.sourceUser.username} To: ${tx.targetUser?.username ?? 'Unknown User'}';
        }
        break;
      default: // Should not happen if server transaction types are mapped
        transactionTitle = 'Transaction: ${tx.transactionType}';
        subtitleDetails = 'From: ${tx.sourceUser.username}';
        if (tx.targetUser != null) {
          subtitleDetails += ' To: ${tx.targetUser!.username}';
        } else if (tx.merchant != null) {
          subtitleDetails += ' To: ${tx.merchant!.name}';
        }
    }

    IconData tileIcon = Icons.swap_horiz;
    switch (clientTransactionTypeFromString(tx.transactionType)) {
      case ClientTransactionType.addFunds:
        tileIcon =
            Icons.input; // Or Icons.account_balance_wallet, Icons.add_card
        break;
      case ClientTransactionType.withdrawal:
        tileIcon = Icons.output; // Or Icons.money_off
        break;
      case ClientTransactionType.payment:
        tileIcon = Icons.payment; // Or Icons.storefront, Icons.shopping_cart
        break;
      case ClientTransactionType.transfer:
        if (isCurrentUserSource) {
          tileIcon = Icons.arrow_circle_up_outlined;
        } else if (isCurrentUserTarget) {
          tileIcon = Icons.arrow_circle_down_outlined;
        } else {
          tileIcon = Icons.compare_arrows_outlined;
        }
        break;
      default:
        tileIcon = Icons.receipt_long_outlined;
    }

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.1),
          foregroundColor: amountColor,
          child: Icon(tileIcon),
        ),
        title: Text(
          transactionTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitleDetails,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (tx.note != null && tx.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  'Notes: ${tx.note}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Text(
              dateFormat.format(tx.date!.toLocal()),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Text(
          '$amountPrefix\$${tx.amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        isThreeLine: (tx.note != null && tx.note!.isNotEmpty),
        onTap: () {
          // TODO: Implement navigation to a detailed transaction view if needed
          logger.d('Tapped on transaction: ${tx.id}');
          // Example: context.push('/transaction-details', extra: tx);
        },
      ),
    );
  }
}
