import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                : [const Color(0xFFFFFFFF), const Color(0xFFF0F4F8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222831) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(context),
                        color: isDark ? Colors.white : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Carpool Agreement',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Last Updated: December 2024',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.handshake_rounded,
                        title: '1. Agreement to Terms',
                        content:
                        'By accessing and using the Carpool application, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to these terms, please do not use our services.',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.account_circle_rounded,
                        title: '2. User Responsibilities',
                        content:
                        'As a user of Carpool, you agree to:\n\n'
                            '• Provide accurate and complete registration information\n'
                            '• Maintain the security of your account credentials\n'
                            '• Be respectful and courteous to other users\n'
                            '• Arrive on time for scheduled rides\n'
                            '• Keep the vehicle clean if you are a passenger\n'
                            '• Report any safety concerns immediately',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.drive_eta_rounded,
                        title: '3. Driver Requirements',
                        content:
                        'All drivers must:\n\n'
                            '• Possess a valid driver\'s license\n'
                            '• Maintain proper vehicle insurance\n'
                            '• Ensure their vehicle is safe and roadworthy\n'
                            '• Follow all traffic laws and regulations\n'
                            '• Not drive under the influence of alcohol or drugs\n'
                            '• Have the right to refuse passengers for safety reasons',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.credit_card_rounded,
                        title: '4. Payment and Cancellation',
                        content:
                        'Booking and Payment:\n\n'
                            '• All bookings must be confirmed through the app\n'
                            '• Payment terms are agreed upon between driver and passenger\n'
                            '• Cancellations must be made at least 2 hours before departure\n'
                            '• Late cancellations may result in penalties\n'
                            '• Drivers may cancel rides due to emergencies or vehicle issues',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.security_rounded,
                        title: '5. Safety and Conduct',
                        content:
                        'Safety is our priority:\n\n'
                            '• Users must not engage in harassment or discrimination\n'
                            '• Smoking and illegal substances are strictly prohibited\n'
                            '• Emergency contact information should be accessible\n'
                            '• Report suspicious behavior immediately\n'
                            '• Users may be banned for violations of conduct policies',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.gavel_rounded,
                        title: '6. Liability and Insurance',
                        content:
                        'Understanding liability:\n\n'
                            '• Carpool is a platform connecting users; we are not responsible for accidents or incidents\n'
                            '• Drivers are responsible for maintaining adequate insurance\n'
                            '• Users participate at their own risk\n'
                            '• Always verify driver and passenger information before rides\n'
                            '• Report any incidents to authorities and our support team',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.privacy_tip_rounded,
                        title: '7. Privacy and Data',
                        content:
                        'Your privacy matters:\n\n'
                            '• We collect only necessary information for service provision\n'
                            '• Personal data is protected and not shared without consent\n'
                            '• Location data is used only for ride coordination\n'
                            '• You can request data deletion at any time\n'
                            '• Review our Privacy Policy for complete details',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.block_rounded,
                        title: '8. Termination',
                        content:
                        'Account termination:\n\n'
                            '• We reserve the right to suspend or terminate accounts\n'
                            '• Violations of these terms may result in immediate termination\n'
                            '• Users may delete their accounts at any time\n'
                            '• Refunds are subject to our cancellation policy',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.update_rounded,
                        title: '9. Changes to Terms',
                        content:
                        'We may update these terms:\n\n'
                            '• Users will be notified of significant changes\n'
                            '• Continued use constitutes acceptance of new terms\n'
                            '• Major changes require explicit user consent\n'
                            '• Check this page regularly for updates',
                      ),

                      _buildSection(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.contact_support_rounded,
                        title: '10. Contact Us',
                        content:
                        'Questions or concerns?\n\n'
                            '• Email: support@carpoolapp.com\n'
                            '• Phone: +92 300 1234567\n'
                            '• In-app support: Available 24/7\n'
                            '• Response time: Within 24 hours',
                      ),

                      const SizedBox(height: 32),

                      // Footer
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withOpacity(0.5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'By using Carpool, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}