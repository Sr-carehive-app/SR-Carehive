import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2260FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Serechi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
                    // Logo and App Name
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/images/logo.png', width: 80, height: 80),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Serechi',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'by SR CareHive Pvt. Ltd.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Welcome Section
                    _h('Welcome to Serechi – Your Trusted Healthcare Companion'),
                    const SizedBox(height: 12),
                    _p('Serechi is an innovative digital platform, designed to seamlessly connect healthcare seekers and healthcare providers across communities. Rooted in the philosophy "Through the people, for the people, and by the people," Serechi brings compassionate, professional, and reliable care to your doorstep.'),
                    const SizedBox(height: 20),
                    
                    // For Healthcare Seekers
                    _h('For Healthcare Seekers'),
                    const SizedBox(height: 8),
                    _p('Serechi offers a simple, secure, and transparent way to find, choose, order, and manage healthcare services — from home nursing and elderly care to physiotherapy, post-surgical support, and chronic disease management. Users can view verified profiles, book trusted professionals, track appointments, make secure payments, and share feedback — all in one place.'),
                    const SizedBox(height: 20),
                    
                    // For Healthcare Providers
                    _h('For Healthcare Providers'),
                    const SizedBox(height: 8),
                    _p('Including nurses, paramedical professionals, physiotherapists, and allied health workers, Serechi offers a gateway to professional growth and service engagement. Registered providers can apply, onboard, and receive assignments directly through the app, ensuring flexible work opportunities, fair remuneration, and visibility within a trusted care network.'),
                    const SizedBox(height: 20),
                    
                    // Key Features
                    _h('Key Features'),
                    const SizedBox(height: 12),
                    _feature('Find & Choose', 'Discover verified healthcare professionals or care services near you.', Icons.search),
                    _feature('Book & Manage', 'Schedule and manage care sessions conveniently.', Icons.calendar_today),
                    _feature('Secure Payments', 'Pay or receive payments safely through integrated digital options.', Icons.payment),
                    _feature('Feedback & Quality', 'Share experiences, build credibility, and ensure accountability.', Icons.star),
                    _feature('Provider Onboarding', 'Healthcare professionals can register, upload credentials, and join the SR CareHive network directly through the app.', Icons.badge),
                    _feature('Know SR CareHive', 'Learn about our mission, standards, and vision for compassionate, community-based healthcare.', Icons.info),
                    const SizedBox(height: 20),
                    
                    // Closing Statement
                    _h('Our Vision'),
                    const SizedBox(height: 8),
                    _p('Serechi is more than a service app — it is a healthcare ecosystem uniting people who care and those who need care. Whether you seek support or wish to serve, Serechi is your trusted bridge to a connected, ethical, and human-centered healthcare future.'),
                    const SizedBox(height: 20),
                    
                    // Tagline
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Download Serechi today — where care meets connection.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _h(String text) => Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
  
  static Widget _p(String text) => Text(
        text,
        textAlign: TextAlign.justify,
        style: const TextStyle(height: 1.5),
      );
  
  static Widget _feature(String title, String description, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2260FF), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
