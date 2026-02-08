class Validators {
  static String? required(String? value,
      {String message = 'This field is required'}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty)
      return null; // Let required validator handle empty

    // Simple email regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;

    // Indian phone regex (optional +91, followed by 10 digits)
    final phoneRegex = RegExp(r'^(\+91[\-\s]?)?[0]?(91)?[789]\d{9}$');

    // Check match
    if (!phoneRegex.hasMatch(value)) {
      // Also allow if just 10 digits for flexibility as per previous logic
      if (value.replaceAll(RegExp(r'\D'), '').length != 10) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    if (price > 1000000) {
      return 'Price cannot exceed ₹10,00,000';
    }

    return null;
  }

  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value != null && value.length > max) {
      return '${fieldName ?? 'This field'} cannot exceed $max characters';
    }
    return null;
  }

  static String? positiveInteger(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    final number = int.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }

    if (number < 0) {
      return '${fieldName ?? 'Value'} cannot be negative';
    }

    if (number > 999999) {
      return '${fieldName ?? 'Value'} cannot exceed 999,999';
    }

    return null;
  }
}
