import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:civilconnect/app/app.dart';

void main() {
  testWidgets('CivilConnect displays Continue with Google, DOB, Age calculation, and Gender on Sign Up', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Verify auth screen is compulsory and displayed
    expect(find.text('CivilConnect'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Professional'), findsOneWidget);

    // Verify Name, DOB, Gender, Phone, and Password fields
    expect(find.widgetWithText(TextFormField, 'First Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Last Name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Date of Birth (DOB)'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '10-Digit Mobile Number'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Create Password'), findsOneWidget);
    expect(find.text('Complete Registration'), findsOneWidget);

    // Verify vendor names are NOT shown in user-facing UI
    expect(find.textContaining('Brevo'), findsNothing);
    expect(find.textContaining('MSG91'), findsNothing);
  });

  testWidgets('Continue with Google fetches profile data, user selects DOB and verifies SMS OTP to register', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // 1. Tap Continue with Google
    final googleBtn = find.text('Continue with Google');
    expect(googleBtn, findsOneWidget);
    await tester.tap(googleBtn);
    await tester.pumpAndSettle();

    // Verify Google Connected banner appears and fields are prefilled
    expect(find.text('Google Connected'), findsOneWidget);
    expect(find.text('Google Verified'), findsOneWidget);

    // 2. User edits First Name & Last Name (fully editable)
    final firstNameField = find.widgetWithText(TextFormField, 'First Name');
    await tester.enterText(firstNameField, 'Pooja');
    final lastNameField = find.widgetWithText(TextFormField, 'Last Name');
    await tester.enterText(lastNameField, 'Verma');

    // 3. User selects Date of Birth using DatePicker
    final dobPickerBtn = find.byKey(const Key('dob_picker_inkwell'));
    await tester.ensureVisible(dobPickerBtn);
    await tester.tap(dobPickerBtn);
    await tester.pumpAndSettle();

    // Confirm date from DatePicker dialog
    final selectBtn = find.text('Select');
    if (selectBtn.evaluate().isNotEmpty) {
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();
    } else {
      final okBtn = find.text('OK');
      await tester.tap(okBtn);
      await tester.pumpAndSettle();
    }

    // Verify real-time Age badge was calculated and rendered
    expect(find.textContaining('Age:'), findsOneWidget);

    // 4. Select Gender Female
    await tester.tap(find.text('Female'));
    await tester.pumpAndSettle();

    // 5. Enter 10-digit mobile number and send SMS OTP
    await tester.enterText(
      find.widgetWithText(TextFormField, '10-Digit Mobile Number'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create Password'),
      'secretPass123',
    );

    final sendSmsOtpBtn = find.text('Send OTP');
    await tester.tap(sendSmsOtpBtn);
    await tester.pumpAndSettle();
    expect(find.text('Mobile SMS OTP Verification'), findsOneWidget);

    // Enter SMS OTP
    final phoneOtpField = find.widgetWithText(TextFormField, 'Enter 6-digit OTP');
    await tester.enterText(phoneOtpField, '123456');

    // Tap verify
    final verifyBtn = find.widgetWithText(ElevatedButton, 'Verify');
    await tester.tap(verifyBtn);
    await tester.pumpAndSettle();
    expect(find.text('Mobile verified ✓'), findsOneWidget);

    // 6. Complete Registration
    final registerButton = find.widgetWithText(ElevatedButton, 'Complete Registration');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Customer home screen should render and greet Pooja
    expect(find.textContaining('Pooja'), findsOneWidget);
    expect(find.text('What do you need help with?'), findsOneWidget);
  });

  testWidgets('User signs in via Sign In form and reaches customer home', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Switch to Sign In tab
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Enter login credentials
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'aarav@civilconnect.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'mySecretPass123',
    );

    // Tap Sign In button
    final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Should now be on customer home screen
    expect(find.textContaining('Make home feel'), findsOneWidget);
    expect(find.text('What do you need help with?'), findsOneWidget);
    expect(find.text('Book a service'), findsOneWidget);
  });

  testWidgets('Signing out redirects back to compulsory registration screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // Sign in using the Sign In tab
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Address'),
      'aarav@civilconnect.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'mySecretPass123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Navigate to Account tab
    final accountNav = find.text('Account');
    expect(accountNav, findsOneWidget);
    await tester.tap(accountNav);
    await tester.pumpAndSettle();

    // Find and tap Sign out
    final signOutTile = find.text('Sign out');
    expect(signOutTile, findsOneWidget);
    await tester.ensureVisible(signOutTile);
    await tester.tap(signOutTile);
    await tester.pumpAndSettle();

    // Confirm sign out dialog
    final confirmBtn = find.widgetWithText(FilledButton, 'Sign out');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify redirected back to compulsory login/register page
    expect(find.text('Complete Registration'), findsOneWidget);
  });
}
