import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../accessibility/homevault_form_accessibility.dart';
import '../../auth/auth_controller.dart';
import '../../models/appliance.dart';
import '../../models/service_request.dart';
import '../../models/service_request_form_result.dart';
import '../../models/user_profile.dart';

class AddServiceRequestScreen extends StatefulWidget {
  const AddServiceRequestScreen({
    super.key,
    required this.appliances,
    this.initialApplianceId,
    this.request,
    this.initialProfile,
    this.initialProviderName,
    this.initialProviderPhone,
  });

  final List<Appliance> appliances;
  final String? initialApplianceId;
  final ServiceRequest? request;
  final UserProfile? initialProfile;
  final String? initialProviderName;
  final String? initialProviderPhone;

  @override
  State<AddServiceRequestScreen> createState() =>
      _AddServiceRequestScreenState();
}

class _AddServiceRequestScreenState extends State<AddServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _issueController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _providerController;
  late final TextEditingController _providerPhoneController;
  late final TextEditingController _ticketController;
  late final TextEditingController _technicianController;
  late final TextEditingController _notesController;

  late String _applianceId;
  late DateTime _preferredDate;
  late ServiceVisitWindow _visitWindow;

  bool _showValidationSummary = false;

  bool get _isEditing => widget.request != null;

  @override
  void initState() {
    super.initState();

    final request = widget.request;
    final requestedId = widget.initialApplianceId;
    _applianceId = widget.appliances.any((item) => item.id == requestedId)
        ? requestedId!
        : widget.appliances.first.id;
    _preferredDate =
        request?.preferredDate ?? DateUtils.dateOnly(DateTime.now());
    _visitWindow = request?.visitWindow ?? ServiceVisitWindow.flexible;

    final profile = widget.initialProfile;
    final appliance = _selectedAppliance;
    final providerDefaults = _providerDefaults(appliance);

    _issueController = TextEditingController(
      text: request?.issueDescription ?? '',
    );
    _addressController = TextEditingController(
      text: request?.serviceAddress ?? _profileAddress(profile),
    );
    _contactNameController = TextEditingController(
      text: request?.contactName ?? profile?.fullName ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: _editableMobile(
        request?.contactPhone ?? profile?.phoneNumber ?? '',
      ),
    );
    final directoryProvider = widget.initialProviderName?.trim() ?? '';
    final directoryPhone = widget.initialProviderPhone?.trim() ?? '';
    _providerController = TextEditingController(
      text:
          request?.provider ??
          (directoryProvider.isNotEmpty
              ? directoryProvider
              : providerDefaults.$1),
    );
    _providerPhoneController = TextEditingController(
      text:
          request?.providerPhone ??
          (directoryPhone.isNotEmpty ? directoryPhone : providerDefaults.$2),
    );
    _ticketController = TextEditingController(
      text: request?.ticketNumber ?? '',
    );
    _technicianController = TextEditingController(
      text: request?.technicianName ?? '',
    );
    _notesController = TextEditingController(text: request?.notes ?? '');
  }

  @override
  void dispose() {
    _issueController.dispose();
    _addressController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _providerController.dispose();
    _providerPhoneController.dispose();
    _ticketController.dispose();
    _technicianController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Appliance get _selectedAppliance => widget.appliances.firstWhere(
    (appliance) => appliance.id == _applianceId,
    orElse: () => widget.appliances.first,
  );

  String _editableMobile(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    return digits;
  }

  (String, String) _providerDefaults(Appliance appliance) {
    final amcDays = appliance.amcDaysRemainingAt(DateTime.now());
    final hasActiveAmc = amcDays == null ? appliance.hasAmc : amcDays >= 0;

    if (hasActiveAmc && appliance.amcProvider.trim().isNotEmpty) {
      return (appliance.amcProvider.trim(), appliance.amcPhone.trim());
    }
    if (appliance.supportProvider.trim().isNotEmpty) {
      return (appliance.supportProvider.trim(), appliance.supportPhone.trim());
    }
    return (appliance.warrantyProvider.trim(), appliance.supportPhone.trim());
  }

  String _profileAddress(UserProfile? profile) {
    if (profile == null) return '';
    final lines = <String>[
      profile.addressLine1.trim(),
      profile.addressLine2.trim(),
      profile.landmark.trim(),
      [
        profile.city.trim(),
        profile.state.trim(),
      ].where((value) => value.isNotEmpty).join(', '),
      profile.pinCode.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return lines.join('\n');
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _selectDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _preferredDate.isBefore(today) ? today : _preferredDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (selected == null) return;
    setState(() => _preferredDate = selected);
  }

  void _changeAppliance(String applianceId) {
    if (_isEditing || applianceId == _applianceId) return;
    final appliance = widget.appliances.firstWhere(
      (item) => item.id == applianceId,
    );
    final providerDefaults = _providerDefaults(appliance);
    final directoryProvider = widget.initialProviderName?.trim() ?? '';
    final directoryPhone = widget.initialProviderPhone?.trim() ?? '';

    setState(() => _applianceId = applianceId);
    _providerController.text = directoryProvider.isNotEmpty
        ? directoryProvider
        : providerDefaults.$1;
    _providerPhoneController.text = directoryPhone.isNotEmpty
        ? directoryPhone
        : providerDefaults.$2;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return null;
    if (AuthController.normalizeIndianMobileNumber(phone) == null) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  void _save() {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      setState(() => _showValidationSummary = true);
      return;
    }
    if (_showValidationSummary) {
      setState(() => _showValidationSummary = false);
    }

    final today = DateUtils.dateOnly(DateTime.now());
    if (_preferredDate.isBefore(today) &&
        (widget.request?.status.isActive ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose today or a future preferred service date.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final normalizedContact = _contactPhoneController.text.trim().isEmpty
        ? ''
        : AuthController.normalizeIndianMobileNumber(
            _contactPhoneController.text,
          )!;
    final normalizedProvider = _providerPhoneController.text.trim().isEmpty
        ? ''
        : AuthController.normalizeIndianMobileNumber(
                _providerPhoneController.text,
              ) ??
              _providerPhoneController.text.trim();

    final existing = widget.request;
    final request = existing == null
        ? ServiceRequest.create(
            id: now.microsecondsSinceEpoch.toString(),
            now: now,
            preferredDate: _preferredDate,
            visitWindow: _visitWindow,
            issueDescription: _issueController.text.trim(),
            serviceAddress: _addressController.text.trim(),
            contactName: _contactNameController.text.trim(),
            contactPhone: normalizedContact,
            provider: _providerController.text.trim(),
            providerPhone: normalizedProvider,
            ticketNumber: _ticketController.text.trim(),
            technicianName: _technicianController.text.trim(),
            notes: _notesController.text.trim(),
          )
        : existing.copyWith(
            updatedAt: now,
            preferredDate: _preferredDate,
            visitWindow: _visitWindow,
            issueDescription: _issueController.text.trim(),
            serviceAddress: _addressController.text.trim(),
            contactName: _contactNameController.text.trim(),
            contactPhone: normalizedContact,
            provider: _providerController.text.trim(),
            providerPhone: normalizedProvider,
            ticketNumber: _ticketController.text.trim(),
            technicianName: _technicianController.text.trim(),
            notes: _notesController.text.trim(),
          );

    Navigator.of(context).pop(
      ServiceRequestFormResult(
        applianceId: _applianceId,
        request: request,
        originalRequest: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit service request' : 'Request service'),
      ),
      body: HomeVaultAccessibleForm(
        formKey: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            HomeVaultFormValidationSummary(visible: _showValidationSummary),
            Card(
              margin: EdgeInsets.zero,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'HomeVault records your preferred visit and request status. Contact the service provider to confirm the booking.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('serviceRequestApplianceField'),
              initialValue: _applianceId,
              decoration: const InputDecoration(
                labelText: 'Appliance (required)',
                prefixIcon: Icon(Icons.devices_other_outlined),
              ),
              items: widget.appliances
                  .map(
                    (appliance) => DropdownMenuItem(
                      value: appliance.id,
                      child: Text(appliance.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _isEditing
                  ? null
                  : (value) {
                      if (value != null) _changeAppliance(value);
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('serviceRequestIssueField'),
              controller: _issueController,
              decoration: const InputDecoration(
                labelText: 'Problem / service needed (required)',
                hintText: 'Example: AC is not cooling properly',
                prefixIcon: Icon(Icons.report_problem_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 4,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Describe the service problem or request.'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('serviceRequestDateField'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Preferred service date (required)'),
              subtitle: Text(_date(_preferredDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _selectDate,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceVisitWindow>(
              key: const Key('serviceRequestWindowField'),
              initialValue: _visitWindow,
              decoration: const InputDecoration(
                labelText: 'Preferred time (required)',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              items: ServiceVisitWindow.values
                  .map(
                    (window) => DropdownMenuItem(
                      value: window,
                      child: Text('${window.label} • ${window.timeLabel}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _visitWindow = value);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Visit address',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('serviceRequestAddressField'),
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Service address (required)',
                hintText: 'Enter the address where service is required',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 3,
              maxLines: 6,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the service address.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('serviceRequestContactPhoneField'),
              controller: _contactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Contact mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
                prefixText: '+91 ',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: _validatePhone,
            ),
            const SizedBox(height: 16),
            Text(
              'Provider details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('serviceRequestProviderField'),
              controller: _providerController,
              decoration: const InputDecoration(
                labelText: 'Service provider',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('serviceRequestProviderPhoneField'),
              controller: _providerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Provider phone',
                prefixIcon: Icon(Icons.support_agent_outlined),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Complaint / ticket number',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _technicianController,
              decoration: const InputDecoration(
                labelText: 'Technician name',
                prefixIcon: Icon(Icons.engineering_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('saveServiceRequestButton'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save changes' : 'Save service request'),
            ),
          ],
        ),
      ),
    );
  }
}
