import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ServicePostDetailsPage extends StatefulWidget {
  final Map<String, dynamic> postData;

  const ServicePostDetailsPage({super.key, required this.postData});

  @override
  State<ServicePostDetailsPage> createState() => _ServicePostDetailsPageState();
}

class _ServicePostDetailsPageState extends State<ServicePostDetailsPage> {
  late Map<String, dynamic> _editedData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editedData = Map<String, dynamic>.from(widget.postData);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final docId = _editedData['id'];
      if (docId == null) throw 'Document ID not found';

      final dataToSave = Map<String, dynamic>.from(_editedData);
      dataToSave.remove('id');

      await FirebaseFirestore.instance
          .collection('service_posts')
          .doc(docId)
          .update(dataToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service post updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating service post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Service Post Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.check, size: 20),
              label: Text(
                'Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User & Status Header
            _buildStatusHeader(),
            const SizedBox(height: 32),

            // Basic Info Section
            _buildSectionHeader('Basic Information'),
            _buildGridFields([
              _buildTextField('userName', 'User Name'),
              _buildTextField('userPhone', 'User Phone'),
              _buildTextField('category', 'Category'),
              _buildTextField('budget', 'Budget/Price'),
              _buildTextField('address', 'Address'),
              _buildTextField('status', 'Status'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('Job Description'),
            _buildTextField('description', 'Description', maxLines: 5),

            const SizedBox(height: 32),
            _buildSectionHeader('Technical Details'),
            _buildGridFields([
              _buildReadOnlyField('currentTier', 'Current Tier'),
              _buildReadOnlyField('sheetRow', 'Sheet Row'),
              _buildReadOnlyField('sheetSerial', 'Sheet Serial'),
              _buildReadOnlyField('geohash5', 'Geohash5'),
              _buildReadOnlyField('latitude', 'Latitude'),
              _buildReadOnlyField('longitude', 'Longitude'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('Timeline'),
            _buildGridFields([
              _buildReadOnlyField('timestamp', 'Posted On'),
              _buildReadOnlyField('nextNotificationAt', 'Next Notification'),
              _buildReadOnlyField('sheetTimestamp', 'Sheet Timestamp'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('Contacted By Providers'),
            _buildContactedList(),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final status = _editedData['status']?.toString() ?? 'pending';
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'live':
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(
              _editedData['userName']?.toString().characters.first.toUpperCase() ?? '?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editedData['userName'] ?? 'Anonymous User',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(
                  _editedData['userPhone'] ?? 'No phone provided',
                  style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildGridFields(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.5,
      children: children,
    );
  }

  Widget _buildTextField(String key, String label, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: _editedData[key]?.toString() ?? ''),
          maxLines: maxLines,
          onChanged: (val) => _editedData[key] = val,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String key, String label) {
    dynamic val = _editedData[key];
    String displayVal = val?.toString() ?? 'N/A';
    
    if (val is Timestamp) {
      displayVal = val.toDate().toString().split('.')[0];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayVal,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildContactedList() {
    final List? contacted = _editedData['contactedDetails'] as List?;
    if (contacted == null || contacted.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          'No providers have contacted this user yet.',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: contacted.length,
      itemBuilder: (context, index) {
        final provider = contacted[index] as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF1F5F9),
                child: Icon(Icons.person, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['businessName'] ?? provider['name'] ?? 'Unknown Provider',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Phone: ${provider['phone']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Plan: ${provider['activePlan']}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (provider['timestamp'] != null)
                    Text(
                      (provider['timestamp'] as Timestamp).toDate().toString().split(' ')[0],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
