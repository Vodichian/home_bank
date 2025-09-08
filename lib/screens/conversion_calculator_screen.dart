import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:home_bank/utils/globals.dart'; // For logger
import 'package:intl/intl.dart';

class ConversionCalculatorScreen extends StatefulWidget {
  const ConversionCalculatorScreen({super.key});

  @override
  State<ConversionCalculatorScreen> createState() => _ConversionCalculatorScreenState();
}

class _ConversionCalculatorScreenState extends State<ConversionCalculatorScreen> {
  final _amountController = TextEditingController();
  String _fromCurrency = 'USD';
  String _toCurrency = 'VND';
  double? _convertedAmount;
  bool _isLoadingConversion = false; // For main conversion
  String? _conversionErrorMessage;

  // State for displaying live exchange rate
  String? _currentRateDisplay;
  bool _isFetchingRate = false;
  final NumberFormat _rateNumberFormat = NumberFormat('#,##0.####', 'en_US'); // For the rate itself
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: ''); // For displaying amounts

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Ensure widget is still in the tree
        _fetchAndDisplayExchangeRate();
      }
    });
  }

  Future<void> _fetchAndDisplayExchangeRate() async {
    if (!mounted) return;
    setState(() {
      _isFetchingRate = true;
      _currentRateDisplay = null; // Clear previous rate
    });

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      // Fetch rate for 1 unit of the _fromCurrency
      final rateForOneUnit = await bankFacade.getCurrencyConversion(_fromCurrency, _toCurrency, 1.0);
      if (mounted) {
        if (rateForOneUnit != null) {
          setState(() {
            _currentRateDisplay = '1 $_fromCurrency = ${_rateNumberFormat.format(rateForOneUnit)} $_toCurrency';
          });
        } else {
          setState(() {
            _currentRateDisplay = 'Rate not available';
          });
        }
      }
    } catch (e) {
      logger.w('Could not fetch exchange rate: $e');
      if (mounted) {
        setState(() {
          _currentRateDisplay = 'Rate not available';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingRate = false;
        });
      }
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _convertedAmount = null;
      _conversionErrorMessage = null;
      // Clear amount field or keep it? For now, let's keep it and re-calculate if user presses convert
      // _amountController.clear(); 
    });
    _fetchAndDisplayExchangeRate(); // Fetch new rate after swap
    if (_amountController.text.isNotEmpty) {
        _performConversion(); // Optionally re-convert if amount is present
    }
  }

  Future<void> _performConversion() async {
    final amountString = _amountController.text;
    if (amountString.isEmpty) {
      setState(() {
        _convertedAmount = null;
        _conversionErrorMessage = null;
      });
      return;
    }

    final amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      setState(() {
        _convertedAmount = null;
        _conversionErrorMessage = 'Please enter a valid positive amount.';
      });
      return;
    }

    setState(() {
      _isLoadingConversion = true;
      _conversionErrorMessage = null;
      _convertedAmount = null;
    });

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      final result = await bankFacade.getCurrencyConversion(_fromCurrency, _toCurrency, amount);
      if (mounted) {
        setState(() {
          _convertedAmount = result;
        });
      }
    } catch (e) {
      logger.e('Currency conversion error: $e');
      if (mounted) {
        setState(() {
          _conversionErrorMessage = 'Error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingConversion = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Widget _buildCurrencyDropdown(String currentValue, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: currentValue,
      items: ['USD', 'VND'].map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildCurrencyDropdown(_fromCurrency, (newValue) {
                  if (newValue != null && newValue != _fromCurrency) {
                    setState(() {
                      _fromCurrency = newValue;
                      if (_fromCurrency == _toCurrency) { // Auto-swap if same
                        _toCurrency = (newValue == 'USD' ? 'VND' : 'USD');
                      }
                      _convertedAmount = null; // Clear previous main conversion
                      _conversionErrorMessage = null;
                    });
                    _fetchAndDisplayExchangeRate();
                  }
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: _swapCurrencies,
                    tooltip: 'Swap currencies',
                  ),
                ),
                _buildCurrencyDropdown(_toCurrency, (newValue) {
                  if (newValue != null && newValue != _toCurrency) {
                    setState(() {
                      _toCurrency = newValue;
                      if (_fromCurrency == _toCurrency) { // Auto-swap if same
                        _fromCurrency = (newValue == 'USD' ? 'VND' : 'USD');
                      }
                      _convertedAmount = null; // Clear previous main conversion
                      _conversionErrorMessage = null;
                    });
                    _fetchAndDisplayExchangeRate();
                  }
                }),
              ],
            ),
            const SizedBox(height: 12.0),
            // Display current exchange rate
            if (_isFetchingRate)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Fetching rate... "), SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))]),
              ))
            else if (_currentRateDisplay != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _currentRateDisplay!,
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount to Convert',
                prefixText: _fromCurrency == 'USD' ? '\$ ' : '₫ ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                 if (value.isEmpty) {
                  setState(() {
                    _convertedAmount = null;
                    _conversionErrorMessage = null;
                  });
                } else {
                  // Optionally trigger conversion on text change with debounce, or rely on button
                }
              },
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _isLoadingConversion ? null : _performConversion,
              child: _isLoadingConversion ? const SizedBox(height:20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Convert'),
            ),
            const SizedBox(height: 24.0),
            if (_convertedAmount != null)
              Text(
                'Converted Amount: ${_toCurrency == 'USD' ? '\$' : '₫'}${_currencyFormat.format(_convertedAmount)} $_toCurrency',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            if (_conversionErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _conversionErrorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
