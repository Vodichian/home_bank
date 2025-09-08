import 'package:flutter/material.dart';
import 'package:home_bank/bank/bank_facade.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CurrencyToggleWidget extends StatefulWidget {
  final double amount;
  final TextStyle? style;

  const CurrencyToggleWidget({
    super.key,
    required this.amount,
    this.style,
  });

  @override
  State<CurrencyToggleWidget> createState() => _CurrencyToggleWidgetState();
}

class _CurrencyToggleWidgetState extends State<CurrencyToggleWidget> {
  bool _isVnd = false;
  double? _convertedAmount;
  bool _isLoading = false;

  final NumberFormat _usdFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _vndFormat =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  Future<void> _toggleCurrency() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    if (!_isVnd && _convertedAmount == null) {
      final bankFacade = context.read<BankFacade>();
      try {
        final result = await bankFacade.getCurrencyConversion(
            'USD', 'VND', widget.amount);
        if (mounted) {
          setState(() {
            _convertedAmount = result;
          });
        }
      } catch (e) {
        // Handle error, maybe show a snackbar
      }
    }

    if (mounted) {
      setState(() {
        _isVnd = !_isVnd;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountStyle = widget.style?.copyWith(fontWeight: FontWeight.bold) ??
        const TextStyle(fontWeight: FontWeight.bold);

    final String displayText;
    if (_isVnd) {
      displayText =
          _convertedAmount != null ? _vndFormat.format(_convertedAmount) : '...';
    } else {
      displayText = _usdFormat.format(widget.amount);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayText,
          style: amountStyle,
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: _toggleCurrency,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    children: [
                      Text(
                        _isVnd ? 'VND' : 'USD',
                        style: widget.style
                            ?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_vert,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
