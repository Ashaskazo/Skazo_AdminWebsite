import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/user_providers.dart';

class BusinessProfilePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> businessData;

  const BusinessProfilePage({super.key, required this.businessData});

  @override
  ConsumerState<BusinessProfilePage> createState() =>
      _BusinessProfilePageState();
}

class _BusinessProfilePageState extends ConsumerState<BusinessProfilePage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _verifyBusiness() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify Business'),
          content: const Text('Are you sure you want to verify this business?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final verificationNotifier = ref.read(userVerificationProvider.notifier);
      final success = await verificationNotifier.verifyUser(
        widget.businessData['id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Business verified successfully'
                  : 'Error verifying business',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying business: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchCall(String phoneNumber) async {
    // Clean the phone number to ensure it's in a valid format
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Create the URI with the cleaned number
    final Uri callUri = Uri(scheme: 'tel', path: cleanedNumber);

    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch call to $cleanedNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
    final Uri url = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch maps for $address'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.businessData;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Business Profile',
          style: GoogleFonts.nunitoSans(
            fontWeight: FontWeight.bold,
            fontSize: 21,
          ),
        ),
        actions: [
          if (!business['isverified'])
            IconButton(
              icon: const Icon(Icons.verified_user),
              onPressed: _isLoading ? null : _verifyBusiness,
              tooltip: 'Verify Business',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Profile header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile image
                      CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          business['businesspic'] ??
                              'https://via.placeholder.com/150',
                        ),
                        radius: 42,
                      ),
                      const SizedBox(width: 12),
                      // Business details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business['businessname'] ?? 'No Name',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  business['isverified']
                                      ? Icons.verified
                                      : Icons.pending,
                                  color:
                                      business['isverified']
                                          ? Colors.green
                                          : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child:
                                      business['category'] == null
                                          ? Text(
                                            'No Category',
                                            style: GoogleFonts.nunitoSans(
                                              fontSize: 16,
                                            ),
                                          )
                                          : Wrap(
                                            spacing: 4,
                                            runSpacing: 0,
                                            children:
                                                (business['category'] is List
                                                        ? List<String>.from(
                                                          business['category'],
                                                        )
                                                        : [
                                                          business['category']
                                                              .toString(),
                                                        ])
                                                    .map(
                                                      (cat) => Chip(
                                                        label: Text(
                                                          cat,
                                                          style:
                                                              GoogleFonts.nunitoSans(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                        backgroundColor: Colors
                                                            .blue
                                                            .withOpacity(0.1),
                                                        labelStyle:
                                                            const TextStyle(
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                ),
                              ],
                            ),
                            if (business['avgRating'] != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                  ),
                                  Text(
                                    '${business['avgRating']} (${business['totalRatings'] ?? 0})',
                                    style: GoogleFonts.nunitoSans(fontSize: 16),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Business bio
                  Text(
                    'About',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Text(
                        business['businessbio'] ?? 'No description available',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              () => _launchCall(business['phone'].toString()),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              () => _launchMaps(business['businessaddress']),
                          icon: const Icon(Icons.location_on),
                          label: const Text('Location'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // TabBar
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library),
                    const SizedBox(width: 8),
                    Text('Gallery', style: GoogleFonts.nunitoSans()),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.reviews),
                    const SizedBox(width: 8),
                    Text('Reviews', style: GoogleFonts.nunitoSans()),
                  ],
                ),
              ),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Gallery Tab
                FutureBuilder<QuerySnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(business['id'])
                          .collection('gallery')
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No photos available'));
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final photo = snapshot.data!.docs[index];
                        return CachedNetworkImage(
                          imageUrl: photo['url'],
                          fit: BoxFit.cover,
                        );
                      },
                    );
                  },
                ),
                // Reviews Tab
                FutureBuilder<QuerySnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(business['id'])
                          .collection('reviews')
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No reviews yet'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final review = snapshot.data!.docs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: ListTile(
                            title: Row(
                              children: [
                                Text(review['userName'] ?? 'Anonymous'),
                                const Spacer(),
                                Row(
                                  children: List.generate(
                                    review['rating'].toInt(),
                                    (index) => const Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(review['comment'] ?? ''),
                          ),
                        );
                      },
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
