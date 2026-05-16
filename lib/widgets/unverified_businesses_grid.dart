import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';

class UnverifiedBusinessesGrid extends ConsumerWidget {
  const UnverifiedBusinessesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(dashboardSelectedCategoryProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: selectedCategory != null
          ? _UserListView(category: selectedCategory)
          : const _CategoryGridView(),
    );
  }
}

class _CategoryGridView extends ConsumerWidget {
  const _CategoryGridView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryCountsAsync = ref.watch(categoryCountsProvider);

    return categoryCountsAsync.when(
      data: (categoryCounts) {
        final categories = [
          'House cleaning', 'Pest control', 'Tank cleaning',
          'Electricians', 'Plumbers',
          'AC Repair', 'Fridge Repair', 'Washing Machine Repair',
          'CCTV Installation', 'Water Purifier Repair', 'Kitchen Appliances Repair',
          'TV Repair', 'Phone & System Repairs',
          'Wood Works', 'Glass Design Works', 'Interior Designers',
          'Ceiling', 'Tiles', 'Painters',
          'Purohith', 'Wedding Halls', 'Photographers', 'Catering',
          'Shamiyana', 'Bridal and Groom Makeup', 'Beauty Services',
          'Mehandi Artists', 'Other Event Services',
          'Astrologers', 'Packers and Movers',
          'Car Mechanic', 'Bike Mechanic',
          'Car Drivers', 'Car Travels', 'Autos',
          'Welders', 'Builders & Contractors',
          'Ambulance', 'Diagnostic Centers', 'Others',
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 8 : (MediaQuery.of(context).size.width > 800 ? 4 : 2),
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final count = categoryCounts[category] ?? 0;

            return InkWell(
              onTap: () {
                ref.read(dashboardSelectedCategoryProvider.notifier).state = category;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: count > 0 ? const Color(0xFF2563EB).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                    width: count > 0 ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      size: 32,
                      color: count > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: count > 0 ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: count > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count unverified',
                        style: GoogleFonts.poppins(
                          color: count > 0 ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (error, _) => Center(child: Text('Error loading categories: $error')),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'house cleaning': case 'pest control': case 'tank cleaning': return Icons.cleaning_services;
      case 'electricians': case 'plumbers': return Icons.electrical_services;
      case 'ac repair': case 'fridge repair': case 'washing machine repair':
      case 'cctv installation': case 'water purifier repair': case 'kitchen appliances repair':
      case 'tv repair': case 'phone & system repairs': return Icons.build;
      case 'wood works': case 'glass design works': case 'interior designers': return Icons.carpenter;
      case 'ceiling': case 'tiles': return Icons.home_repair_service;
      case 'painters': return Icons.format_paint;
      case 'purohith': case 'wedding halls': case 'photographers': case 'catering':
      case 'shamiyana': case 'bridal and groom makeup': case 'beauty services':
      case 'mehandi artists': case 'other event services': return Icons.celebration;
      case 'astrologers': return Icons.psychology;
      case 'packers and movers': return Icons.local_shipping;
      case 'car mechanic': case 'bike mechanic': return Icons.two_wheeler;
      case 'car drivers': case 'car travels': case 'autos': return Icons.directions_car;
      case 'welders': return Icons.hardware;
      case 'builders & contractors': return Icons.construction;
      case 'ambulance': case 'diagnostic centers': return Icons.medical_services;
      default: return Icons.category;
    }
  }
}

class _UserListView extends ConsumerWidget {
  final String category;
  const _UserListView({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(unverifiedUsersByCategoryProvider(category));
    final citiesAsync = ref.watch(unverifiedCitiesProvider);
    final selectedCity = ref.watch(dashboardSelectedCityProvider);

    return Column(
      children: [
        // Header with Back button and City Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => ref.read(dashboardSelectedCategoryProvider.notifier).state = null,
                ),
                Text(
                  category,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            // City Filter
            citiesAsync.when(
              data: (cities) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: DropdownButton<String?>(
                  value: selectedCity,
                  hint: const Text('All Cities'),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.location_on, size: 16, color: Color(0xFF2563EB)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Cities')),
                    ...cities.map((city) => DropdownMenuItem(value: city, child: Text(city))),
                  ],
                  onChanged: (v) => ref.read(dashboardSelectedCityProvider.notifier).state = v,
                ),
              ),
              loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return Container(
                height: 200,
                alignment: Alignment.center,
                child: Text('No unverified users found', style: GoogleFonts.poppins(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  elevation: 0,
                  borderOnForeground: true,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: user['businesspic'] != null ? NetworkImage(user['businesspic']) : null,
                      child: user['businesspic'] == null ? const Icon(Icons.business) : null,
                    ),
                    title: Text(user['businessname'] ?? 'No Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['email'] ?? 'No Email', style: GoogleFonts.poppins(fontSize: 12)),
                        Text(user['address'] ?? 'No Address', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Color(0xFF2563EB)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BusinessProfilePage(businessData: user)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _confirmVerify(context, ref, user['id'], user['businessname']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
        ),
      ],
    );
  }

  void _confirmVerify(BuildContext context, WidgetRef ref, String id, String? name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Business'),
        content: Text('Verify $name and allow them to take service requests?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(userVerificationProvider.notifier).verifyUser(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
