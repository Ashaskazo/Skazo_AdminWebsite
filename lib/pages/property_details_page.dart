import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PropertyDetailsPage extends StatefulWidget {
  final Map<String, dynamic> propertyData;

  const PropertyDetailsPage({super.key, required this.propertyData});

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  late Map<String, dynamic> _editedData;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editedData = Map<String, dynamic>.from(widget.propertyData);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final docId = _editedData['id'];
      if (docId == null) throw 'Document ID not found';

      final dataToSave = Map<String, dynamic>.from(_editedData);
      dataToSave.remove('id'); // Don't save the ID back into the document fields

      await FirebaseFirestore.instance
          .collection('rental_properties')
          .doc(docId)
          .update(dataToSave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating property: $e')),
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
          'Edit Property Details',
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
            // Image Preview Section
            _buildImageSection(),
            const SizedBox(height: 32),

            // Main Info Section
            _buildSectionHeader('Basic Information'),
            _buildGridFields([
              _buildTextField('propertyName', 'Property Name'),
              _buildTextField('type', 'Property Type'),
              _buildTextField('rentAmount', 'Rent Amount (₹)'),
              _buildTextField('bhk', 'BHK'),
              _buildTextField('furnishingType', 'Furnishing'),
              _buildTextField('city', 'City'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('Location Details'),
            _buildTextField('location', 'Full Address', maxLines: 2),
            const SizedBox(height: 16),
            _buildGridFields([
              _buildTextField('landmark', 'Landmark'),
              _buildTextField('area', 'Area/Plot No'),
              _buildTextField('floor', 'Floor'),
              _buildTextField('acOption', 'AC Availability'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('Listing Details'),
            _buildGridFields([
              _buildTextField('availableFrom', 'Available From'),
              _buildTextField('contactNumber', 'Contact Number'),
              _buildTextField('ownerName', 'Owner Name'),
              _buildTextField('ownerPlan', 'Owner Plan'),
            ]),
            const SizedBox(height: 16),
            _buildTextField('description', 'Description', maxLines: 3),

            const SizedBox(height: 32),
            _buildSectionHeader('Status & Visibility'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDropdownField('status', 'Status', [
                    'under_review',
                    'live',
                    'rejected',
                    'sold',
                    'rented',
                  ]),
                  const Divider(height: 32),
                  _buildSwitchTile('isPropertyVerified', 'Verified Property', 'Admin verification badge'),
                  _buildSwitchTile('isVisible', 'Show on App', 'Visible to users'),
                  _buildSwitchTile('isBoosted', 'Boosted Listing', 'Priority in search results'),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('Stats (Read Only)'),
            _buildGridFields([
              _buildReadOnlyField('viewsCount', 'Total Views'),
              _buildReadOnlyField('interestedCount', 'Interested Users'),
              _buildReadOnlyField('createdAt', 'Created Date'),
            ]),
            const SizedBox(height: 48),
          ],
        ),
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

  Widget _buildDropdownField(String key, String label, List<String> options) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: options.contains(_editedData[key]) ? _editedData[key] : options.first,
            underline: const SizedBox(),
            onChanged: (val) {
              if (val != null) setState(() => _editedData[key] = val);
            },
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String key, String title, String subtitle) {
    return SwitchListTile(
      value: _editedData[key] == true,
      onChanged: (val) => setState(() => _editedData[key] = val),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
      ),
      activeColor: const Color(0xFF2563EB),
      contentPadding: EdgeInsets.zero,
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

  Widget _buildImageSection() {
    final urls = _editedData['photoUrls'] as List?;
    if (urls == null || urls.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.no_photography_outlined, size: 48, color: Color(0xFF94A3B8)),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return Container(
            width: 350,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: NetworkImage(urls[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}
