import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import '../payment/payment_details_screen.dart';

enum CustomerFilterTab { all, hasBalance, settled }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  CustomerFilterTab _selectedTab = CustomerFilterTab.all;
  final Set<String> _expandedCustomerCodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchRealtimeCustomers(force: true);
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
    final isSi = lang == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Filter accessible customers by search query
    final accessible = appState.accessibleCustomers;
    final searchedCustomers = accessible.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.town.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
    }).toList();

    // Tab filtering (All vs Has Balance vs Settled)
    final filteredCustomers = searchedCustomers.where((c) {
      final invoices = appState.getCustomerInvoices(c.code);
      final localOutstanding = invoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);
      final outstanding = c.totalOutstanding > 0 ? c.totalOutstanding : localOutstanding;

      switch (_selectedTab) {
        case CustomerFilterTab.hasBalance:
          return outstanding > 0.01;
        case CustomerFilterTab.settled:
          return outstanding <= 0.01;
        case CustomerFilterTab.all:
          return true;
      }
    }).toList();

    // Summary calculations
    final totalAccessibleOutstanding = accessible.fold<double>(0.0, (sum, c) => sum + c.totalOutstanding);
    final countWithBalance = accessible.where((c) => c.totalOutstanding > 0.01).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1E36),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.tr('customers', lang: lang),
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              isSi ? 'පාරිභෝගික ගිණුම් සහ හිඟ ශේෂයන්' : 'Customer Directory & Outstanding Dues',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: isSi ? 'නැවත පූරණය කරන්න' : 'Refresh Customers',
            onPressed: () {
              appState.fetchRealtimeCustomers(force: true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls & Territory Scope
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: LocalizationService.tr('search_customer', lang: lang),
                        hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Tabs (All, With Due, Settled)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: isSi ? 'සියලු දෙනා (${searchedCustomers.length})' : 'All (${searchedCustomers.length})',
                          tab: CustomerFilterTab.all,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: isSi ? 'හිඟ මුදල් සහිත (${countWithBalance})' : 'With Dues (${countWithBalance})',
                          tab: CustomerFilterTab.hasBalance,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: isSi
                              ? 'සමථය කර ඇති (${accessible.length - countWithBalance})'
                              : 'Settled (${accessible.length - countWithBalance})',
                          tab: CustomerFilterTab.settled,
                        ),
                      ],
                    ),
                  ),

                  // Territory Scoped Tag (if collector is territory restricted)
                  if (!appState.currentUser.hasAllLocations) ...[
                    const SizedBox(height: 10),
                    Container(
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
                              isSi
                                  ? 'පවරා ඇති ප්‍රදේශ: ${appState.currentUser.assignedLocations} (${appState.customers.length} න් ${accessible.length})'
                                  : 'Territory Scoped: ${appState.currentUser.assignedLocations} (${accessible.length} of ${appState.customers.length} accessible)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Overall Outstanding Metric Banner
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              isSi ? 'මුළු හිඟ ශේෂය:' : 'Total Outstanding:',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Text(
                          'Rs. ${currency.format(totalAccessibleOutstanding)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F1E36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Customers Directory List
            Expanded(
              child: filteredCustomers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              isSi ? 'ගැලපෙන පාරිභෝගිකයෙකු හමු නොවීය.' : 'No matching customers found.',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSi ? 'සෙවුම් පදය හෝ පෙරහන වෙනස් කර බලන්න.' : 'Try adjusting your search query or filter tab.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final isExpanded = _expandedCustomerCodes.contains(customer.code);
                        final invoices = appState.getCustomerInvoices(customer.code);
                        final localOutstanding = invoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);
                        final outstanding = customer.totalOutstanding > 0 ? customer.totalOutstanding : localOutstanding;
                        final invCount = customer.pendingInvoiceCount > 0 ? customer.pendingInvoiceCount : invoices.length;

                        return _buildCustomerCard(
                          customer: customer,
                          isExpanded: isExpanded,
                          invoices: invoices,
                          invCount: invCount,
                          outstanding: outstanding,
                          currency: currency,
                          dateFormat: dateFormat,
                          appState: appState,
                          isSi: isSi,
                          lang: lang,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({required String label, required CustomerFilterTab tab}) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard({
    required Customer customer,
    required bool isExpanded,
    required List<Invoice> invoices,
    required int invCount,
    required double outstanding,
    required NumberFormat currency,
    required DateFormat dateFormat,
    required AppState appState,
    required bool isSi,
    required String lang,
  }) {
    final hasBalance = outstanding > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? const Color(0xFF2563EB).withOpacity(0.08) : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header Bar: Code, Town, and Outstanding Amount
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCustomerCodes.remove(customer.code);
                } else {
                  _expandedCustomerCodes.add(customer.code);
                  appState.fetchInvoicesForCustomerRealtime(customer.code);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Code Pill, Town Pill & Amount
                  Row(
                    children: [
                      // Customer Code Badge - FIXED WIDTH / NEVER WRAPS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 3),
                            Text(
                              customer.code,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D4ED8),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (customer.town.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            customer.town,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Outstanding Balance Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${currency.format(outstanding)}',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: hasBalance ? const Color(0xFF0F1E36) : const Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            hasBalance ? (isSi ? 'හිඟ ශේෂය' : 'Due Amount') : (isSi ? 'සමථය කර ඇත' : 'Settled'),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: hasBalance ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer Name
                  Text(
                    customer.name,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom Info Row: Invoice count, Address & Chevron
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasBalance
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBalance ? Icons.receipt_long : Icons.check_circle_outline,
                              size: 12,
                              color: hasBalance ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasBalance
                                  ? (isSi ? 'හිඟ ඉන්වොයිසි $invCount' : '$invCount due invoices')
                                  : (isSi ? 'ඉන්වොයිසි හිඟ නැත' : 'All Settled'),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: hasBalance ? const Color(0xFFB45309) : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (customer.address.isNotEmpty)
                        Expanded(
                          child: Text(
                            customer.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        )
                      else
                        const Spacer(),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content (Invoices & Payment Actions)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full Address & Phone
                  if (customer.address.isNotEmpty || customer.phone.isNotEmpty) ...[
                    Row(
                      children: [
                        if (customer.address.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.address,
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                            ),
                          ),
                        ],
                        if (customer.phone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone,
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Outstanding Invoices Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocalizationService.tr('outstanding_invoices', lang: lang),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      if (appState.isLoadingInvoices && invoices.isEmpty)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (invoices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          isSi
                              ? 'හිඟ ශේෂයක් නොමැත. සියලු ඉන්වොයිසි සමථයකට පත් කර ඇත.'
                              : 'No outstanding balance. All invoices are settled.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF16A34A)),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    LocalizationService.tr('inv_no', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    LocalizationService.tr('delivery_age', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    LocalizationService.tr('balance', lang: lang),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Rows
                          for (int i = 0; i < invoices.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      invoices[i].invoiceNo,
                                      style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '${invoices[i].deliveryAgeDays} ${LocalizationService.tr('days', lang: lang)} (${dateFormat.format(invoices[i].deliveryDate)})',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: invoices[i].deliveryAgeDays > 30 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                        fontWeight: invoices[i].deliveryAgeDays > 30 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Rs. ${currency.format(invoices[i].outstandingBalance)}',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F1E36),
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
                  const SizedBox(height: 12),

                  // Quick Collect Payment CTA
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_card, size: 16),
                    label: Text(
                      isSi ? 'මෙම පාරිභෝගිකයාගෙන් මුදල් අයකරගන්න' : 'Collect Payment for this Customer',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F1E36),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (appState.isDayEndFinalized) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocalizationService.tr('day_end_locked_msg', lang: lang)),
                            backgroundColor: AppTheme.dangerRed,
                          ),
                        );
                        return;
                      }
                      appState.startNewPayment(customer);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
