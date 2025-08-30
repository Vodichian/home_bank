import 'package:bank_server/bank.dart';
import 'package:flutter/material.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:home_bank/utils/globals.dart'; // For logger

// Enum for Admin Status Filter
enum AdminStatusFilter { all, admin, nonAdmin }

class InvestmentOversightScreen extends StatefulWidget {
  const InvestmentOversightScreen({super.key});

  @override
  State<InvestmentOversightScreen> createState() =>
      _InvestmentOversightScreenState();
}

class _InvestmentOversightScreenState extends State<InvestmentOversightScreen> {
  late BankFacade _bankFacade;
  Stream<List<SavingsAccount>>? _allAccountsStream;
  List<SavingsAccount> _allAccounts = []; // To store all accounts from the stream

  // --- Filter State Variables ---
  final TextEditingController _nameSearchController = TextEditingController();

  final Map<String, AdminStatusFilter> _adminStatusOptions = {
    'All Users': AdminStatusFilter.all,
    'Admins Only': AdminStatusFilter.admin,
    'Non-Admins Only': AdminStatusFilter.nonAdmin,
  };
  late String _selectedAdminStatusDisplay;

  bool _isFilterPanelExpanded = false;
  // --- End Filter State Variables ---

  @override
  void initState() {
    super.initState();
    _bankFacade = Provider.of<BankFacade>(context, listen: false);
    _selectedAdminStatusDisplay = _adminStatusOptions.keys.first; // Default

    _nameSearchController.addListener(() {
      if (mounted) {
        setState(() {}); // Trigger rebuild to apply filters
      }
    });

    _fetchAccounts();
  }

  @override
  void dispose() {
    _nameSearchController.removeListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _nameSearchController.dispose();
    super.dispose();
  }

  void _fetchAccounts() {
    if (!mounted) return;
    logger.i("InvestmentOversight: Initializing savings accounts stream.");
    try {
      setState(() {
        _allAccountsStream = _bankFacade.listenAllSavingsAccounts();
      });
    } catch (e, s) {
      logger.e("Error initiating account stream: $e", stackTrace: s);
      if (mounted) {
        setState(() {
          _allAccountsStream = Stream.error(e);
        });
      }
    }
  }

  List<SavingsAccount> _calculateFilteredAccounts(List<SavingsAccount> accounts) {
    List<SavingsAccount> tempFilteredList = List.from(accounts);

    // Filter by name
    final String searchTerm = _nameSearchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((account) {
        return account.owner.fullName.toLowerCase().contains(searchTerm) ||
               account.owner.username.toLowerCase().contains(searchTerm);
      }).toList();
    }

