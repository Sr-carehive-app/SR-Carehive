import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Contact Us form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  bool isSubmitting = false;

  // Country code for phone validation
  String selectedCountryCode = '+91';
  
  // Country codes list with phone number lengths
  final List<Map<String, dynamic>> countryCodes = [
    {'code': '+91', 'country': 'India', 'length': 10},
    {'code': '+1', 'country': 'USA', 'length': 10},
    {'code': '+44', 'country': 'UK', 'length': 10},
    {'code': '+971', 'country': 'UAE', 'length': 9},
    {'code': '+61', 'country': 'Australia', 'length': 9},
    {'code': '+65', 'country': 'Singapore', 'length': 8},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Helper methods for dynamic phone validation
  int getPhoneNumberLength() {
    final country = countryCodes.firstWhere(
      (c) => c['code'] == selectedCountryCode,
      orElse: () => {'code': '+91', 'country': 'India', 'length': 10},
    );
    return country['length'] as int;
  }

  String getPhonePlaceholder() {
    final length = getPhoneNumberLength();
    return '9' * length; // e.g., "9999999999" for 10 digits
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate phone number if provided
    if (phoneController.text.trim().isNotEmpty) {
      final phone = phoneController.text.trim();
      final requiredLength = getPhoneNumberLength();
      if (phone.length != requiredLength || int.tryParse(phone) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone number must be $requiredLength digits for $selectedCountryCode')),
        );
        return;
      }
      // For Indian numbers, check if starts with 6-9
      if (selectedCountryCode == '+91' && !RegExp(r'^[6-9]').hasMatch(phone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indian phone number must start with 6, 7, 8, or 9')),
        );
        return;
      }
    }
    
    setState(() => isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('contact_messages').insert({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        'subject': subjectController.text.trim(),
        'message': messageController.text.trim(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your message has been sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Clear the form after successful submission
      _formKey.currentState!.reset();
      nameController.clear();
      emailController.clear();
      phoneController.clear();
      subjectController.clear();
      messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white, 
        iconTheme: const IconThemeData(color: Colors.black), 
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2260FF),
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contact Us'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // FAQ Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                // Authentication Section
                _buildFAQSection(
                  'Account & Authentication',
                  [
                    FAQItem(
                      question: 'How do I create an account?',
                      answer: 'To create an account, go to the sign-up page and fill in your details including full name, email, password, phone number, date of birth, Aadhar number, permanent address, and gender. You can also sign up using your Google account for faster registration.',
                    ),
                    FAQItem(
                      question: 'Why do I need to verify my email?',
                      answer: 'Email verification ensures the security of your account and confirms that the email address you provided is valid. You\'ll receive a verification link in your email after registration. Click the link to verify your account before logging in.',
                    ),
                    FAQItem(
                      question: 'I forgot my password. How can I reset it?',
                      answer: 'Click on "Forgot Password?" on the login screen, enter your email address, and we\'ll send you a password reset link. Click the link in your email to set a new password.',
                    ),
                    FAQItem(
                      question: 'Can I use Google to sign in?',
                      answer: 'Yes! You can sign in using your Google account. Simply click the "Sign in with Google" button on the login screen. This is a secure and convenient way to access your account.',
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Nurse Services Section
                _buildFAQSection(
                  'Nurse Services & Scheduling',
                  [
                    FAQItem(
                      question: 'How do I schedule a nurse?',
                      answer: 'Go to the Schedule section in your dashboard, select your preferred date and time slot, fill in the patient details (yourself or another person), and describe your health requirements. Complete the payment to confirm your appointment.',
                    ),
                    FAQItem(
                      question: 'What information do I need to provide when scheduling?',
                      answer: 'You\'ll need to provide the patient\'s full name, age, gender, and a detailed description of the health problem or care requirements. This helps us assign the most suitable nurse for your needs.',
                    ),
                    FAQItem(
                      question: 'What are the available time slots?',
                      answer: 'Nurse services are available from 9:00 AM to 6:00 PM, with appointments scheduled in 1-hour intervals. You can select any available time slot that works best for you.',
                    ),
                    FAQItem(
                      question: 'Can I schedule for someone else?',
                      answer: 'Yes, you can schedule appointments for yourself or another person. Simply select "Another Person" when filling out the patient details form.',
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Profile Management Section
                _buildFAQSection(
                  'Profile & Account Management',
                  [
                    FAQItem(
                      question: 'How do I update my profile information?',
                      answer: 'Go to your Profile section and tap on "Edit Profile". You can update your personal information, contact details, and profile photo. All changes are automatically saved to your account.',
                    ),
                    FAQItem(
                      question: 'How do I change my profile photo?',
                      answer: 'In the Edit Profile section, tap on the camera icon on your profile picture. You can select a photo from your gallery. The photo will be automatically uploaded and displayed across the app.',
                    ),
                    FAQItem(
                      question: 'What personal information is stored?',
                      answer: 'We store your name, email, phone number, date of birth, Aadhar number, permanent address, gender, and profile photo. This information is used to provide personalized care services and maintain your health records.',
                    ),
                    FAQItem(
                      question: 'Is my personal information secure?',
                      answer: 'Yes, we use industry-standard security measures to protect your personal information. All data is encrypted and stored securely in our database. We never share your information with third parties without your consent.',
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // General App Usage Section
                _buildFAQSection(
                  'General App Usage',
                  [
                    FAQItem(
                      question: 'What is SERECHI?',
                      answer: 'SERECHI is a healthcare platform by SR CareHive Pvt. Ltd. that connects patients with professional nurses and healthcare providers for home care services. We provide convenient, reliable, and personalized healthcare solutions right at your doorstep.',
                    ),
                    FAQItem(
                      question: 'How do I contact support?',
                      answer: 'You can contact our support team through the Contact Us form in this Help Center. Fill in your details and message, and we\'ll get back to you within 24 hours.',
                    ),
                    FAQItem(
                      question: 'What if I need to cancel an appointment?',
                      answer: 'Currently, appointment cancellation can be done by contacting our support team through the Contact Us form. Please provide your appointment details and reason for cancellation.',
                    ),
                    FAQItem(
                      question: 'Are the nurses qualified and verified?',
                      answer: 'Yes, all our nurses are professionally qualified, licensed, and thoroughly verified. We conduct background checks and ensure they meet our high standards for patient care.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Contact Us Tab (existing code)
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Contact Us', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Phone Number with Country Code
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phone Number (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Country Code Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: selectedCountryCode,
                              underline: const SizedBox(),
                              items: countryCodes.map((code) {
                                return DropdownMenuItem<String>(
                                  value: code['code'] as String,
                                  child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedCountryCode = value!);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Phone Number Field
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(selectedCountryCode), // Rebuild when country changes
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              autocorrect: false,
                              enableSuggestions: false,
                              enableInteractiveSelection: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(getPhoneNumberLength()),
                              ],
                              decoration: InputDecoration(
                                hintText: getPhonePlaceholder(),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Subject is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 6,
                    maxLength: 1000,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Message is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Message must be at least 10 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _submitContactForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2260FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send Message',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection(String title, List<FAQItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2260FF)),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => _buildFAQItem(item)).toList(),
      ],
    );
  }

  Widget _buildFAQItem(FAQItem item) {
    return ExpansionTile(
      title: Text(
        item.question,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            item.answer,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}
