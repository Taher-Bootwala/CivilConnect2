import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/verification_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isSignUp = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Form controllers - Registration
  final _registerFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  
  DateTime? _selectedDob;
  int? _calculatedAge;
  AppRole _selectedRole = AppRole.customer;
  String _selectedGender = 'Male';
  bool _agreeToTerms = true;
  bool _obscureRegisterPassword = true;

  // Google Account state
  bool _isGoogleConnected = false;
  bool _isLoadingGoogle = false;
  String? _googleEmail;
  String? _googleFullName;

  // Phone SMS OTP state (MSG91)
  final _phoneOtpController = TextEditingController();
  bool _isPhoneOtpSent = false;
  bool _isPhoneVerified = false;
  bool _isSendingPhoneOtp = false;
  bool _isVerifyingPhoneOtp = false;
  String? _phoneOtpMessage;
  int _phoneCountdown = 0;
  Timer? _phoneTimer;

  // Form controllers - Login
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  @override
  void initState() {
    super.initState();
    // Invalidate phone verification state if user modifies phone number
    _phoneController.addListener(() {
      if (_isPhoneVerified || _isPhoneOtpSent) {
        setState(() {
          _isPhoneVerified = false;
          _isPhoneOtpSent = false;
          _phoneOtpController.clear();
          _phoneOtpMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _phoneTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _registerEmailController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _registerPasswordController.dispose();
    _phoneOtpController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _pickGoogleAccount() async {
    setState(() {
      _isLoadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final googleProfile = await ref.read(authProvider.notifier).pickGoogleAccount();
      if (googleProfile != null && mounted) {
        _applyGoogleProfile(googleProfile);
      } else if (mounted) {
        // If native device picker couldn't be launched (e.g. desktop/test/no Play Services),
        // provide the account chooser dialog so user can pick/enter their account
        _showManualGoogleAccountPicker();
      }
    } catch (_) {
      if (mounted) {
        _showManualGoogleAccountPicker();
      }
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  void _applyGoogleProfile(GoogleAuthProfile googleProfile) {
    setState(() {
      _isGoogleConnected = true;
      _googleEmail = googleProfile.email;
      _googleFullName = googleProfile.displayName;

      if (googleProfile.firstName.isNotEmpty) {
        _firstNameController.text = googleProfile.firstName;
      }
      if (googleProfile.lastName.isNotEmpty) {
        _lastNameController.text = googleProfile.lastName;
      }
      if (googleProfile.email.isNotEmpty) {
        _registerEmailController.text = googleProfile.email;
      }
    });
  }

  void _showManualGoogleAccountPicker() {
    final emailController = TextEditingController(
      text: _registerEmailController.text.isNotEmpty
          ? _registerEmailController.text
          : 'taher.bootwala@gmail.com',
    );
    final nameController = TextEditingController(
      text: ('${_firstNameController.text} ${_lastNameController.text}').trim().isNotEmpty
          ? ('${_firstNameController.text} ${_lastNameController.text}').trim()
          : 'Taher Bootwala',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F3F4),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Select Google Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select or confirm your Google account to link with CivilConnect:',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Google Account Email',
                hintText: 'e.g. name@gmail.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Taher Bootwala',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final email = emailController.text.trim();
                  final name = nameController.text.trim();
                  if (email.isNotEmpty && VerificationService.isValidEmail(email)) {
                    final parts = name.split(' ');
                    final first = parts.isNotEmpty ? parts.first : '';
                    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                    _applyGoogleProfile(
                      GoogleAuthProfile(
                        email: email,
                        firstName: first,
                        lastName: last,
                        fullName: name,
                      ),
                    );
                    Navigator.of(ctx).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Use This Account',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initialDate = _selectedDob ?? DateTime(now.year - 22, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select your Date of Birth',
      confirmText: 'Select',
      cancelText: 'Cancel',
    );

    if (picked != null) {
      final age = _computeAge(picked);
      setState(() {
        _selectedDob = picked;
        _calculatedAge = age;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  void _startPhoneCountdown() {
    _phoneTimer?.cancel();
    _phoneTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_phoneCountdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _phoneCountdown = 0);
      } else {
        if (mounted) setState(() => _phoneCountdown--);
      }
    });
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneController.text.trim();
    if (!VerificationService.isValid10DigitPhone(phone)) {
      setState(() {
        _errorMessage =
            'Please enter a valid 10-digit Indian mobile number (e.g. 9876543210).';
      });
      return;
    }

    setState(() {
      _isSendingPhoneOtp = true;
      _errorMessage = null;
      _phoneOtpMessage = null;
    });

    try {
      final verifier = ref.read(verificationServiceProvider);
      final res = await verifier.sendPhoneOtp(phone10Digits: phone);

      if (mounted) {
        if (res.success) {
          setState(() {
            _isPhoneOtpSent = true;
            _phoneOtpMessage = res.devOtp != null
                ? '${res.message} (Test OTP: ${res.devOtp})'
                : res.message;
            _phoneCountdown = 30;
          });
          _startPhoneCountdown();
        } else {
          setState(() {
            _errorMessage = res.message;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isSendingPhoneOtp = false);
    }
  }

  Future<void> _verifyPhoneOtp() async {
    final otp = _phoneOtpController.text.trim();
    if (otp.length < 4) {
      setState(() {
        _errorMessage = 'Please enter the 6-digit WhatsApp OTP sent to your phone.';
      });
      return;
    }

    setState(() {
      _isVerifyingPhoneOtp = true;
      _errorMessage = null;
    });

    try {
      final verifier = ref.read(verificationServiceProvider);
      final res = await verifier.verifyPhoneOtp(
        phone10Digits: _phoneController.text.trim(),
        enteredOtp: otp,
      );

      if (mounted) {
        if (res.success) {
          setState(() {
            _isPhoneVerified = true;
            _phoneOtpMessage = res.message;
          });
        } else {
          setState(() {
            _errorMessage = res.message;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isVerifyingPhoneOtp = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_agreeToTerms) {
      setState(() {
        _errorMessage =
            'Please accept the Terms of Service to create an account.';
      });
      return;
    }

    if (!(_registerFormKey.currentState?.validate() ?? false)) return;

    if (_selectedDob == null) {
      setState(() {
        _errorMessage = 'Please select your Date of Birth (DOB).';
      });
      return;
    }

    // Check phone verification
    if (!_isPhoneVerified) {
      if (!_isPhoneOtpSent) {
        await _sendPhoneOtp();
      }
      setState(() {
        _errorMessage =
            'Please enter the WhatsApp OTP sent to your mobile number to verify your phone.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = ('$firstName $lastName').trim();

      await ref.read(authProvider.notifier).signUp(
            name: fullName.isEmpty ? 'User' : fullName,
            firstName: firstName,
            lastName: lastName,
            email: _registerEmailController.text.trim(),
            password: _registerPasswordController.text,
            phone: '+91${_phoneController.text.trim()}',
            role: _selectedRole,
            gender: _selectedGender,
            dateOfBirth: _selectedDob,
            age: _calculatedAge,
          );

      if (mounted) {
        final targetRoute =
            _selectedRole == AppRole.professional ? '/pro/jobs' : '/home';
        context.go(targetRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).signIn(
            email: _loginEmailController.text.trim(),
            password: _loginPasswordController.text,
          );

      if (mounted) {
        final user = ref.read(authProvider);
        final targetRoute =
            user?.role == AppRole.professional ? '/pro/jobs' : '/home';
        context.go(targetRoute);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Center(
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        color: AppColors.saffron,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'CivilConnect',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _isSignUp
                          ? 'Trusted On-Demand Home Services'
                          : 'Sign in to access your bookings & services',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab Switcher (Register / Sign In)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            label: 'Register',
                            icon: Icons.person_add_alt_1_outlined,
                            isSelected: _isSignUp,
                            onTap: () {
                              if (!_isSignUp) {
                                setState(() {
                                  _isSignUp = true;
                                  _errorMessage = null;
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            label: 'Sign In',
                            icon: Icons.login_outlined,
                            isSelected: !_isSignUp,
                            onTap: () {
                              if (_isSignUp) {
                                setState(() {
                                  _isSignUp = false;
                                  _errorMessage = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 20,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Form Content
                  if (_isSignUp) _buildSignUpForm() else _buildSignInForm(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create your account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connect with Google to verify email, then review and edit your details.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 14),

          // Google Connect Action
          _buildGoogleActionCard(),
          const SizedBox(height: 18),

          // Role Selection Cards
          const Text(
            'I want to join as',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  title: 'Customer',
                  subtitle: 'Book repairs & services',
                  icon: Icons.home_repair_service_outlined,
                  isSelected: _selectedRole == AppRole.customer,
                  onTap: () {
                    setState(() {
                      _selectedRole = AppRole.customer;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  title: 'Professional',
                  subtitle: 'Earn offering services',
                  icon: Icons.engineering_outlined,
                  isSelected: _selectedRole == AppRole.professional,
                  onTap: () {
                    setState(() {
                      _selectedRole = AppRole.professional;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // First Name & Last Name (Side by Side)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    hintText: 'e.g. Rahul',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter first name.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    hintText: 'e.g. Sharma',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter last name.';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Email Address (Pre-filled from Google, editable)
          TextFormField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: const Icon(Icons.mail_outline),
              suffixIcon: _isGoogleConnected
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Google Verified',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address.';
              }
              if (!VerificationService.isValidEmail(value)) {
                return 'Enter a valid email format (e.g. rahul@example.com).';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Date of Birth (DOB) and Real-Time Age Calculation
          InkWell(
            key: const Key('dob_picker_inkwell'),
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              child: TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: 'Date of Birth (DOB)',
                  hintText: 'DD/MM/YYYY',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.calendar_month, color: AppColors.ink),
                  ),
                ),
                validator: (value) {
                  if (_selectedDob == null) {
                    return 'Please select your Date of Birth.';
                  }
                  if (_calculatedAge != null && _calculatedAge! < 14) {
                    return 'Must be at least 14 years old to create an account.';
                  }
                  return null;
                },
              ),
            ),
          ),
          if (_calculatedAge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.saffron.withValues(alpha: .5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, size: 18, color: AppColors.coral),
                  const SizedBox(width: 8),
                  Text(
                    'Age: $_calculatedAge years',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _calculatedAge! >= 18 ? 'Eligible ✓' : 'Under 18',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _calculatedAge! >= 18 ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Gender Selection
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  label: 'Male',
                  icon: Icons.male,
                  isSelected: _selectedGender == 'Male',
                  onTap: () => setState(() => _selectedGender = 'Male'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GenderCard(
                  label: 'Female',
                  icon: Icons.female,
                  isSelected: _selectedGender == 'Female',
                  onTap: () => setState(() => _selectedGender = 'Female'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GenderCard(
                  label: 'Other',
                  icon: Icons.person_outline,
                  isSelected: _selectedGender == 'Other',
                  onTap: () => setState(() => _selectedGender = 'Other'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 10-Digit Mobile + MSG91 SMS OTP Section
          _buildPhoneFieldWithMsg91Otp(),
          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            decoration: InputDecoration(
              labelText: 'Create Password',
              hintText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscureRegisterPassword = !_obscureRegisterPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please create a password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _agreeToTerms,
                  activeColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'I agree to the Terms of Service & Privacy Policy.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Complete Registration Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Complete Registration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = false;
                  _errorMessage = null;
                });
              },
              child: const Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: AppColors.muted),
                  children: [
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleActionCard() {
    if (_isGoogleConnected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Google Connected',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    ],
                  ),
                  Text(
                    _googleEmail ?? _registerEmailController.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _isLoadingGoogle ? null : _pickGoogleAccount,
              child: const Text(
                'Change',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _isLoadingGoogle ? null : _pickGoogleAccount,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _isLoadingGoogle
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneFieldWithMsg91Otp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: '10-Digit Mobile Number',
            hintText: '9876543210',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              child: const Text(
                '+91',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            suffixIcon: _isPhoneVerified
                ? const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.success, size: 20),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton(
                    onPressed: _isSendingPhoneOtp ? null : _sendPhoneOtp,
                    child: _isSendingPhoneOtp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isPhoneOtpSent ? 'Resend' : 'Send OTP',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.ink,
                            ),
                          ),
                  ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your 10-digit mobile number.';
            }
            if (!VerificationService.isValid10DigitPhone(value)) {
              return 'Enter a valid 10-digit Indian mobile number (e.g. 9876543210).';
            }
            return null;
          },
        ),
        if (_isPhoneVerified)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'WhatsApp verified ✓',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          )
        else if (_isPhoneOtpSent) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.saffron.withValues(alpha: .5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 16, color: Color(0xFF25D366)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'WhatsApp OTP Verification',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (_phoneCountdown > 0)
                      Text(
                        '${_phoneCountdown}s',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coral,
                        ),
                      ),
                  ],
                ),
                if (_phoneOtpMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _phoneOtpMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneOtpController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Enter 6-digit OTP',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed:
                            _isVerifyingPhoneOtp ? null : _verifyPhoneOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: _isVerifyingPhoneOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Verify',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignInForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your credentials to access your CivilConnect account.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 18),

          // Email
          TextFormField(
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address.';
              }
              if (!VerificationService.isValidEmail(value)) {
                return 'Please enter a valid email format.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscureLoginPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your account password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureLoginPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscureLoginPassword = !_obscureLoginPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Sign In Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = true;
                  _errorMessage = null;
                });
              },
              child: const Text.rich(
                TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: AppColors.muted),
                  children: [
                    TextSpan(
                      text: 'Register now',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cream : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.saffron : AppColors.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppColors.coral : AppColors.muted,
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.saffron,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isSelected ? AppColors.ink : AppColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cream : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.saffron : AppColors.line,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.coral : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
