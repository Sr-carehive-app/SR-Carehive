import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewProfileDetailsScreen extends StatefulWidget {
  const ViewProfileDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ViewProfileDetailsScreen> createState() =>
      _ViewProfileDetailsScreenState();
}

class _ViewProfileDetailsScreenState extends State<ViewProfileDetailsScreen> {
  final primaryColor = const Color(0xFF2260FF);
  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final patient =
            await supabase
                .from('patients')
                .select()
                .eq('user_id', user.id)
                .single();

        setState(() {
          profileData = patient;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _buildFullName() {
    if (profileData == null) return 'User';

    String name = '';
    final salutation = profileData!['salutation'] ?? '';

    if (salutation.isNotEmpty) name += '$salutation ';

    if (profileData!['first_name'] != null) {
      name += profileData!['first_name'];
      if (profileData!['middle_name'] != null &&
          profileData!['middle_name'].toString().isNotEmpty) {
        name += ' ${profileData!['middle_name']}';
      }
      if (profileData!['last_name'] != null) {
        name += ' ${profileData!['last_name']}';
      }
    } else if (profileData!['name'] != null) {
      name += profileData!['name'];
    }

    return name.trim();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Profile Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body:
          isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2260FF)),
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Compact Header Section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Profile Image - Tappable
                          GestureDetector(
                            onTap: () {
                              if (profileData?['profile_image_url'] != null &&
                                  profileData!['profile_image_url']
                                      .toString()
                                      .isNotEmpty) {
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black87,
                                  builder:
                                      (context) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: InteractiveViewer(
                                                minScale: 0.5,
                                                maxScale: 4.0,
                                                child: Image.network(
                                                  profileData!['profile_image_url'],
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: isTablet ? 50 : 45,
                                backgroundColor: Colors.white,
                                backgroundImage:
                                    profileData?['profile_image_url'] != null &&
                                            profileData!['profile_image_url']
                                                .toString()
                                                .isNotEmpty
                                        ? NetworkImage(
                                          profileData!['profile_image_url'],
                                        )
                                        : const AssetImage(
                                              'assets/images/user.png',
                                            )
                                            as ImageProvider,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Name
                          Text(
                            _buildFullName(),
                            style: TextStyle(
                              fontSize: isTablet ? 22 : 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Email badge
                          if (profileData?['email'] != null &&
                              profileData!['email'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              profileData!['email'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    // Content with modern cards
                    Padding(
                      padding: EdgeInsets.all(isTablet ? 24 : 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                isDesktop
                                    ? 800
                                    : (isTablet ? 650 : double.infinity),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Personal Information
                              if (profileData?['gender'] != null ||
                                  profileData?['age'] != null)
                                _buildModernSection(
                                  title: 'Personal Information',
                                  icon: Icons.person_outlined,
                                  iconColor: primaryColor,
                                  items: [
                                    if (profileData?['gender'] != null)
                                      _buildModernInfoRow(
                                        icon: Icons.person_outline,
                                        label: 'Gender',
                                        value: profileData!['gender'],
                                        iconBg: primaryColor,
                                      ),
                                    if (profileData?['age'] != null)
                                      _buildModernInfoRow(
                                        icon: Icons.cake_outlined,
                                        label: 'Age',
                                        value: '${profileData!['age']} years',
                                        iconBg: primaryColor,
                                      ),
                                  ],
                                ),

                              const SizedBox(height: 16),

                              // Contact Section
                              _buildModernSection(
                                title: 'Contact Information',
                                icon: Icons.phone_in_talk_outlined,
                                iconColor: const Color(0xFF10B981),
                                items: [
                                  if (profileData?['aadhar_linked_phone'] !=
                                          null)
                                    _buildModernInfoRow(
                                      icon: Icons.phone_android,
                                      label: 'Primary Phone (Aadhar Linked)',
                                      value:
                                          '${profileData?['country_code'] ?? '+91'} ${profileData!['aadhar_linked_phone']}',
                                      iconBg: const Color(0xFF10B981),
                                    ),
                                  if (profileData?['alternative_phone'] !=
                                          null &&
                                      profileData!['alternative_phone']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.phone_iphone,
                                      label: 'Alternative Phone',
                                      value:
                                          '${profileData?['country_code'] ?? '+91'} ${profileData!['alternative_phone']}',
                                      iconBg: const Color(0xFF059669),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Address Section
                              _buildModernSection(
                                title: 'Address',
                                icon: Icons.location_on_outlined,
                                iconColor: const Color(0xFFEF4444),
                                items: [
                                  if (profileData?['house_number'] != null &&
                                      profileData!['house_number']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.home_outlined,
                                      label: 'House/Flat Number',
                                      value: profileData!['house_number'],
                                      iconBg: const Color(0xFFEF4444),
                                    ),
                                  if (profileData?['town'] != null &&
                                      profileData!['town']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.location_city_outlined,
                                      label: 'Town/Village/Locality',
                                      value: profileData!['town'],
                                      iconBg: const Color(0xFFDC2626),
                                    ),
                                  if (profileData?['city'] != null &&
                                      profileData!['city']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.apartment_outlined,
                                      label: 'City',
                                      value: profileData!['city'],
                                      iconBg: const Color(0xFFF97316),
                                    ),
                                  if (profileData?['state'] != null &&
                                      profileData!['state']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.map_outlined,
                                      label: 'State',
                                      value: profileData!['state'],
                                      iconBg: const Color(0xFFEA580C),
                                    ),
                                  if (profileData?['pincode'] != null &&
                                      profileData!['pincode']
                                          .toString()
                                          .isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.pin_drop_outlined,
                                      label: 'Pincode',
                                      value: profileData!['pincode'],
                                      iconBg: const Color(0xFFF59E0B),
                                    ),
                                ],
                              ),

                              // Identification
                              if (profileData?['aadhar_number'] != null &&
                                  profileData!['aadhar_number']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildModernSection(
                                  title: 'Identification',
                                  icon: Icons.verified_user_outlined,
                                  iconColor: const Color(0xFF8B5CF6),
                                  items: [
                                    _buildModernInfoRow(
                                      icon: Icons.credit_card,
                                      label: 'Aadhar Number',
                                      value: profileData!['aadhar_number'],
                                      iconBg: const Color(0xFF8B5CF6),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconBg,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconBg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _maskAadhar(String aadhar) {
    // Remove any spaces or hyphens first
    final cleanAadhar = aadhar.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanAadhar.length != 12) return aadhar;

    // Format as XXXX XXXX 1234
    final lastFour = cleanAadhar.substring(8);
    return 'XXXX XXXX $lastFour';
  }
}
