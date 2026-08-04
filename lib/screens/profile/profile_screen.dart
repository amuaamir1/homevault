import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_controller.dart';
import '../../auth/auth_scope.dart';
import '../../models/user_profile.dart';
import '../../profile/india_states.dart';
import '../../profile/profile_scope.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.isInitialSetup = false});

  final bool isInitialSetup;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinCodeController = TextEditingController();
  String? _selectedState;
  bool _didLoadInitialValues = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitialValues) return;
    _didLoadInitialValues = true;

    final profile = ProfileScope.read(context).profile;
    final authUser = AuthScope.read(context).user;

    _emailController.text = authUser?.email ?? profile?.email ?? '';
    final savedPhone = profile?.phoneNumber.isNotEmpty == true
        ? profile!.phoneNumber
        : authUser?.phoneNumber ?? '';
    _phoneController.text = _localIndianMobile(savedPhone);

    if (profile == null) return;
    _nameController.text = profile.fullName;
    _addressLine1Controller.text = profile.addressLine1;
    _addressLine2Controller.text = profile.addressLine2;
    _landmarkController.text = profile.landmark;
    _cityController.text = profile.city;
    _pinCodeController.text = profile.pinCode;
    if (indiaStatesAndUnionTerritories.contains(profile.state)) {
      _selectedState = profile.state;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    final authUser = AuthScope.read(context).user;
    if (authUser == null) return;

    final profileController = ProfileScope.read(context);
    final existing = profileController.profile;
    final profile = UserProfile(
      uid: authUser.uid,
      fullName: _nameController.text.trim(),
      phoneNumber: AuthController.normalizeIndianMobileNumber(
        _phoneController.text,
      )!,
      email: authUser.email.trim(),
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _addressLine2Controller.text.trim(),
      landmark: _landmarkController.text.trim(),
      state: _selectedState ?? '',
      city: _cityController.text.trim(),
      pinCode: _pinCodeController.text.trim(),
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );

    final saved = await profileController.saveProfile(profile);
    if (!mounted || !saved) return;

    if (!widget.isInitialSetup) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your profile was updated.')),
      );
    }
  }

  String? _requiredText(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validateMobile(String? value) {
    if (AuthController.normalizeIndianMobileNumber(value ?? '') == null) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  String _localIndianMobile(String value) {
    final normalized = AuthController.normalizeIndianMobileNumber(value);
    return normalized == null ? '' : normalized.substring(3);
  }

  String? _validatePinCode(String? value) {
    if (!UserProfile.isValidIndianPinCode(value ?? '')) {
      return 'Enter a valid 6-digit Indian PIN code.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileController = ProfileScope.of(context);
    final title = widget.isInitialSetup ? 'Create your profile' : 'My profile';

    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isInitialSetup) ...[
            Icon(
              Icons.person_pin_circle_outlined,
              size: 70,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Tell us about your home',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your address will help HomeVault pre-fill service-call requests in a future update.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
          TextFormField(
            key: const Key('profileFullNameField'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Full name *',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => _requiredText(value, 'Full name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Verified email address',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('profileMobileNumberField'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Mobile number *',
              hintText: '9876543210',
              prefixIcon: Icon(Icons.phone_android_outlined),
              prefixText: '+91 ',
            ),
            validator: _validateMobile,
          ),
          const SizedBox(height: 22),
          Text(
            'Service address',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profileAddressLine1Field'),
            controller: _addressLine1Controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.streetAddressLine1],
            decoration: const InputDecoration(
              labelText: 'Address line 1 *',
              hintText: 'House/flat number, building and street',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            validator: (value) => _requiredText(value, 'Address line 1'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressLine2Controller,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.streetAddressLine2],
            decoration: const InputDecoration(
              labelText: 'Address line 2',
              hintText: 'Area, locality or colony',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _landmarkController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Landmark',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const Key('profileStateField'),
            initialValue: _selectedState,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'State / Union Territory *',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: indiaStatesAndUnionTerritories
                .map(
                  (state) => DropdownMenuItem<String>(
                    value: state,
                    child: Text(state, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: profileController.isSaving
                ? null
                : (value) => setState(() => _selectedState = value),
            validator: (value) => value == null || value.isEmpty
                ? 'State / Union Territory is required.'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('profileCityField'),
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.addressCity],
            decoration: const InputDecoration(
              labelText: 'City *',
              prefixIcon: Icon(Icons.location_city),
            ),
            validator: (value) => _requiredText(value, 'City'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('profilePinCodeField'),
            controller: _pinCodeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            autofillHints: const [AutofillHints.postalCode],
            decoration: const InputDecoration(
              labelText: 'PIN code *',
              prefixIcon: Icon(Icons.markunread_mailbox_outlined),
            ),
            validator: _validatePinCode,
            onFieldSubmitted: (_) => _save(),
          ),
          if (profileController.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              profileController.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('saveProfileButton'),
            onPressed: profileController.isSaving ? null : _save,
            icon: profileController.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              profileController.isSaving
                  ? 'Saving...'
                  : widget.isInitialSetup
                  ? 'Save and continue'
                  : 'Save profile',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '* Required fields',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !widget.isInitialSetup,
      child: Scaffold(
        appBar: widget.isInitialSetup ? null : AppBar(title: Text(title)),
        body: SafeArea(child: body),
      ),
    );
  }
}
