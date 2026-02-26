class Country {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final int phoneLength;
  final String? phoneRegex;

  const Country({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.phoneLength,
    this.phoneRegex,
  });

  String get displayName => '$flag $name ($dialCode)';
  String get flagWithCode => '$flag $dialCode';
}

class Countries {
  // Arab Countries - Static Constants

  /// Egypt
  static const Country egypt = Country(
    name: 'Egypt',
    code: 'EG',
    dialCode: '+20',
    flag: '🇪🇬',
    phoneLength: 10,
    phoneRegex: r'^1[0-2,5]{1}[0-9]{8}$', // 10 أرقام: 1[0125]XXXXXXXX
  );

  /// Saudi Arabia
  static const Country saudiArabia = Country(
    name: 'Saudi Arabia',
    code: 'SA',
    dialCode: '+966',
    flag: '🇸🇦',
    phoneLength: 9,
    phoneRegex: r'^5[0-9]{8}$', // 9 أرقام: 5XXXXXXXX
  );

  /// United Arab Emirates
  static const Country uae = Country(
    name: 'United Arab Emirates',
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
    phoneLength: 9,
    phoneRegex: r'^5[0-9]{8}$', // 9 أرقام: 5XXXXXXXX
  );

  /// Kuwait
  static const Country kuwait = Country(
    name: 'Kuwait',
    code: 'KW',
    dialCode: '+965',
    flag: '🇰🇼',
    phoneLength: 8,
    phoneRegex: r'^[5-9][0-9]{7}$', // 8 أرقام: يبدأ بـ 5-9
  );

  /// Qatar
  static const Country qatar = Country(
    name: 'Qatar',
    code: 'QA',
    dialCode: '+974',
    flag: '🇶🇦',
    phoneLength: 8,
    phoneRegex: r'^[3-7][0-9]{7}$', // 8 أرقام: يبدأ بـ 3-7
  );

  /// Bahrain
  static const Country bahrain = Country(
    name: 'Bahrain',
    code: 'BH',
    dialCode: '+973',
    flag: '🇧🇭',
    phoneLength: 8,
    phoneRegex: r'^[3-6][0-9]{7}$', // 8 أرقام: يبدأ بـ 3-6
  );

  /// Oman
  static const Country oman = Country(
    name: 'Oman',
    code: 'OM',
    dialCode: '+968',
    flag: '🇴🇲',
    phoneLength: 8,
    phoneRegex: r'^[7-9][0-9]{7}$', // 8 أرقام: يبدأ بـ 7-9
  );

  /// Jordan
  static const Country jordan = Country(
    name: 'Jordan',
    code: 'JO',
    dialCode: '+962',
    flag: '🇯🇴',
    phoneLength: 9,
    phoneRegex: r'^7[0-9]{8}$', // 9 أرقام: 7XXXXXXXX
  );

  /// Lebanon
  static const Country lebanon = Country(
    name: 'Lebanon',
    code: 'LB',
    dialCode: '+961',
    flag: '🇱🇧',
    phoneLength: 8,
    phoneRegex: r'^[3-7][0-9]{7}$', // 8 أرقام: يبدأ بـ 3-7
  );

  /// Iraq
  static const Country iraq = Country(
    name: 'Iraq',
    code: 'IQ',
    dialCode: '+964',
    flag: '🇮🇶',
    phoneLength: 10,
    phoneRegex: r'^7[0-9]{9}$', // 10 أرقام: 7XXXXXXXXX
  );

  /// Syria
  static const Country syria = Country(
    name: 'Syria',
    code: 'SY',
    dialCode: '+963',
    flag: '🇸🇾',
    phoneLength: 9,
    phoneRegex: r'^9[0-9]{8}$', // 9 أرقام: 9XXXXXXXX
  );

  /// Palestine
  static const Country palestine = Country(
    name: 'Palestine',
    code: 'PS',
    dialCode: '+970',
    flag: '🇵🇸',
    phoneLength: 9,
    phoneRegex: r'^5[0-9]{8}$', // 9 أرقام: 5XXXXXXXX
  );

