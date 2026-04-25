class Validators {
  static String? requiredField(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'هذا الحقل مطلوب';
    }
    return null;
  }

  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الهاتف أو البريد الإلكتروني';
    }
    // يمكن تحسين التحقق لاحقاً
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال الاسم';
    }
    if (value.trim().length < 2) {
      return 'الاسم قصير جدًا';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال عنوان البريد الإلكتروني';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الهاتف';
    }

    // Same regex used on the backend (roughly).
    final regex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!regex.hasMatch(value.trim())) {
      return 'صيغة رقم الهاتف غير صحيحة';
    }

    return null;
  }

  static String? syrianMobileLocal(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم الجوال';
    }

    final trimmed = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'رقم الجوال يجب أن يحتوي أرقامًا فقط';
    }
    if (!trimmed.startsWith('9')) {
      return 'رقم الجوال يجب أن يبدأ بـ 9 (بدون 0 وبدون +963)';
    }
    if (trimmed.length != 9) {
      return 'رقم الجوال يجب أن يكون 9 أرقام';
    }

    return null;
  }

  static String? otpCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الرمز مطلوب';
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return 'الرمز يجب أن يكون من 6 أرقام';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون على الأقل 6 أحرف';
    }
    return null;
  }

  static String? password8(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (value.length < 8) {
      return 'كلمة المرور يجب أن تكون على الأقل 8 أحرف';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على حرف صغير واحد على الأقل';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على حرف كبير واحد على الأقل';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'كلمة المرور يجب أن تحتوي على رقم واحد على الأقل';
    }
    return null;
  }
}

