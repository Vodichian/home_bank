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
  bool _isLoadingConversion = false;
  String? _conversionErrorMessage;

  String? _currentRateDisplay;
  bool _isFetchingRate = false;
  final NumberFormat _rateNumberFormat = NumberFormat('#,##0.####', 'en_US');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '');

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountOrCurrencyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchAndDisplayExchangeRate();
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountOrCurrencyChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountOrCurrencyChanged() {
    final amountString = _amountController.text;
    if (amountString.isEmpty) {
      if (mounted) {
        setState(() {
          _convertedAmount = null;
          _conversionErrorMessage = null;
        });
      }
      return;
    }
    final amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      if (mounted) {
        setState(() {
          _convertedAmount = null;
          if (_conversionErrorMessage == null || _conversionErrorMessage!.isEmpty) {
             _conversionErrorMessage = 'Please enter a valid positive amount.';
          }
        });
      }
      return;
    } else {
       if (mounted) {
        setState(() {
          _conversionErrorMessage = null; 
        });
      }
    }
    _performConversion();
  }

  Future<void> _fetchAndDisplayExchangeRate() async {
    if (!mounted) return;
    setState(() {
      _isFetchingRate = true;
      _currentRateDisplay = null;
    });

    try {
      final bankFacade = Provider.of<BankFacade>(context, listen: false);
      final rateForOneUnit = await bankFacade.getCurrencyConversion(_fromCurrency, _toCurrency, 1.0);
      // Assuming getCurrencyConversion throws an error or returns a sentinel value on failure, which is caught below.
      // The direct check `if (rateForOneUnit != null)` might be redundant if the method guarantees non-null on success.
      // For robustness, especially if the API contract isn't strict or might change, keeping a check or relying on typed non-nullable return is safer.
      // Given the previous lint warning, we assume the API returns double directly or throws.
      if (mounted) {
         setState(() {
            _currentRateDisplay = '1 $_fromCurrency = ${_rateNumberFormat.format(rateForOneUnit)} $_toCurrency';
         });
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
    if (!mounted) return;
    setState(() {
      final tempFrom = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tempFrom;
      _amountController.clear();
      _convertedAmount = null;
      _conversionErrorMessage = null;
    });
    _fetchAndDisplayExchangeRate();
    _onAmountOrCurrencyChanged(); 
  }

  Future<void> _performConversion() async {
    if (!mounted) return;
    final amountString = _amountController.text;
    if (amountString.isEmpty) return; 

    final amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) return; 

    setState(() {
      _isLoadingConversion = true;
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

  Widget _buildCurrencyDropdown(String currentValue, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return DropdownButton<String>(
      value: currentValue,
      isExpanded: false, 
      underline: Container(),
      icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary, size: 28),
      selectedItemBuilder: (BuildContext context) {
        return ['USD', 'VND'].map<Widget>((String item) {
          return Center(
            child: Text(item, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          );
        }).toList();
      },
      items: ['USD', 'VND'].map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: theme.textTheme.titleMedium), 
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildInputRow(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 5, offset: const Offset(0,1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _amountController,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.hintColor.withAlpha(128)),
                border: InputBorder.none,
                prefixText: _fromCurrency == 'USD' ? '\$ ' : '₫ ',
                prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 95, 
            child: _buildCurrencyDropdown(_fromCurrency, (newValue) {
              if (newValue != null && newValue != _fromCurrency) {
                if (!mounted) return;
                setState(() {
                  _fromCurrency = newValue;
                  if (_fromCurrency == _toCurrency) {
                    _toCurrency = (newValue == 'USD' ? 'VND' : 'USD');
                  }
                });
                _fetchAndDisplayExchangeRate();
                _onAmountOrCurrencyChanged();
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputRow(BuildContext context) {
    final theme = Theme.of(context);
    String displayAmount = "0.00";
    TextStyle amountStyle = theme.textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.hintColor.withAlpha(179), // Default for non-converted, non-error state
    );

    if (_isLoadingConversion) {
      displayAmount = ""; 
      amountStyle = amountStyle.copyWith(color: theme.colorScheme.onSurface.withAlpha(128));
    } else if (_convertedAmount != null) {
      displayAmount = _currencyFormat.format(_convertedAmount);
      amountStyle = amountStyle.copyWith(color: theme.colorScheme.onSurface);
    } else if (_amountController.text.isNotEmpty && _conversionErrorMessage == null) {
       displayAmount = "0.00"; // Default if input exists but no conversion yet
    }
    // If _amountController.text is empty, displayAmount remains "0.00" and color is hintColor.withAlpha(179)

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 5, offset: const Offset(0,1))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_toCurrency == 'USD' ? '\$' : '₫'}$displayAmount',
              style: amountStyle,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 95,
            child: _buildCurrencyDropdown(_toCurrency, (newValue) {
              if (newValue != null && newValue != _toCurrency) {
                if (!mounted) return;
                setState(() {
                  _toCurrency = newValue;
                  if (_fromCurrency == _toCurrency) {
                    _fromCurrency = (newValue == 'USD' ? 'VND' : 'USD');
                  }
                });
                _fetchAndDisplayExchangeRate();
                _onAmountOrCurrencyChanged();
              }
            }),
          ),
        ],),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 8),
            Text("FROM", style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor, letterSpacing: 0.5)),
            const SizedBox(height: 6.0),
            _buildInputRow(context),
            const SizedBox(height: 12.0),
            Center(
              child: IconButton(
                icon: const Icon(Icons.swap_vert, size: 36),
                onPressed: _swapCurrencies,
                tooltip: 'Swap currencies',
                color: theme.colorScheme.primary,
                splashRadius: 28,
              ),
            ),
            const SizedBox(height: 12.0),
            Text("TO", style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor, letterSpacing: 0.5)),
            const SizedBox(height: 6.0),
            _buildOutputRow(context),
            const SizedBox(height: 20.0),
            if (_isFetchingRate)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Fetching rate... ", style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)), 
                    const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5))]),
              ))
            else if (_currentRateDisplay != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _currentRateDisplay!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor.withAlpha(204)),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(), 
            if (_conversionErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  _conversionErrorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: theme.textTheme.bodyLarge?.fontSize),
                  textAlign: TextAlign.center,
                ),
              ),
             const SizedBox(height: 8), 
          ],
        ),
      ),
    );
  }
}
