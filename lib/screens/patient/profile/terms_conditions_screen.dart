import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2260FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
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
                        'Terms & Conditions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _p('Welcome to SR Carehive Network. By accessing or using our website '),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('srcarehive.com', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Text(' and our services (including those offered via Serechi app), you agree to these Terms & Conditions, as well as our Privacy Policy. If you do not agree, please do not use our services.'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _h('1. Services'),
                    _p('We provide a health-related platform, offering elder care, chronic care, wellness resources, community forums, caregiving services, training, and allied health support as described on our Site.'),
                    const SizedBox(height: 12),
                    _h('2. User Accounts'),
                    _ul([
                      'You may register for an account to access certain features (forums, expert advice, etc.). You must provide accurate information and keep your account secure.',
                      'You are responsible for all activity under your account.',
                    ]),
                    const SizedBox(height: 12),
                    _h('3. Payment & Razorpay'),
                    _ul([
                      'Some of our services may require payment. All payments are processed securely via Razorpay.',
                      'We do not store your full payment instrument details (card/UPI credentials etc.); Razorpay handles that as per their policies.',
                      'Refunds, cancellations, or changes to paid services will follow our Refund Policy or as indicated at the time of purchase.',
                    ]),
                    const SizedBox(height: 12),
                    _h('4. Intellectual Property'),
                    _p('All content on this Site (text, images, logos, designs) is owned by us or licensed to us. You may not reuse, copy, modify, or distribute without our permission.'),
                    const SizedBox(height: 12),
                    _h('5. Content & Conduct'),
                    _p('You agree not to misuse the forums or community tools, post harmful or unlawful content, impersonate others, or violate applicable laws. We reserve the right to remove or modify content that violates these Terms.'),
                    const SizedBox(height: 12),
                    _h('6. Limitation of Liability'),
                    _p('We strive to provide accurate, timely information, but we make no warranties regarding the completeness, reliability, or suitability of the information. In no event shall we be liable for any indirect, incidental or consequential damages arising out of or in connection with your use of our Site or services.'),
                    const SizedBox(height: 12),
                    _h('7. Governing Law'),
                    _p('These Terms are governed by the laws of Uttarakhand. Any disputes will be resolved in courts of appropriate jurisdiction in Uttarakhand.'),
                    const SizedBox(height: 12),
                    _h('8. Changes to Terms'),
                    _p('We may modify these Terms from time to time. We will notify users by posting revised Terms on this Site. Continued use after changes means you accept the new Terms.'),
                    const SizedBox(height: 12),
                    _h('9. Contact Information'),
                    Wrap(children: [
                      const Text('If you have questions about these Terms, please contact us at: '),
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