  /// Tunisia
  static const Country tunisia = Country(
    name: 'Tunisia',
    code: 'TN',
    dialCode: '+216',
    flag: '🇹🇳',
    phoneLength: 8,
    phoneRegex: r'^[2-5][0-9]{7}$', // 8 أرقام: يبدأ بـ 2-5
  );

  /// Algeria
  static const Country algeria = Country(
    name: 'Algeria',
    code: 'DZ',
    dialCode: '+213',
    flag: '🇩🇿',
    phoneLength: 9,
    phoneRegex: r'^[5-7][0-9]{8}$', // 9 أرقام: يبدأ بـ 5-7
  );

  /// Morocco
  static const Country morocco = Country(
    name: 'Morocco',
    code: 'MA',
    dialCode: '+212',
    flag: '🇲🇦',
    phoneLength: 9,
    phoneRegex: r'^[6-7][0-9]{8}$', // 9 أرقام: يبدأ بـ 6-7
  );

  /// Libya
  static const Country libya = Country(
    name: 'Libya',
    code: 'LY',
    dialCode: '+218',
    flag: '🇱🇾',
    phoneLength: 10,
    phoneRegex: r'^9[0-9]{9}$', // 10 أرقام: 9XXXXXXXXX
  );

  /// Sudan
  static const Country sudan = Country(
    name: 'Sudan',
    code: 'SD',
    dialCode: '+249',
    flag: '🇸🇩',
    phoneLength: 9,
    phoneRegex: r'^9[0-9]{8}$', // 9 أرقام: 9XXXXXXXX
  );

  /// Yemen
  static const Country yemen = Country(
    name: 'Yemen',
    code: 'YE',
    dialCode: '+967',
    flag: '🇾🇪',
    phoneLength: 9,
    phoneRegex: r'^7[0-9]{8}$', // 9 أرقام: 7XXXXXXXX
  );

  // Major Countries - Static Constants

  /// United States
  static const Country usa = Country(
    name: 'United States',
    code: 'US',
    dialCode: '+1',
    flag: '🇺🇸',
    phoneLength: 10,
    phoneRegex: r'^[2-9][0-9]{2}[2-9][0-9]{6}$', // US format: XXX-XXX-XXXX
  );

  /// United Kingdom
  static const Country uk = Country(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    flag: '🇬🇧',
    phoneLength: 10,
    phoneRegex: r'^7[0-9]{9}$', // 07XXX XXXXXX
  );

  /// Canada
  static const Country canada = Country(
    name: 'Canada',
    code: 'CA',
    dialCode: '+1',
    flag: '🇨🇦',
    phoneLength: 10,
    phoneRegex: r'^[2-9][0-9]{2}[2-9][0-9]{6}$', // Same as US
  );

  /// Germany
  static const Country germany = Country(
    name: 'Germany',
    code: 'DE',
    dialCode: '+49',
    flag: '🇩🇪',
    phoneLength: 10,
    phoneRegex: r'^1[5-7][0-9]{8}$', // Mobile: 15X, 16X, 17X
  );

  /// France
  static const Country france = Country(
    name: 'France',
    code: 'FR',
    dialCode: '+33',
    flag: '🇫🇷',
    phoneLength: 9,
    phoneRegex: r'^[6-7][0-9]{8}$', // Mobile: 6X, 7X
  );

  /// Italy
  static const Country italy = Country(
    name: 'Italy',
    code: 'IT',
    dialCode: '+39',
    flag: '🇮🇹',
    phoneLength: 10,
    phoneRegex: r'^3[0-9]{9}$', // Mobile: 3XX XXX XXXX
  );

  /// Spain
  static const Country spain = Country(
    name: 'Spain',
    code: 'ES',
    dialCode: '+34',
    flag: '🇪🇸',
    phoneLength: 9,
    phoneRegex: r'^[6-7][0-9]{8}$', // Mobile: 6X, 7X
  );

