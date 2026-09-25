/// Represents an official PIN-code group for the Hyderabad Service Providers view.
class ServiceProviderAreaGroup {
  final String displayName;
  final List<String> pincodes;

  const ServiceProviderAreaGroup({
    required this.displayName,
    required this.pincodes,
  });

  /// Checks if a given normalized 6-digit pincode belongs to this group.
  bool matchesPincode(String? pincode) {
    if (pincode == null) return false;
    final normalized = pincode.trim();
    return pincodes.contains(normalized);
  }
}

/// The 10 exact Hyderabad area groups with their assigned PIN codes.
const kHyderabadAreaGroups = <ServiceProviderAreaGroup>[
  ServiceProviderAreaGroup(
    displayName: 'Abids',
    pincodes: [
      '500001',
      '500012',
      '500022',
      '500095',
      '500102',
      '500104',
      '500106',
      '500108',
      '500109',
      '500110',
      '500111',
      '500112',
      '500114',
      '500117',
      '500118',
      '500119',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Old City',
    pincodes: [
      '500002',
      '500023',
      '500024',
      '500053',
      '500064',
      '500065',
      '500066',
      '500068',
      '500069',
      '500070',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Mehdipatnam',
    pincodes: [
      '500006',
      '500028',
      '500030',
      '500048',
      '500058',
      '500059',
      '500060',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Jubilee Hills',
    pincodes: [
      '500033',
      '500034',
      '500041',
      '500073',
      '500082',
      '500096',
      '501203',
      '501218',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'HITEC City',
    pincodes: [
      '500032',
      '500075',
      '500081',
      '500084',
      '500089',
      '500931',
      '500934',
      '500939',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Kukatpally',
    pincodes: [
      '500049',
      '500050',
      '500072',
      '500085',
      '500090',
      '500901',
      '500918',
      '500920',
      '500927',
      '500930',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Sanathnagar',
    pincodes: [
      '500011',
      '500018',
      '500037',
      '500054',
      '500055',
      '500067',
      '500984',
      '500989',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Secunderabad',
    pincodes: [
      '500003',
      '500009',
      '500010',
      '500015',
      '500016',
      '500017',
      '500047',
      '500056',
      '502032',
      '502033',
      '502034',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Uppal',
    pincodes: [
      '500039',
      '500044',
      '500061',
      '500062',
      '500076',
      '500094',
      '500325',
      '500307',
      '502300',
      '502305',
      '502307',
      '502319',
      '502324',
      '502325',
      '502329',
    ],
  ),

  ServiceProviderAreaGroup(
    displayName: 'Dilsukhnagar',
    pincodes: [
      '500035',
      '500036',
      '500058',
      '500059',
      '500060',
      '500068',
      '500069',
      '500070',
      '500074',
      '500079',
      '509216',
      '509325',
    ],
  ),
];

/// Finds which Hyderabad area group a given 6-digit PIN code belongs to.
/// Returns null if the PIN code is not in any of the 10 configured groups.
ServiceProviderAreaGroup? findHyderabadAreaGroupForPincode(String? pincode) {
  if (pincode == null) return null;
  final normalized = pincode.trim();
  for (final group in kHyderabadAreaGroups) {
    if (group.pincodes.contains(normalized)) {
      return group;
    }
  }
  return null;
}

/// Checks if a city name represents Hyderabad (case-insensitive).
bool isCityHyderabad(String? city) {
  if (city == null) return false;
  return city.trim().toLowerCase() == 'hyderabad';
}
