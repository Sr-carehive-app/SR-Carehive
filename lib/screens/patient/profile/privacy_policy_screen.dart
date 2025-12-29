import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2260FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF7F7FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _p('SR Carehive Network is committed to protecting your privacy. This Privacy Policy describes how we collect, use, share, and protect your personal data when you use our website '),
                    const Text('srcarehive.com', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Text(' and the Serechi app'),
                    const SizedBox(height: 20),
                    _h('1. Information We Collect'),
                    _ul([
                      'Personal Identifiable Information (PII): name, email address, phone number, address when you register or provide feedback.',
                      'Health-related information: if you share details relevant to caregiving or chronic conditions (only if voluntary).',
                      'Payment Information: processed via Razorpay (we do not store full card/UPI details).',
                      'Usage Data: how you use the Site, pages visited, links clicked.',
                      'Cookies & Tracking: to improve Site experience and performance.',
                    ]),
                    const SizedBox(height: 12),
                    _h('2. How We Use Information'),
                    _ul([
                      'Provide, maintain, and improve our services.',
                      'Process payments and fulfil your requests.',
                      'Communicate with you: updates, newsletters, support.',
                      'Ensure security, prevent fraud, misuse.',
                      'Analyze Site traffic, usage patterns for enhancement.',
                    ]),
                    const SizedBox(height: 12),
                    _h('3. Sharing & Disclosure'),
                    _ul([
                      'Razorpay (for payment processing).',
                      'Service providers engaged by us (hosting, analytics etc.).',
                      'Legal authorities if required by law.',
                      'Other third parties only with your consent or as needed to deliver the services.',
                    ]),
                    const SizedBox(height: 12),
                    _h('4. Data Security'),
                    _p('We implement reasonable technical and organizational measures to protect your data (e.g., encryption, secure servers). However, no method is 100% secure, and we cannot guarantee absolute security.'),
                    const SizedBox(height: 12),
                    _h('5. Data Retention'),
                    _p('We retain your personal data only as long as necessary for the purposes described in this Policy or as required by law. If you request deletion, we will remove your data except where retention is legally required.'),
                    const SizedBox(height: 12),
                    _h('6. Your Rights'),
                    _ul([
                      'Accessing your personal data.',
                      'Correcting inaccurate data.',
                      'Deleting your data.',
                      'Restricting or objecting to certain processing.',
                      'Withdrawing consent where applicable.',
                    ]),
                    const SizedBox(height: 12),
                    _h('7. Children’s Privacy'),
                    _p('Our services are not intended for minors under age 18. We do not knowingly collect personal data from children. If you believe we have done so, please contact us to remove it.'),
                    const SizedBox(height: 12),
                    _h('8. International Transfers'),
                    _p('If data is transferred across borders, we ensure that appropriate protections are in place (standard contractual clauses, etc.).'),
                    const SizedBox(height: 12),
                    _h('9. Changes to This Policy'),
                    _p('We may update this Privacy Policy occasionally. The revised version will be posted with a new Effective Date. Your continued use after changes implies your acceptance.'),
                    const SizedBox(height: 12),
                    _h('10. Contact Us'),
                    Wrap(children: [
                      const Text('If you have any questions or concerns about this Privacy Policy, reach us at: '),
                      InkWell(
                        onTap: () => launchUrl(Uri.parse('mailto:contact@srcarehive.com')),
                        child: const Text('contact@srcarehive.com', style: TextStyle(color: primary, decoration: TextDecoration.underline)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _h(String text) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  static Widget _p(String text) => Text(text, textAlign: TextAlign.justify);
  static Widget _ul(List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• '),
                    Expanded(child: Text(e)),
                  ]),
                ))
            .toList(),
      );
}