    // Filter by admin status
    final AdminStatusFilter selectedStatus =
        _adminStatusOptions[_selectedAdminStatusDisplay]!;
    if (selectedStatus != AdminStatusFilter.all) {
      tempFilteredList = tempFilteredList.where((account) {
        final bool isAdmin = account.owner.isAdmin;
        return selectedStatus == AdminStatusFilter.admin ? isAdmin : !isAdmin;
      }).toList();
    }
    // Log filter application outside of setState, if needed for debugging,
    // but avoid logging excessively during build phases.
    // logger.i(
    //     "InvestmentOversight: Calculated filters. Name: '$searchTerm', AdminStatus: '$selectedStatus'. Found ${tempFilteredList.length} of ${accounts.length} accounts.");
    return tempFilteredList;
  }

  void _resetFilters() {
    _nameSearchController.clear(); // Listener will call setState
    setState(() {
      _selectedAdminStatusDisplay = _adminStatusOptions.keys.first;
    });
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
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.9),
          headerBuilder: (BuildContext context, bool isExpanded) {
            return ListTile(
              title: Text('Filters',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              leading: Icon(Icons.filter_list_alt,
                  color: theme.colorScheme.primary),
            );
          },
          body: Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextFormField(
                  controller: _nameSearchController,
                  decoration: InputDecoration(
                    labelText: 'Filter by Name/Username',
                    hintText: 'e.g., Jane Doe, jdoe',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.canvasColor,
                    suffixIcon: _nameSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _nameSearchController.clear();
                              // Listener will call setState
                            },
                          )
                        : null,
                  ),
                  // No onEditingComplete needed if listener handles it, or add setState here too
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Admin Status',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.canvasColor,
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                  value: _selectedAdminStatusDisplay,
                  items: _adminStatusOptions.keys.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedAdminStatusDisplay = newValue;
                      });
                    }
                  },
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Savings Accounts'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildFilterPanel(),
          ),
          Expanded(
            child: StreamBuilder<List<SavingsAccount>>(
              stream: _allAccountsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _allAccounts.isEmpty && !snapshot.hasError) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  logger.e(
                      "InvestmentOversightScreen: Error in stream: ${snapshot.error}",
                      stackTrace: snapshot.stackTrace);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading accounts: ${snapshot.error}',
                        style: TextStyle(color: colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasData) {
                  _allAccounts = snapshot.data!;
                   // Log if needed for debugging, but be mindful of build frequency
                  // logger.d("InvestmentOversightScreen: Stream has new data. ${_allAccounts.length} total accounts.");
                }

                final List<SavingsAccount> filteredAccounts = _calculateFilteredAccounts(_allAccounts);
                
                if (_allAccounts.isNotEmpty && filteredAccounts.isEmpty && (_nameSearchController.text.isNotEmpty || _selectedAdminStatusDisplay != _adminStatusOptions.keys.first) ) {
                   return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No accounts match your current filters.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                          ),
                           const SizedBox(height: 8),
                          Text(
                            'Try adjusting or resetting your filters.',
                            textAlign: TextAlign.center,
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // This condition covers the case where the stream is done/active but emitted an empty list,
                // or if it hasn't emitted yet but also isn't waiting or in error.
                if (_allAccounts.isEmpty && snapshot.connectionState != ConnectionState.waiting && !snapshot.hasError) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty_rounded, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No savings accounts found.'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredAccounts.length,
                  itemBuilder: (context, index) {
                    final account = filteredAccounts[index];
                    return SavingsAccountListItem(
                      key: ValueKey(account.accountNumber),
                      account: account,
                      bankFacade: _bankFacade,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SavingsAccountListItem extends StatefulWidget {
  final SavingsAccount account;
  final BankFacade bankFacade;

  const SavingsAccountListItem({
    super.key,
    required this.account,
    required this.bankFacade,
  });

  @override
  State<SavingsAccountListItem> createState() => _SavingsAccountListItemState();
}

class _SavingsAccountListItemState extends State<SavingsAccountListItem> {
  double? _interestAccrued;
  bool _isLoadingInterest = true;
  String? _interestError;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _percentFormat =
      NumberFormat.percentPattern('en_US'); // For percentage formatting

  @override
  void initState() {
    super.initState();
    _fetchInterest();
  }

   @override
  void didUpdateWidget(SavingsAccountListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account.accountNumber != oldWidget.account.accountNumber) {
      _fetchInterest(); // Refetch if the account itself changes
    }
  }

  Future<void> _fetchInterest() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInterest = true;
      _interestError = null;
    });
    try {
      final interest = await widget.bankFacade.getInterestAccrued(
        ownerUserId: widget.account.owner.userId,
      );
      if (mounted) {
        setState(() {
          _interestAccrued = interest;
          _isLoadingInterest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // logger.w("Failed to load interest for ${widget.account.owner.userId}: $e");
        setState(() {
          _interestError = 'Failed to load interest';
          _isLoadingInterest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: widget.account.owner.isAdmin 
              ? colorScheme.primaryContainer 
              : colorScheme.secondaryContainer,
          foregroundColor: widget.account.owner.isAdmin
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSecondaryContainer,
          child: Icon(widget.account.owner.isAdmin 
              ? Icons.admin_panel_settings 
              : Icons.account_balance_wallet_outlined),
        ),
        title: Text(
          'Holder: ${widget.account.owner.fullName} ${widget.account.owner.isAdmin ? "(Admin)" : ""}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Username: ${widget.account.owner.username}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            Text(
              'Balance: ${_currencyFormat.format(widget.account.balance)}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withOpacity(0.8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Interest Rate: ${_percentFormat.format(widget.account.interestRate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
            if (_isLoadingInterest)
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text("Loading interest...", style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            else if (_interestError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _interestError!,
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              )
            else if (_interestAccrued != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Interest Accrued (Total): ${_currencyFormat.format(_interestAccrued)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: colorScheme.primary,
        ),
        onTap: () {
          // TODO: Implement navigation to account details screen or other action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tapped on account for user ID: ${widget.account.owner.userId}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}
