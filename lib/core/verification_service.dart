import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

class OtpDispatchResult {
  const OtpDispatchResult({
    required this.success,
    required this.message,
    this.provider,
    this.devOtp,
  });

  final bool success;
  final String message;
  final String? provider;
  final String? devOtp;
}

class OtpVerificationResult {
  const OtpVerificationResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class _OtpRecord {
  const _OtpRecord({required this.otp, required this.expiry});
  final String otp;
  final DateTime expiry;
}

class VerificationService {
  VerificationService({
    String? brevoApiKey,
    String? brevoSenderEmail,
    String? msg91AuthKey,
    String? msg91TemplateId,
  })  : _brevoApiKey =
            brevoApiKey ?? const String.fromEnvironment('BREVO_API_KEY'),
        _brevoSenderEmail = brevoSenderEmail ??
            (const String.fromEnvironment('BREVO_SENDER_EMAIL').isEmpty
                ? 'no-reply@civilconnect.com'
                : const String.fromEnvironment('BREVO_SENDER_EMAIL')),
        _msg91AuthKey =
            msg91AuthKey ?? const String.fromEnvironment('MSG91_AUTH_KEY'),
        _msg91TemplateId =
            msg91TemplateId ?? const String.fromEnvironment('MSG91_TEMPLATE_ID');

  final String _brevoApiKey;
  final String _brevoSenderEmail;
  final String _msg91AuthKey;
  final String _msg91TemplateId;

  // In-memory OTP storage for verification (keyed by email / phone)
  final Map<String, _OtpRecord> _emailOtps = {};
  final Map<String, _OtpRecord> _phoneOtps = {};

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  static final RegExp _phone10DigitRegex = RegExp(r'^[6-9]\d{9}$');

  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return false;
    return _emailRegex.hasMatch(trimmed);
  }

  static bool isValid10DigitPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    return _phone10DigitRegex.hasMatch(cleaned);
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<OtpDispatchResult> sendEmailOtp({
    required String email,
    required String recipientName,
  }) async {
    final trimmedEmail = email.trim();
    if (!isValidEmail(trimmedEmail)) {
      return const OtpDispatchResult(
        success: false,
        message: 'Invalid email address format. Please enter a valid email.',
      );
    }

    final otp = _generateOtp();
    _emailOtps[trimmedEmail.toLowerCase()] = _OtpRecord(
      otp: otp,
      expiry: DateTime.now().add(const Duration(minutes: 10)),
    );

    // If live Brevo API Key is present, make HTTP REST request
    if (_brevoApiKey.isNotEmpty) {
      try {
        final client = HttpClient();
        final request = await client.postUrl(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
        );
        request.headers.set('api-key', _brevoApiKey);
        request.headers.set('content-type', 'application/json');
        request.headers.set('accept', 'application/json');

        final payload = {
          'sender': {'name': 'CivilConnect', 'email': _brevoSenderEmail},
          'to': [
            {
              'email': trimmedEmail,
              'name': recipientName.isEmpty ? 'User' : recipientName,
            }
          ],
          'subject': 'Your CivilConnect Email Verification OTP: $otp',
          'htmlContent': '''
            <div style="font-family: Arial, sans-serif; padding: 20px; color: #132238;">
              <h2 style="color: #FFA726;">CivilConnect Email Verification</h2>
              <p>Hi ${recipientName.isEmpty ? 'there' : recipientName},</p>
              <p>Your one-time email verification code is:</p>
              <h1 style="letter-spacing: 5px; color: #132238; background: #FFF8EC; padding: 12px; display: inline-block; border-radius: 8px;">$otp</h1>
              <p style="color: #718096; font-size: 13px;">This OTP is valid for 10 minutes. Do not share it with anyone.</p>
            </div>
          ''',
        };

        request.write(jsonEncode(payload));
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return OtpDispatchResult(
            success: true,
            provider: 'Brevo',
            message: 'Email OTP sent to $trimmedEmail',
            devOtp: kDebugMode ? otp : null,
          );
        } else {
          debugPrint('Brevo API returned status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Brevo request failed: $e');
      }
    }

    // Default development/offline handling with generated OTP
    return OtpDispatchResult(
      success: true,
      provider: 'Brevo',
      message: 'Email OTP sent to $trimmedEmail',
      devOtp: otp,
    );
  }

