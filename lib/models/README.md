# User Model Documentation

## Current Implementation

The admin dashboard currently uses `Map<String, dynamic>` directly from Firestore for user data instead of a dedicated User model class. This approach provides flexibility and avoids dependency issues.

## User Data Structure

The user data structure supports both single category (string) and multiple categories (list) for backward compatibility:

```dart
{
  'businessname': String,
  'businessbio': String,
  'businessaddress': String,
  'businesspic': String,
  'category': List<String> | String, // Supports both formats
  'coordinates': List,
  'email': String,
  'username': String,
  'gender': String,
  'firstname': String,
  'lastname': String,
  'fcmtoken': String,
  'uid': String,
  'geohash5': String,
  'geohash7': String,
  'isonline': bool,
  'phone': int,
  'isuser': bool,
  'isactive': bool,
  'isverified': bool,
  'avgRating': double,
  'totalRatings': int,
  'ratingSum': double,
}
```

## Category Support

The system now supports multiple categories per business:
- **Old format**: Single string category
- **New format**: List of string categories

The providers handle both formats automatically for backward compatibility.

## Available Categories

1. **Cleaning Services**
   - House cleaning
   - Pest control
   - Tank cleaning

2. **Electricians & Plumbers**
   - Electricians
   - Plumbers

3. **Technicians**
   - AC Repair
   - Fridge Repair
   - Washing Machine Repair
   - CCTV Installation
   - Water Purifier Repair
   - Kitchen Appliances Repair
   - TV Repair
   - Phone & System Repairs

4. **Carpenters**
   - Wood Works
   - Glass Design Works
   - Interior Designers

5. **Ceiling & Tiles**
   - Ceiling
   - Tiles

6. **Painters**
   - Painters

7. **Events**
   - Purohith
   - Wedding Halls
   - Photographers
   - Catering
   - Shamiyana
   - Bridal and Groom Makeup
   - Beauty Services
   - Mehandi Artists
   - Other Event Services

8. **Astrologers**
   - Astrologers

9. **Packers and Movers**
   - Packers and Movers

10. **Mechanic**
    - Car Mechanic
    - Bike Mechanic

11. **Travels**
    - Car Drivers
    - Car Travels
    - Autos

12. **Welders**
    - Welders

13. **Builders & Contractors**
    - Builders & Contractors

14. **Medical Services**
    - Ambulance
    - Diagnostic Centers

15. **Others**
    - Others 