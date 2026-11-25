import 'package:flutter/material.dart';

import '../../core/models/app_module.dart';
import '../../core/theme/app_colors.dart';

/// Offline, searchable help assistant for shop owners. It does not send
/// business data to an external service or require an API key.
class ShopGuideScreen extends StatefulWidget {
  const ShopGuideScreen({super.key, this.onOpenModule});

  final void Function(String moduleId)? onOpenModule;

  @override
  State<ShopGuideScreen> createState() => _ShopGuideScreenState();
}

class _ShopGuideScreenState extends State<ShopGuideScreen> {
  final _question = TextEditingController();
  String _query = '';
  _GuideTopic? _selected;

  static const _topics = <_GuideTopic>[
    _GuideTopic('Getting started', 'I am new. What should I do first?',
      'Set up your shop before making your first invoice.',
      ['Open Shop Settings and enter your shop name, address and phone.',
       'Add your GSTIN if your shop is GST-registered. Choose the default GST or NON-GST invoice setting.',
       'Add customers and suppliers in Party Details.',
       'Add products, purchase rates, selling rates and opening stock in Items & Stock.',
       'Make a test invoice and check the PDF before using it with a customer.'],
      'settings', ['start', 'begin', 'new', 'first', 'setup', 'shop']),
    _GuideTopic('Create a sale invoice', 'How do I sell an item and make a bill?',
      'Use Sale Counter for a customer bill.',
      ['Open Sale Counter and choose New Sale / the add button.',
       'Select a customer, or use the walk-in customer option.',
       'Choose GST or NON-GST as appropriate for this sale.',
       'Add each product, quantity, rate and any discount. Add serial numbers or warranty details when needed.',
       'Enter the amount received and payment mode. Check the due amount.',
       'Save the invoice. Open PDF / Print / Share to give the bill to the customer.'],
      'sale', ['sale', 'sell', 'invoice', 'bill', 'customer', 'gst', 'non gst']),
    _GuideTopic('Record a purchase', 'How do I enter stock bought from a supplier?',
      'Use Purchase Counter when goods arrive from a supplier.',
      ['Open Purchase Counter and start a purchase invoice.',
       'Select the supplier and add each product, quantity and purchase rate.',
       'For a new product, enter its name and details; it can be added to Items & Stock.',
       'Use Camera to photograph the supplier bill, or Files to attach photos or a PDF.',
       'Enter payment made and payment mode, then save.',
       'Open the saved purchase invoice to view or share its attached bill files.'],
      'purchase', ['purchase', 'buy', 'supplier', 'stock in', 'bill photo', 'upload']),
    _GuideTopic('Add or update products', 'How do I add a product or change its price?',
      'Products are managed in Items & Stock.',
      ['Open Items & Stock.',
       'Tap Add Product to enter the product name and available details.',
       'Enter purchase rate, selling rate, GST rate, opening quantity and minimum stock where applicable.',
       'Save the product. Open it later to update its details.',
       'Use stock adjustment only for a genuine stock correction; purchases and sales should normally update stock through their invoices.'],
      'stock', ['product', 'item', 'price', 'rate', 'add item', 'inventory']),
    _GuideTopic('Customers and suppliers', 'How do I save a customer or supplier?',
      'Use Party Details to keep contact information and balances together.',
      ['Open Party Details and choose Add.',
       'Choose the correct party type: customer, supplier or both if supported by the form.',
       'Enter the name and contact details. Add GSTIN and address when available.',
       'Save the record. Open the party later to see its ledger and outstanding balance.'],
      'parties', ['party', 'parties', 'customer', 'supplier', 'contact', 'ledger']),
    _GuideTopic('Understand profit', 'Where can I see my profit?',
      'Open Reports and choose the profit report.',
      ['Open Reports.',
       'Choose the profit or sales analysis report and select the required date range.',
       'Profit is an estimate based on recorded sale values and item purchase costs.',
       'For newer sales, the app saves the purchase cost on the sale line so later price changes do not rewrite that sale’s cost.',
       'Check that purchase rates, discounts, returns and expenses are entered correctly. Profit figures are only as accurate as the records entered.'],
      'reports', ['profit', 'earning', 'margin', 'loss', 'report']),
    _GuideTopic('Serial numbers and warranty', 'How do I scan a serial number?',
      'Use the camera scanner from the serial-number field in an invoice.',
      ['Open a sale or purchase invoice and add or edit an item.',
       'Tap the camera scan icon beside the serial-number field.',
       'Allow camera access when Android asks, then point the camera at a supported barcode or QR code.',
       'If the serial is printed as ordinary text rather than a barcode or QR code, type it manually.',
       'For eligible sale items, enter the warranty period before saving. Use Serial Tracking or Warranty to look up saved records.'],
      'serial', ['serial', 'barcode', 'qr', 'scan', 'warranty']),
    _GuideTopic('Record expenses and payments', 'How do I enter shop expenses or payments?',
      'Use Expenses for business costs and Cash & Bank for account activity.',
      ['Open Expenses and add the date, category, amount and payment details.',
       'Use Cash & Bank to review cash or bank balances and account transactions.',
       'Record customer or supplier payments against the correct party when using the party ledger.',
       'Avoid entering the same payment twice in two different places.'],
      'expenses', ['expense', 'payment', 'cash', 'bank', 'upi', 'balance']),
    _GuideTopic('Backup your data', 'How do I protect my shop data?',
      'Use Backup & Restore regularly, especially before changing phones.',
      ['Open Backup & Restore.',
       'Create a fresh backup and follow the app prompts to save or share it.',
       'Keep a copy somewhere separate from the phone.',
       'Before restoring, confirm that the backup belongs to the correct shop and understand that restore may replace current data.',
       'Do not share backup files publicly; they may contain customer and business information.'],
      'backup', ['backup', 'restore', 'data', 'phone', 'transfer']),
    _GuideTopic('Shop and invoice settings', 'How do I add my shop logo or change invoice details?',
      'Use Shop Settings to control the information printed on invoices.',
      ['Open Shop Settings.',
       'Enter the shop name, address, phone and GSTIN as applicable.',
       'Choose a shop logo if you want it printed on invoices.',
       'Set the invoice number prefix, default payment mode and default GST preference.',
       'Save settings and preview a new invoice PDF to confirm the details.'],
      'settings', ['logo', 'settings', 'gstin', 'prefix', 'invoice design']),
  ];

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  _GuideTopic? _findAnswer(String value) {
    final q = value.toLowerCase().trim();
    if (q.isEmpty) return null;
    final words = q.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 2).toSet();
    _GuideTopic? best;
    var bestScore = 0;
    for (final topic in _topics) {
      final haystack = '${topic.title} ${topic.question} ${topic.answer} ${topic.keywords.join(' ')}'.toLowerCase();
      var score = 0;
      for (final word in words) {
        if (haystack.contains(word)) score += topic.keywords.any((k) => k == word) ? 3 : 1;
      }
      if (score > bestScore) {
        best = topic;
        bestScore = score;
      }
    }
    return bestScore > 0 ? best : null;
  }

  void _ask() {
    final q = _question.text.trim();
    if (q.isEmpty) return;
    final answer = _findAnswer(q);
    setState(() {
      _query = q;
      _selected = answer;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _topics.where((t) {
      final q = _query.toLowerCase();
      if (q.isEmpty) return true;
      return '${t.title} ${t.question} ${t.keywords.join(' ')}'.toLowerCase().contains(q);
    }).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyLight]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  CircleAvatar(radius: 26, backgroundColor: AppColors.cyan,
                    child: Icon(Icons.support_agent_rounded, color: AppColors.navy, size: 30)),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Shop Owner Assistant', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Ask how to use SHOPMASTER PRO. Simple step-by-step help, available offline.',
                      style: TextStyle(color: Color(0xFFD7E4F2))),
                  ])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                labelText: 'What do you want to do?',
                hintText: 'e.g. How do I make a GST bill?',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                suffixIcon: IconButton(onPressed: _ask, tooltip: 'Ask assistant',
                  icon: const Icon(Icons.send_rounded)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Try asking about sales, purchases, stock, profit, serial numbers or backup.',
              style: TextStyle(color: AppColors.textMuted)),
            if (_query.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_selected != null)
                _AnswerCard(topic: _selected!, onOpen: widget.onOpenModule)
              else
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('I could not find an exact guide for that question. Try one of these topics:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    for (final t in _topics.take(4))
                      TextButton.icon(onPressed: () => setState(() => _selected = t),
                        icon: const Icon(Icons.help_outline_rounded), label: Text(t.title)),
                  ],
                ))),
            ],
            const SizedBox(height: 18),
            Text('Step-by-step guides', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final topic in filtered)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
                  title: Text(topic.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(topic.question),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() => _selected = topic),
                ),
              ),
            const SizedBox(height: 12),
            const Text('This built-in guide works offline. It is not a live human support service or a cloud AI chatbot.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.topic, required this.onOpen});
  final _GuideTopic topic;
  final void Function(String moduleId)? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppColors.cyan),
            const SizedBox(width: 8),
            Expanded(child: Text(topic.title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(topic.answer),
          const SizedBox(height: 12),
          for (var i = 0; i < topic.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 10),
                Expanded(child: Text(topic.steps[i])),
              ]),
            ),
          if (onOpen != null)
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
              onPressed: () => onOpen!(topic.moduleId),
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Open ${_moduleName(topic.moduleId)}'),
            )),
        ]),
      ),
    );
  }

  String _moduleName(String id) {
    for (final module in appModules) {
      if (module.id == id) return module.title;
    }
    return 'module';
  }
}

class _GuideTopic {
  const _GuideTopic(this.title, this.question, this.answer, this.steps, this.moduleId, this.keywords);
  final String title;
  final String question;
  final String answer;
  final List<String> steps;
  final String moduleId;
  final List<String> keywords;
}
