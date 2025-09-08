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
  bool _isLoading = false;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: ''); // No symbol, we add it manually

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;
      _convertedAmount = null; // Clear previous conversion
      _errorMessage = null;
      // If amount exists, trigger conversion or clear converted amount
      if (_amountController.text.isNotEmpty) {
        _performConversion();
      }
    });
  }

  Future<void> _performConversion() async {
    final amountString = _amountController.text;
    if (amountString.isEmpty) {
      setState(() {
        _convertedAmount = null;
        _errorMessage = null;
      });
      return;
    }

    final amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      setState(() {
        _convertedAmount = null;
        _errorMessage = 'Please enter a valid positive amount.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _convertedAmount = null;
    });

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      final result = await bankFacade.getCurrencyConversion(_fromCurrency, _toCurrency, amount);
      setState(() {
        _convertedAmount = result;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Currency conversion error: $e');
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
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
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount to Convert',
                prefixText: _fromCurrency == 'USD' ? '\$ ' : '₫ ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                // Optionally, could auto-convert on change with debounce
                // For now, conversion is triggered by button or currency swap
                 if (value.isEmpty) {
                  setState(() {
                    _convertedAmount = null;
                    _errorMessage = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildCurrencyDropdown(_fromCurrency, (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _fromCurrency = newValue;
                      // Ensure from and to are not the same
                      if (_fromCurrency == _toCurrency) {
                        _toCurrency = newValue == 'USD' ? 'VND' : 'USD';
                      }
                       _amountController.clear();
                      _convertedAmount = null;
                      _errorMessage = null;
                    });
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
                  if (newValue != null) {
                    setState(() {
                      _toCurrency = newValue;
                       // Ensure from and to are not the same
                      if (_fromCurrency == _toCurrency) {
                        _fromCurrency = newValue == 'USD' ? 'VND' : 'USD';
                      }
                      _amountController.clear();
                      _convertedAmount = null;
                      _errorMessage = null;
                    });
                  }
                }),
              ],
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _performConversion,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2,) : const Text('Convert'),
            ),
            const SizedBox(height: 24.0),
            if (_convertedAmount != null)
              Text(
                'Converted Amount: ${_toCurrency == 'USD' ? '\$' : '₫'}${_currencyFormat.format(_convertedAmount)} $_toCurrency',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
