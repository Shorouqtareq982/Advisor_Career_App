import '../../../shared/models/country_model.dart';

class AuthValidators {
  AuthValidators._();
  static const List<String> _knownDomains = [
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'icloud.com',
    'me.com',
    'mac.com',
    'aol.com',
    'mail.com',
    'protonmail.com',
    'proton.me',
    'yandex.com',
    'gmx.com',
    'zoho.com',
    'qq.com',
    '163.com',
    '126.com',
    'googlemail.com',
  ];

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    return matrix[a.length][b.length];
  }

  static String? _detectDomainTypo(String domain) {
    for (final known in _knownDomains) {
      final distance = _levenshtein(domain, known);
      if (distance > 0 && distance <= 2) {
        return known;
      }
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }

    final username = value.trim();

    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (username.length > 50) {
      return 'Username must be less than 50 characters';
    }

    if (!RegExp(r'^[\u0600-\u06FFa-zA-Z]').hasMatch(username[0])) {
      return 'Username must start with a letter';
    }

    if (!RegExp(r'^[\u0600-\u06FFa-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain Arabic/English letters, numbers, and underscores';
    }

    if (username.contains('__')) {
      return 'Username cannot contain consecutive underscores';
    }

    if (username.endsWith('_')) {
      return 'Username cannot end with underscore';
    }

    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final email = value.trim().toLowerCase();

    // ── Basic format check ──────────────────────────────────────────────────
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    final parts = email.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address';
    }

    final domain = parts[1].toLowerCase();

    // ── TLD check ───────────────────────────────────────────────────────────
    if (!domain.contains('.')) {
      return 'Please enter a valid email address';
    }

    final domainParts = domain.split('.');
    final tld = domainParts.last;
    if (tld.length < 2 || tld.length > 6) {
      return 'Please enter a valid email address (e.g., name@domain.com)';
    }

    if (!_knownDomains.contains(domain)) {
      final suggestion = _detectDomainTypo(domain);
      if (suggestion != null) {
        return 'Did you mean @$suggestion? Please check your email address';
      }
    }

    // ── IP address domain ───────────────────────────────────────────────────
    if (RegExp(r'^\d+\.\d+$').hasMatch(domain)) {
      return 'Email domain cannot be just numbers';
    }

    return null;
  }

  static String? validatePhone(String? value, Country country) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final phone = value.trim().replaceAll(' ', '');

    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Phone number must contain only numbers';
    }

    final phoneLength = country.phoneLength;
    if (phone.length != phoneLength) {
      return 'Phone number must be $phoneLength digits for ${country.name}';
    }

    return null;
  }

  static String getFullPhoneNumber(String phone, Country country) {
    final cleanPhone = phone.trim().replaceAll(' ', '');
    return '${country.dialCode}$cleanPhone';
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }

    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }

    return null;
  }

  static String? validateUsernameOrEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username or email is required';
    }

    final input = value.trim();

    if (input.contains('@')) {
      return validateEmail(input);
    } else {
      if (input.isEmpty) {
        return 'Username or email is required';
      }
      return null;
    }
  }

  static String formatPhoneForDisplay(String phone) {
    var cleaned = phone.replaceAll(' ', '');

    if (cleaned.startsWith('+')) {
      final countryCode = cleaned.substring(0, cleaned.indexOf(' ') + 1);
      final number =
          cleaned.substring(countryCode.length).replaceAll(RegExp(r'\D'), '');
      cleaned = countryCode + number;
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'\D'), '');
    }

    final buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 3 == 0 && buffer.toString().length < 10) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }

    return buffer.toString();
  }

  static String maskPhone(String fullPhone) {
    if (fullPhone.length < 4) return fullPhone;

    final lastDigits = fullPhone.substring(fullPhone.length - 2);
    final countryCode = fullPhone.substring(0, fullPhone.indexOf(' ') + 1);

    return '$countryCode*** *** **$lastDigits';
  }

  static String maskEmail(String email) {
    if (!email.contains('@')) return email;

    final parts = email.split('@');
    final username = parts[0];
    final domain = parts[1];

    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }

    return '${username.substring(0, 2)}***@$domain';
  }
}
