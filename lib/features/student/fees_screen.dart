import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/services/student_service.dart';
import 'package:alara/core/models/fee.dart';
import 'package:alara/theme.dart';

class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({super.key});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  final StudentService _service = StudentService();
  List<Fee>? _fees;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final fees = await _service.getFees();

      double totalAmount = 0;
      double totalPaid = 0;
      int overdueCount = 0;
      for (final fee in fees) {
        totalAmount += fee.totalAssigned;
        totalPaid += fee.paidAmount;
        if (fee.isOverdue) overdueCount++;
      }

      final summary = <String, dynamic>{
        'total_amount': totalAmount,
        'total_paid': totalPaid,
        'balance': totalAmount - totalPaid,
        'overdue_count': overdueCount,
        'total_items': fees.length,
        'paid_items': fees.where((f) => f.isPaid).length,
      };

      if (mounted) {
        setState(() {
          _fees = fees;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightModeColors.lightBackground,
      appBar: AppBar(
        title: const Text('Fees & Payments', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [LightModeColors.lightPrimary, LightModeColors.lightSecondary],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _isLoading ? null : _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: LightModeColors.lightPrimary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_summary != null && _summary!.isNotEmpty) _buildSummaryCard(),
          const SizedBox(height: 24),
          Text('Fee Items',
              style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_fees == null || _fees!.isEmpty)
            _buildEmptyFees()
          else
            ..._fees!.map((fee) => _buildFeeCard(fee)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalAmount = (_summary!['total_amount'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (_summary!['total_paid'] as num?)?.toDouble() ?? 0.0;
    final balance = (_summary!['balance'] as num?)?.toDouble() ?? 0.0;
    final overdueCount = _summary!['overdue_count'] ?? 0;
    final paidItems = _summary!['paid_items'] ?? 0;
    final totalItems = _summary!['total_items'] ?? 0;
    final paymentPct = totalAmount > 0 ? (totalPaid / totalAmount) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Payment progress
          Row(
            children: [
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80, height: 80,
                      child: CircularProgressIndicator(
                        value: paymentPct / 100,
                        strokeWidth: 8,
                        backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          paymentPct >= 90
                              ? LightModeColors.accentGreen
                              : paymentPct >= 50
                                  ? LightModeColors.accentOrange
                                  : LightModeColors.lightError,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${paymentPct.toStringAsFixed(0)}%',
                            style: context.textStyles.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: paymentPct >= 90
                                    ? LightModeColors.accentGreen
                                    : paymentPct >= 50
                                        ? LightModeColors.accentOrange
                                        : LightModeColors.lightError)),
                        Text('Paid',
                            style: TextStyle(
                                fontSize: 10, color: LightModeColors.lightOnSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAmountRow('Total Fees', totalAmount, LightModeColors.lightOnSurface),
                    const SizedBox(height: 6),
                    _buildAmountRow('Paid', totalPaid, LightModeColors.accentGreen),
                    const SizedBox(height: 6),
                    _buildAmountRow('Balance', balance, balance > 0 ? LightModeColors.lightError : LightModeColors.accentGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _buildMinimalStat('$paidItems/$totalItems', 'Paid Items', LightModeColors.accentGreen),
              const SizedBox(width: 8),
              _buildMinimalStat('$overdueCount', 'Overdue', LightModeColors.lightError),
              const SizedBox(width: 8),
              _buildMinimalStat(totalAmount > 0 ? '${(totalPaid / totalAmount * 100).toStringAsFixed(0)}%' : '0%', 'Progress', LightModeColors.lightPrimary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: context.textStyles.bodySmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant)),
        Text('GHS ${amount.toStringAsFixed(2)}',
            style: context.textStyles.titleSmall?.copyWith(
                fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildMinimalStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: context.textStyles.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: color, fontSize: 18)),
            Text(label,
                style: context.textStyles.bodySmall?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFees() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.payment_rounded, size: 48,
                color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('No fee records found',
                style: context.textStyles.bodyMedium?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeCard(Fee fee) {
    final paymentPct = fee.amount > 0 ? (fee.paidAmount / fee.amount) * 100 : 0.0;

    Color statusColor;
    String statusLabel;
    if (fee.isPaid) {
      statusColor = LightModeColors.accentGreen;
      statusLabel = 'Paid';
    } else if (fee.isOverdue) {
      statusColor = LightModeColors.lightError;
      statusLabel = 'Overdue';
    } else {
      statusColor = LightModeColors.accentOrange;
      statusLabel = 'Partial';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fee.isOverdue
                ? LightModeColors.lightError.withOpacity(0.2)
                : LightModeColors.lightOutline,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      fee.isPaid ? Icons.check_circle_rounded : Icons.payment_rounded,
                      color: statusColor, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fee.title,
                            style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Type: ${fee.feeType}',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('Due: ${DateFormat('MMM dd, yyyy').format(fee.dueDate)}',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Amount breakdown
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GHS ${fee.totalAssigned.toStringAsFixed(2)}',
                            style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold)),
                        Text('Total assigned',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GHS ${fee.paidAmount.toStringAsFixed(2)}',
                            style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600, color: LightModeColors.accentGreen)),
                        Text('Paid',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GHS ${fee.balance.toStringAsFixed(2)}',
                            style: context.textStyles.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: fee.balance > 0 ? LightModeColors.lightError : LightModeColors.accentGreen)),
                        Text('Balance',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: LightModeColors.lightOnSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: paymentPct / 100,
                  minHeight: 5,
                  backgroundColor: LightModeColors.lightOutline.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${paymentPct.toStringAsFixed(0)}% paid',
                  style: context.textStyles.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500, color: statusColor, fontSize: 11),
                ),
              ),
              if (fee.paymentHistory.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  'Payment History',
                  style: context.textStyles.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: LightModeColors.lightOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...fee.paymentHistory.map((payment) {
                  final paidOn = payment.paymentDate != null
                      ? DateFormat('MMM dd, yyyy').format(payment.paymentDate!)
                      : 'Date not available';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: LightModeColors.lightOnSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${payment.method ?? 'Payment'} • GHS ${payment.amount.toStringAsFixed(2)} • $paidOn'
                            '${payment.reference != null && payment.reference!.trim().isNotEmpty ? ' • Ref: ${payment.reference}' : ''}',
                            style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