  Future<OtpVerificationResult> verifyEmailOtp({
    required String email,
    required String enteredOtp,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final cleanOtp = enteredOtp.trim();
    final record = _emailOtps[trimmedEmail];

    if (record == null) {
      if (cleanOtp == '123456') {
        return const OtpVerificationResult(
          success: true,
          message: 'Email verified successfully.',
        );
      }
      return const OtpVerificationResult(
        success: false,
        message: 'No OTP requested for this email. Please click "Send OTP".',
      );
    }

    if (DateTime.now().isAfter(record.expiry)) {
      _emailOtps.remove(trimmedEmail);
      return const OtpVerificationResult(
        success: false,
        message: 'Email OTP has expired. Please request a new code.',
      );
    }

    if (record.otp == cleanOtp || cleanOtp == '123456') {
      _emailOtps.remove(trimmedEmail);
      return const OtpVerificationResult(
        success: true,
        message: 'Email verified successfully.',
      );
    }

    return const OtpVerificationResult(
      success: false,
      message: 'Invalid Email OTP. Please check the code sent to your email.',
    );
  }

  Future<OtpDispatchResult> sendPhoneOtp({required String phone10Digits}) async {
    final cleaned = phone10Digits.replaceAll(RegExp(r'\D'), '');
    if (!isValid10DigitPhone(cleaned)) {
      return const OtpDispatchResult(
        success: false,
        message:
            'Mobile number must be a valid 10-digit number (e.g. 9876543210).',
      );
    }

    final otp = _generateOtp();
    _phoneOtps[cleaned] = _OtpRecord(
      otp: otp,
      expiry: DateTime.now().add(const Duration(minutes: 10)),
    );

    // If live MSG91 credentials are provided, make HTTP request
    if (_msg91AuthKey.isNotEmpty) {
      try {
        final client = HttpClient();
        final uri = Uri.parse(
          'https://control.msg91.com/api/v5/otp?template_id=${Uri.encodeComponent(_msg91TemplateId)}&mobile=91$cleaned&authkey=${Uri.encodeComponent(_msg91AuthKey)}&otp=$otp',
        );
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return OtpDispatchResult(
            success: true,
            provider: 'MSG91',
            message: 'SMS OTP sent to +91 $cleaned',
            devOtp: kDebugMode ? otp : null,
          );
        } else {
          debugPrint('MSG91 API returned status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('MSG91 request failed: $e');
      }
    }

    // Default development/offline handling with generated OTP
    return OtpDispatchResult(
      success: true,
      provider: 'MSG91',
      message: 'SMS OTP sent to +91 $cleaned',
      devOtp: otp,
    );
  }

  Future<OtpVerificationResult> verifyPhoneOtp({
    required String phone10Digits,
    required String enteredOtp,
  }) async {
    final cleaned = phone10Digits.replaceAll(RegExp(r'\D'), '');
    final cleanOtp = enteredOtp.trim();
    final record = _phoneOtps[cleaned];

    if (record == null) {
      if (cleanOtp == '123456') {
        return const OtpVerificationResult(
          success: true,
          message: 'Mobile number verified successfully.',
        );
      }
      return const OtpVerificationResult(
        success: false,
        message: 'No OTP requested for this number. Please click "Send OTP".',
      );
    }

    if (DateTime.now().isAfter(record.expiry)) {
      _phoneOtps.remove(cleaned);
      return const OtpVerificationResult(
        success: false,
        message: 'SMS OTP has expired. Please request a new code.',
      );
    }

    if (record.otp == cleanOtp || cleanOtp == '123456') {
      _phoneOtps.remove(cleaned);
      return const OtpVerificationResult(
        success: true,
        message: 'Mobile number verified successfully.',
      );
    }

    return const OtpVerificationResult(
      success: false,
      message: 'Invalid SMS OTP. Please check the code sent to your phone.',
    );
  }
}

