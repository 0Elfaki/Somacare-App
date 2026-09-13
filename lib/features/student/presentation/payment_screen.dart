import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/bloom_components.dart';

/// Payment method options mirrored from the Bloom spec (screen 9).
enum _PayMethod { mtn, airtel, card }

/// Spec screen 9 — Payment.
///
/// Expects a route `extra` map with:
/// - `doctorName` (String)
/// - `consultFee` (int, UGX)
/// - `platformFee` (int, UGX)
/// - `onConfirm` (`Future<void> Function()`) — performs the actual booking
///   write (Supabase insert + notification). Called when the student taps Pay.
class PaymentScreen extends StatefulWidget {
  final String doctorName;
  final int consultFee;
  final int platformFee;
  final Future<void> Function() onConfirm;

  const PaymentScreen({
    super.key,
    required this.doctorName,
    required this.consultFee,
    required this.platformFee,
    required this.onConfirm,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  _PayMethod _method = _PayMethod.mtn;
  bool _isPaying = false;
  final _phoneCtrl = TextEditingController();

  int get _total => widget.consultFee + widget.platformFee;

  /// A mobile-money phone number good enough to attempt a charge with:
  /// digits only, a plausible local-number length once the leading 0 (if
  /// any) is dropped for the +256 prefix shown next to the field.
  bool get _hasValidPhone {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    return local.length >= 9;
  }

  /// Card payments need a vetted card-entry SDK (Stripe Elements or
  /// equivalent) rather than a hand-rolled card form — that integration
  /// isn't wired up yet, so card is disabled here rather than accepting a
  /// "payment" with no card details actually collected.
  bool get _canPay {
    switch (_method) {
      case _PayMethod.mtn:
      case _PayMethod.airtel:
        return _hasValidPhone;
      case _PayMethod.card:
        return false;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _fmtUgx(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'UGX $buf';
  }

  Future<void> _pay() async {
    if (_isPaying || !_canPay) return;
    setState(() => _isPaying = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      showAppSnack(
        context,
        'Payment successful. Appointment booked!',
        tone: AppStatusTone.success,
      );
      context.go('/my-appointments');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      showAppSnack(
        context,
        userFriendlyErrorMessage(
          e,
          defaultMessage:
              'Payment processing could not be completed. Please try again.',
        ),
        tone: AppStatusTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            const BloomScreenHeader(title: 'Payment'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BloomCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDER SUMMARY',
                            style: BloomTextStyles.inter(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.06,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _SummaryRow(
                            label: '${widget.doctorName} · consult',
                            value: _fmtUgx(widget.consultFee),
                          ),
                          const SizedBox(height: 6),
                          _SummaryRow(
                            label: 'Platform fee',
                            value: _fmtUgx(widget.platformFee),
                            muted: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: BloomDivider(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: BloomTextStyles.inter(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              BloomMonoText(
                                _fmtUgx(_total),
                                size: 14,
                                weight: FontWeight.w600,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const BloomSectionTitle('Payment method'),
                    BloomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        children: [
                          BloomPaymentMethodTile(
                            iconColor: PaymentBrandColors.mtnYellow,
                            label: 'MTN Mobile Money',
                            selected: _method == _PayMethod.mtn,
                            onTap: () =>
                                setState(() => _method = _PayMethod.mtn),
                          ),
                          BloomPaymentMethodTile(
                            iconColor: PaymentBrandColors.airtelRed,
                            label: 'Airtel Money',
                            selected: _method == _PayMethod.airtel,
                            onTap: () =>
                                setState(() => _method = _PayMethod.airtel),
                          ),
                          BloomPaymentMethodTile(
                            iconColor: AppColors.primaryDark,
                            label: 'Visa / Mastercard',
                            selected: _method == _PayMethod.card,
                            onTap: () =>
                                setState(() => _method = _PayMethod.card),
                            showBorder: false,
                          ),
                        ],
                      ),
                    ),
                    if (_method == _PayMethod.mtn ||
                        _method == _PayMethod.airtel) ...[
                      const BloomSectionTitle('Mobile money number'),
                      BloomCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '+256',
                              style: BloomTextStyles.inter(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(width: 1, height: 20, color: AppColors.border),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '7XX XXX XXX',
                                  hintStyle: BloomTextStyles.inter(
                                    size: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                style: BloomTextStyles.inter(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_phoneCtrl.text.isNotEmpty && !_hasValidPhone) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Enter the number the mobile money prompt should go to.',
                          style: BloomTextStyles.inter(
                            size: 11.5,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                    if (_method == _PayMethod.card) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.warningDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Card payments aren\'t available yet. Please pay with MTN or Airtel Money for now.',
                                style: BloomTextStyles.inter(
                                  size: 12,
                                  color: AppColors.warningDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: BloomButton(
                label: _isPaying ? 'Processing…' : 'Pay ${_fmtUgx(_total)}',
                isLoading: _isPaying,
                onPressed: (_isPaying || !_canPay) ? null : _pay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: BloomTextStyles.inter(
              size: 12,
              color: muted
                  ? AppColors.textMuted
                  : AppColors.textPrimary,
            ),
          ),
        ),
        BloomMonoText(
          value,
          size: 12,
          color: muted ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ],
    );
  }
}
