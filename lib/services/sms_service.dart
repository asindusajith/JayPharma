import 'package:intl/intl.dart';
import '../models/receipt.dart';

class SmsService {
  static final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  static String generatePaymentConfirmationMessage(Receipt receipt) {
    final formattedAmount = currencyFormat.format(receipt.totalAmount);
    final paymentType = receipt.paymentMethod == PaymentMethod.cash ? 'Cash' : 'Cheque (${receipt.bank ?? ''})';
    
    return 'JAY PHARMA: Dear Customer (${receipt.customerCode}), we have received Rs. $formattedAmount via $paymentType under Receipt #${receipt.manualReceiptNo} on ${DateFormat('dd/MM/yyyy HH:mm').format(receipt.createdAt)}. Thank you for your payment.';
  }

  // Simulated SMS dispatcher with delivery response
  static Future<Map<String, dynamic>> sendCustomerPaymentSms(Receipt receipt) async {
    // In production, connects to Dialog/Mobitel/Hutch or Twilio/Infobip SMS Gateway API
    await Future.delayed(const Duration(milliseconds: 600));

    final message = generatePaymentConfirmationMessage(receipt);
    return {
      'success': true,
      'recipient': receipt.customerPhone.isNotEmpty ? receipt.customerPhone : '077 123 4567',
      'message': message,
      'timestamp': DateTime.now(),
      'status': 'DELIVERED',
    };
  }
}