  /// Turkey
  static const Country turkey = Country(
    name: 'Turkey',
    code: 'TR',
    dialCode: '+90',
    flag: '🇹🇷',
    phoneLength: 10,
    phoneRegex: r'^5[0-9]{9}$', // Mobile: 5XX XXX XXXX
  );

  /// India
  static const Country india = Country(
    name: 'India',
    code: 'IN',
    dialCode: '+91',
    flag: '🇮🇳',
    phoneLength: 10,
    phoneRegex: r'^[6-9][0-9]{9}$', // Mobile: 6-9XXXXXXXXX
  );

  /// Pakistan
  static const Country pakistan = Country(
    name: 'Pakistan',
    code: 'PK',
    dialCode: '+92',
    flag: '🇵🇰',
    phoneLength: 10,
    phoneRegex: r'^3[0-9]{9}$', // Mobile: 3XXXXXXXXX
  );

  /// Bangladesh
  static const Country bangladesh = Country(
    name: 'Bangladesh',
    code: 'BD',
    dialCode: '+880',
    flag: '🇧🇩',
    phoneLength: 10,
    phoneRegex: r'^1[3-9][0-9]{8}$', // Mobile: 13X-19X
  );

  /// China
  static const Country china = Country(
    name: 'China',
    code: 'CN',
    dialCode: '+86',
    flag: '🇨🇳',
    phoneLength: 11,
    phoneRegex: r'^1[3-9][0-9]{9}$', // Mobile: 1XX XXXX XXXX
  );

  /// Japan
  static const Country japan = Country(
    name: 'Japan',
    code: 'JP',
    dialCode: '+81',
    flag: '🇯🇵',
    phoneLength: 10,
    phoneRegex: r'^[7-9]0[0-9]{8}$', // Mobile: 70X, 80X, 90X
  );

  /// South Korea
  static const Country southKorea = Country(
    name: 'South Korea',
    code: 'KR',
    dialCode: '+82',
    flag: '🇰🇷',
    phoneLength: 10,
    phoneRegex: r'^1[0-9]{9}$', // Mobile: 10XX XXXX
  );

  /// Indonesia
  static const Country indonesia = Country(
    name: 'Indonesia',
    code: 'ID',
    dialCode: '+62',
    flag: '🇮🇩',
    phoneLength: 10,
    phoneRegex: r'^8[0-9]{9}$', // Mobile: 8XXXXXXXXX
  );

  /// Malaysia
  static const Country malaysia = Country(
    name: 'Malaysia',
    code: 'MY',
    dialCode: '+60',
    flag: '🇲🇾',
    phoneLength: 9,
    phoneRegex: r'^1[0-9]{8}$', // Mobile: 1XXXXXXXX
  );

  /// Singapore
  static const Country singapore = Country(
    name: 'Singapore',
    code: 'SG',
    dialCode: '+65',
    flag: '🇸🇬',
    phoneLength: 8,
    phoneRegex: r'^[8-9][0-9]{7}$', // Mobile: 8XXXXXXX, 9XXXXXXX
  );

  /// Philippines
  static const Country philippines = Country(
    name: 'Philippines',
    code: 'PH',
    dialCode: '+63',
    flag: '🇵🇭',
    phoneLength: 10,
    phoneRegex: r'^9[0-9]{9}$', // Mobile: 9XXXXXXXXX
  );

  /// Thailand
  static const Country thailand = Country(
    name: 'Thailand',
    code: 'TH',
    dialCode: '+66',
    flag: '🇹🇭',
    phoneLength: 9,
    phoneRegex: r'^[6-9][0-9]{8}$', // Mobile: 6X, 8X, 9X
  );

  /// Vietnam
  static const Country vietnam = Country(
    name: 'Vietnam',
    code: 'VN',
    dialCode: '+84',
    flag: '🇻🇳',
    phoneLength: 9,
    phoneRegex: r'^[3-9][0-9]{8}$', // Mobile: 3X-9X
  );

  /// Australia
  static const Country australia = Country(
    name: 'Australia',
    code: 'AU',
    dialCode: '+61',
    flag: '🇦🇺',
    phoneLength: 9,
    phoneRegex: r'^4[0-9]{8}$', // Mobile: 4XX XXX XXX
  );

