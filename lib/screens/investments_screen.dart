import 'dart:async'; // Make sure this is imported
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:home_bank/widgets/currency_toggle_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:bank_server/bank.dart'; // Your models
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // Your logger

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  late BankFacade _bankFacade;
  Stream<SavingsAccount>? _savingsAccountStream;
  double? _interestYTD;
  bool _isLoadingInterestYTD = false;
  Map<DateTime, double>? _balanceHistory;
  Map<DateTime, double>? _interestHistory;
  bool _isLoadingHistory = false;
  bool _isLoadingInterestHistory = false;
  final _formatter = NumberFormat('#,##0', 'en_US');

  // final int _historyPeriodInDays = 30;
  int _selectedHistoryPeriodInDays = 30; // Default value is 30 days

  void _onSelectHistoryPeriod(int? period) {
    if (period != null) {
      setState(() {
        _selectedHistoryPeriodInDays = period;
      });
      _fetchBalanceHistory();
      _fetchInterestHistory();
    }
  }

  // No longer need _savingsAccountSubscription for this stream
  // StreamSubscription<SavingsAccount>? _savingsAccountSubscription;

  SavingsAccount?
      _currentSavingsAccountData; // To hold the latest data from stream

  @override
  void initState() {
    super.initState();
    _bankFacade = context.read<BankFacade>();
    _initializeStream(); // Just initialize the stream, don't listen here
    _fetchBalanceHistory();
    _fetchInterestHistory();
  }

  void _initializeStream() {
    // It's important to handle potential errors from listenSavingsAccount,
    // especially AuthenticationError if the user is not logged in when
    // this screen is initialized.
    try {
      setState(() {
        _savingsAccountStream = _bankFacade.listenSavingsAccount();
      });
    } catch (e) {
      logger.e("Error initializing savings account stream: $e");
      // Handle error, e.g., show a message or navigate away
      // For now, StreamBuilder's error handling will catch issues from the stream itself.
      // If the error is from the synchronous part of listenSavingsAccount (like auth check),
      // you might want to handle it more directly here.
      if (mounted && e is AuthenticationError) {
        // Example: Navigate to login if not authenticated
        // context.go('/login');
        // Or set an error state to be displayed by the build method
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Error: ${e.message}')),
        );
      }
    }
  }

  // This method will now be called from the StreamBuilder's builder when data arrives
  Future<void> _fetchInterestYTD(int ownerUserId) async {
    if (mounted) {
      setState(() {
        _isLoadingInterestYTD = true;
        // Keep existing _interestYTD or clear it, depending on desired UX
        // _interestYTD = null; // Option: Clear previous value while loading new one
      });
    }

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      if (_bankFacade.currentUser == null) {
        throw AuthenticationError(
            "Cannot fetch interest YTD: User not authenticated.");
      }

      final interest = await _bankFacade.getInterestAccrued(
        ownerUserId: ownerUserId,
        startDate: startOfYear,
        endDate: now,
      );
      if (mounted) {
        setState(() {
          _interestYTD = interest;
          _isLoadingInterestYTD = false;
        });
      }
    } on AuthenticationError catch (e) {
      logger.e('Authentication error fetching YTD interest: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Auth Error fetching YTD Interest: ${e.message}')),
        );
        setState(() {
          _interestYTD = null;
          _isLoadingInterestYTD = false;
        });
      }
    } catch (e) {
      logger.e('Failed to fetch YTD interest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching YTD Interest: ${e.toString()}')),
        );
        setState(() {
          _interestYTD = null;
          _isLoadingInterestYTD = false;
        });
      }
    }
  }

  Future<void> _fetchBalanceHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // TODO: Calculate days based on account creation date for a full history.
      // For now, we'll just grab the last year.
      final now = DateTime.now();
      final history = await _bankFacade.getBalanceHistory(
        endDate: now,
        days: _selectedHistoryPeriodInDays,
      );

      if (mounted) {
        setState(() {
          _balanceHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      logger.e('Failed to fetch balance history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching balance history: ${e.toString()}')),
        );
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _fetchInterestHistory() async {
    setState(() {
      _isLoadingInterestHistory = true;
    });

    try {
      final now = DateTime.now();
      final history = await _bankFacade.getInterestHistory(
        endDate: now,
        days: _selectedHistoryPeriodInDays,
      );

      if (mounted) {
        setState(() {
          _interestHistory = history;
          _isLoadingInterestHistory = false;
        });
      }
    } catch (e) {
      logger.e('Failed to fetch interest history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error fetching interest history: ${e.toString()}')),
        );
        setState(() {
          _isLoadingInterestHistory = false;
        });
      }
    }
  }

  void _refreshSavingsData() {
    // Re-initialize the stream. The StreamBuilder will pick up the new stream.
    _initializeStream();
    _fetchBalanceHistory();
    _fetchInterestHistory();
    // Reset YTD interest as well, as it will be re-fetched when new stream data arrives.
    if (mounted) {
      setState(() {
        _interestYTD = null;
        _isLoadingInterestYTD =
            false; // Could set to true if you want immediate loading
        _currentSavingsAccountData = null;
      });
    }
  }

  @override
  void dispose() {
    // _savingsAccountSubscription?.cancel(); // No longer needed for _savingsAccountStream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle case where stream couldn't be initialized due to auth error in initState
    if (_savingsAccountStream == null && _bankFacade.currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Savings Account'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text("User not authenticated. Please log in.",
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Account'),
        actions: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 10),
                // Adjust the padding as needed
                child: Text('Period:',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              DropdownButton<int>(
                value: _selectedHistoryPeriodInDays,
                onChanged: (period) {
                  _onSelectHistoryPeriod(period);
                },
                items: const [
                  DropdownMenuItem(value: 7, child: Text(' 7 Days')),
                  DropdownMenuItem(value: 14, child: Text(' 14 Days')),
                  DropdownMenuItem(value: 30, child: Text(' 30 Days')),
                  DropdownMenuItem(value: 60, child: Text(' 60 Days')),
                  DropdownMenuItem(value: 90, child: Text(' 90 Days')),
                  DropdownMenuItem(value: 180, child: Text(' 180 Days')),
                  DropdownMenuItem(value: 365, child: Text(' 365 Days')),
                ],
                // style: TextStyle(
                //   color: Theme.of(context).colorScheme.onPrimary,
                //   fontSize: 16,
                // ),
                icon: Icon(Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.onPrimary),
              ),
            ],
          ),
        ],
        // backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: StreamBuilder<SavingsAccount>(
        stream: _savingsAccountStream, // Use the stream from BankFacade
        builder: (context, snapshot) {
          // 1. Check for errors from the stream
          if (snapshot.hasError) {
            String errorMessage = 'Failed to load savings account data.';
            if (snapshot.error is AuthenticationError) {
              errorMessage =
                  'Authentication Error: Please log in again. ${(snapshot.error as AuthenticationError).message}';
            } else {
              logger.e('Error in SavingsAccount stream: ${snapshot.error}');
              errorMessage += '\nDetails: ${snapshot.error.toString()}';
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (snapshot.error is AuthenticationError ||
                            _bankFacade.currentUser == null) {
                          if (mounted) context.go('/login');
                        } else {
                          _refreshSavingsData(); // Try to re-initialize the stream
                        }
                      },
                      child: Text(snapshot.error is AuthenticationError ||
                              _bankFacade.currentUser == null
                          ? 'Go to Login'
                          : 'Try Again'),
                    )
                  ],
                ),
              ),
            );
          }

          // 2. Check connection state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to Savings Account Stream...'),
                ],
              ),
            );
          }

          // 3. Check if data is available
          if (!snapshot.hasData) {
            return const Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Waiting for savings account data...'),
              ],
            ));
          }

          // 4. Data is available
          final savingsAccount = snapshot.data!;

          // --- Fetch YTD Interest when SavingsAccount data changes ---
          // Check if the current data is different from the last known data,
          // or if interest hasn't been fetched yet for this data.
          // This prevents re-fetching if the stream emits the same data multiple times.
          if (_currentSavingsAccountData?.accountNumber !=
                  savingsAccount.accountNumber || // Example: Use a unique ID
              _currentSavingsAccountData?.balance !=
                  savingsAccount.balance || // Or other relevant fields
              _interestYTD == null && !_isLoadingInterestYTD) {
            // Or if interest YTD is not yet loaded and not currently loading
            _currentSavingsAccountData = savingsAccount;
            // Post a frame callback to ensure setState for _fetchInterestYTD
            // is not called during the build phase of StreamBuilder
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Ensure widget is still mounted
                _fetchInterestYTD(_bankFacade.currentUser!.userId);
                _fetchBalanceHistory();
                _fetchInterestHistory();
              }
            });
          }
          // --- End of YTD Interest Fetch Logic ---

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshSavingsData();
              },
              child: ListView(
                children: <Widget>[
                  _buildInfoCard(
                    context,
                    isExpanded: false,
                    title: 'Account Details',
                    icon: Icons.account_balance_wallet,
                    children: [
                      _buildInfoRow(
                          title: 'Account Number:',
                          value: savingsAccount.accountNumber.toString()),
                      _buildInfoRow(title: 'Account Type:', value: 'Savings'),
                      _buildInfoRow(
                          title: 'Nickname:', value: savingsAccount.nickname),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    title: 'Balance & Interest',
                    icon: Icons.monetization_on,
                    children: [
                      _buildInfoRow(
                        title: 'Current Balance:',
                        valueWidget: CurrencyToggleWidget(
                          amount: savingsAccount.balance,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        isCurrency: true,
                      ),
                      _buildInfoRow(
                          title: 'Interest Rate:',
                          value:
                              '${(savingsAccount.interestRate * 100).toStringAsFixed(2)}%'),
                      _isLoadingInterestYTD
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Interest Earned (YTD):',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500)),
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ],
                              ),
                            )
                          : _buildInfoRow(
                              title: 'Interest Earned (YTD):',
                              valueWidget: _interestYTD != null
                                  ? CurrencyToggleWidget(
                                      amount: _interestYTD!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                    )
                                  : const Text('N/A'),
                              isCurrency: true,
                            ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    title: 'Balance History',
                    icon: Icons.show_chart,
                    children: [
                      _isLoadingHistory
                          ? const Center(child: CircularProgressIndicator())
                          : (_balanceHistory != null &&
                                  _balanceHistory!.isNotEmpty)
                              ? _buildChart(_balanceHistory!)
                              : const Text('No balance history available.'),
                    ],
                  ),
                  // ...
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    title: 'Interest History',
                    icon: Icons.show_chart,
                    children: [
                      _isLoadingInterestHistory
                          ? const Center(child: CircularProgressIndicator())
                          : (_interestHistory != null &&
                                  _interestHistory!.isNotEmpty)
                              ? _buildChart(_interestHistory!)
                              : const Text('No interest history available.'),
                    ],
                  ),
// ...
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart(Map<DateTime, double> history) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = history.entries.map((entry) {
      return FlSpot(entry.key.millisecondsSinceEpoch.toDouble(), entry.value);
    }).toList();

    final sortedTimestamps = history.keys
        .map((e) => e.millisecondsSinceEpoch.toDouble())
        .toList()
      ..sort();
    final firstTimestamp = sortedTimestamps.first;
    final lastTimestamp = sortedTimestamps.last;

    final yValues = history.values;
    final minY = yValues.reduce(min);
    final maxY = yValues.reduce(max);

    final double verticalPadding;
    if (maxY == minY) {
      verticalPadding = maxY == 0 ? 1 : (maxY * 0.1).abs();
    } else {
      verticalPadding = (maxY - minY) * 0.1;
    }
    final double paddedMinY = max(0, minY - verticalPadding);
    final double paddedMaxY = maxY + verticalPadding;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: paddedMinY,
          maxY: paddedMaxY,
          gridData: const FlGridData(show: true),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final date =
                      DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
                  return LineTooltipItem(
                    '${DateFormat.Md().format(date)}: \$${barSpot.y.toStringAsFixed(2)}',
                    const TextStyle(
                        color: Colors.white), // Style for the tooltip container
                  );
                }).toList(); // Convert Iterable to List
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  // Hide edge labels to avoid crowding
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }

                  final date =
                      DateTime.fromMillisecondsSinceEpoch(value.toInt());

                  TextAlign textAlign = TextAlign.center;
                  // Adjust alignment for the first and last labels
                  if (value.toInt() == firstTimestamp.toInt()) {
                    textAlign = TextAlign.left;
                  } else if (value.toInt() == lastTimestamp.toInt()) {
                    textAlign = TextAlign.right;
                  }

                  return SideTitleWidget(
                    meta: meta,
                    space: 8.0,
                    child: Text(DateFormat('MMM\ndd').format(date),
                        textAlign: textAlign),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    // Hide edge labels to avoid crowding
                    if (value == meta.min) {
                      return const SizedBox.shrink();
                    }

                    return SideTitleWidget(
                      meta: meta,
                      space: 8.0,
                      child: Text(
                        '\$${_formatter.format(value)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children,
      bool isExpanded = true}) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ExpansionTile(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        initiallyExpanded: isExpanded,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 20, thickness: 1),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    String? value,
    Widget? valueWidget,
    bool isCurrency = false,
  }) {
    assert(value != null || valueWidget != null,
        'Either value or valueWidget must be provided.');
    assert(value == null || valueWidget == null,
        'Cannot provide both value and valueWidget.');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          if (valueWidget != null)
            valueWidget
          else
            Text(
              value!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isCurrency ? FontWeight.bold : FontWeight.normal,
                color:
                    isCurrency ? Theme.of(context).colorScheme.secondary : null,
              ),
            ),
        ],
      ),
    );
  }
}
