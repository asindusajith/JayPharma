import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import 'payment_details_screen.dart';

class SelectCustomerScreen extends StatefulWidget {
  const SelectCustomerScreen({super.key});

  @override
  State<SelectCustomerScreen> createState() => _SelectCustomerScreenState();
}

class _SelectCustomerScreenState extends State<SelectCustomerScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchRealtimeCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final currency = NumberFormat('#,##0.00', 'en_US');

    final allCustomers = appState.accessibleCustomers;
    final filteredCustomers = allCustomers.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.code.toLowerCase().contains(q) || c.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('select_customer', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(1, lang == 'si' ? 'පාරිභෝගිකයා' : 'Customer', true),
                _buildStepDivider(false),
                _buildStepIndicator(2, lang == 'si' ? 'ගෙවීම' : 'Payment', false),
                _buildStepDivider(false),
                _buildStepIndicator(3, lang == 'si' ? 'සමාලෝචනය' : 'Review', false),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: LocalizationService.tr('search_customer', lang: lang),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                  if (!appState.currentUser.hasAllLocations)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lang == 'si'
                                  ? 'පවරා ඇති ප්‍රදේශ: ${appState.currentUser.assignedLocations} (${appState.customers.length} න් ${filteredCustomers.length})'
                                  : 'Territory Scoped: ${appState.currentUser.assignedLocations} (${filteredCustomers.length} of ${appState.customers.length} total)',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        lang == 'si'
                            ? 'හිඟ ඉන්වොයිසි සහිත පාරිභෝගිකයින් ${filteredCustomers.length} ක්'
                            : '${filteredCustomers.length} Customers with Due Invoices',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Customers List
            Expanded(
              child: filteredCustomers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            lang == 'si' ? 'ගැලපෙන පාරිභෝගිකයෙකු හමු නොවීය.' : 'No matching pharmacy or customer found.',
                            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return _buildCustomerItem(context, customer, currency, appState, lang);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(BuildContext context, Customer customer, NumberFormat currency, AppState appState, String lang) {
    final invCount = customer.pendingInvoiceCount > 0 
        ? customer.pendingInvoiceCount 
        : appState.getCustomerInvoices(customer.code).length;

    final outstanding = customer.totalOutstanding > 0 
        ? customer.totalOutstanding 
        : appState.getCustomerInvoices(customer.code).fold(0.0, (sum, i) => sum + i.outstandingBalance);

    final isSi = lang == 'si';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          appState.startNewPayment(customer);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              // Customer Code Badge - fixed width & scaleDown so 8-digit codes never wrap
              Container(
                width: 82,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      customer.code,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppTheme.primaryBlue,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Customer Details: Name, Pending & Part Settled Counts, and Outstanding Balance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Breakdown of Pending and Part Settled Invoices
                        if (customer.pendingCount > 0 && customer.partSettledCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, size: 11, color: Color(0xFFB45309)),
                                const SizedBox(width: 3),
                                Text(
                                  isSi ? '${customer.pendingCount} බලාපොරොත්තු' : '${customer.pendingCount} Pending',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.pie_chart_outline_rounded, size: 11, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 3),
                                Text(
                                  isSi ? '${customer.partSettledCount} කොටසක් ගෙවා ඇත' : '${customer.partSettledCount} Part Settled',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: customer.partSettledCount > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: customer.partSettledCount > 0 ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  customer.partSettledCount > 0 ? Icons.pie_chart_outline_rounded : Icons.hourglass_top_rounded,
                                  size: 11,
                                  color: customer.partSettledCount > 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  customer.partSettledCount > 0
                                      ? (isSi ? '${customer.partSettledCount} කොටසක් ගෙවා ඇත' : '${customer.partSettledCount} Part Settled')
                                      : (isSi ? '${customer.pendingCount > 0 ? customer.pendingCount : invCount} හිඟ ඉන්වොයිසි' : '${customer.pendingCount > 0 ? customer.pendingCount : invCount} Pending Invoices'),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: customer.partSettledCount > 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Total Outstanding Balance
                        if (outstanding > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payments_outlined, size: 11, color: Color(0xFFDC2626)),
                                const SizedBox(width: 3),
                                Text(
                                  'Rs. ${currency.format(outstanding)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? AppTheme.primaryNavy : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool active) {
    return Container(
      width: 20,
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: active ? Colors.white : Colors.white30,
    );
  }
}