  /// New Zealand
  static const Country newZealand = Country(
    name: 'New Zealand',
    code: 'NZ',
    dialCode: '+64',
    flag: '🇳🇿',
    phoneLength: 9,
    phoneRegex: r'^2[0-9]{8}$', // Mobile: 2X XXX XXXX
  );

  /// Brazil
  static const Country brazil = Country(
    name: 'Brazil',
    code: 'BR',
    dialCode: '+55',
    flag: '🇧🇷',
    phoneLength: 11,
    phoneRegex: r'^[1-9][1-9]9[0-9]{8}$', // Mobile: DD + 9XXXXXXXX
  );

  /// Mexico
  static const Country mexico = Country(
    name: 'Mexico',
    code: 'MX',
    dialCode: '+52',
    flag: '🇲🇽',
    phoneLength: 10,
    phoneRegex: r'^1[0-9]{9}$', // Mobile: 1XX XXX XXXX
  );

  /// Argentina
  static const Country argentina = Country(
    name: 'Argentina',
    code: 'AR',
    dialCode: '+54',
    flag: '🇦🇷',
    phoneLength: 10,
    phoneRegex: r'^9[0-9]{9}$', // Mobile: 9XXXXXXXXX
  );

  /// Russia
  static const Country russia = Country(
    name: 'Russia',
    code: 'RU',
    dialCode: '+7',
    flag: '🇷🇺',
    phoneLength: 10,
    phoneRegex: r'^9[0-9]{9}$', // Mobile: 9XXXXXXXXX
  );

  /// South Africa
  static const Country southAfrica = Country(
    name: 'South Africa',
    code: 'ZA',
    dialCode: '+27',
    flag: '🇿🇦',
    phoneLength: 9,
    phoneRegex: r'^[6-8][0-9]{8}$', // Mobile: 6X, 7X, 8X
  );

  /// Nigeria
  static const Country nigeria = Country(
    name: 'Nigeria',
    code: 'NG',
    dialCode: '+234',
    flag: '🇳🇬',
    phoneLength: 10,
    phoneRegex: r'^[7-9][0-9]{9}$', // Mobile: 70X, 80X, 90X
  );

  /// Kenya
  static const Country kenya = Country(
    name: 'Kenya',
    code: 'KE',
    dialCode: '+254',
    flag: '🇰🇪',
    phoneLength: 9,
    phoneRegex: r'^7[0-9]{8}$', // Mobile: 7XXXXXXXX
  );

  //  All Countries List (Using Static Constants)
  static const List<Country> all = [
    // Arab Countries
    egypt,
    saudiArabia,
    uae,
    kuwait,
    qatar,
    bahrain,
    oman,
    jordan,
    lebanon,
    iraq,
    syria,
    palestine,
    tunisia,
    algeria,
    morocco,
    libya,
    sudan,
    yemen,

    // Major Countries
    usa,
    uk,
    canada,
    germany,
    france,
    italy,
    spain,
    turkey,
    india,
    pakistan,
    bangladesh,
    china,
    japan,
    southKorea,
    indonesia,
    malaysia,
    singapore,
    philippines,
    thailand,
    vietnam,
    australia,
    newZealand,
    brazil,
    mexico,
    argentina,
    russia,
    southAfrica,
    nigeria,
    kenya,
  ];

  /// Find country by dial code
  static Country? findByDialCode(String dialCode) {
    try {
      return all.firstWhere((c) => c.dialCode == dialCode);
    } catch (e) {
      return null;
    }
  }

  /// Find country by country code
  static Country? findByCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Get sorted list of countries alphabetically
  static List<Country> get sortedAll {
    final list = List<Country>.from(all);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Get map of countries by dial code for quick lookup
  static Map<String, Country> get byDialCode {
    return {for (var country in all) country.dialCode: country};
  }

  /// Get map of countries by code for quick lookup
  static Map<String, Country> get byCode {
    return {for (var country in all) country.code: country};
  }

  /// Default country
  static Country get defaultCountry => egypt;
}
