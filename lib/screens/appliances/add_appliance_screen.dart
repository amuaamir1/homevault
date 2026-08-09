import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../models/appliance_form_result.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../services/support_action_service.dart';
import '../../widgets/document_attachment_field.dart';

class AddApplianceScreen extends StatefulWidget {
  const AddApplianceScreen({super.key, this.appliance});

  final Appliance? appliance;

  @override
  State<AddApplianceScreen> createState() => _AddApplianceScreenState();
}

class _AddApplianceScreenState extends State<AddApplianceScreen> {
  static const _reminderOptions = [7, 14, 30, 60, 90];

  static const _categories = [
    'Air Conditioner',
    'Kitchen Appliance',
    'Laundry',
    'Geyser / Water Heater',
    'Television',
    'Computer',
    'Mobile Device',
    'Home Appliance',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _documentStorageService = DocumentStorageService();

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _serialController;
  late final TextEditingController _supportProviderController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _websiteController;
  late final TextEditingController _supportNotesController;
  late final TextEditingController _invoiceController;
  late final TextEditingController _warrantyDurationController;
  late final TextEditingController _warrantyProviderController;
  late final TextEditingController _warrantyReferenceController;
  late final TextEditingController _warrantyTermsController;
  late final TextEditingController _warrantyCoverageController;
  late final TextEditingController _extendedWarrantyProviderController;
  late final TextEditingController _extendedWarrantyReferenceController;
  late final TextEditingController _warrantyClaimNumberController;
  late final TextEditingController _notesController;
  late final String _draftId;

  final Map<String, StoredDocument> _newDocuments = {};
  final Map<String, StoredDocument> _documentsToDelete = {};
  late final Set<String> _originalDocumentPaths;

  late String _category;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiryDate;
  DateTime? _extendedWarrantyExpiryDate;
  WarrantyDurationUnit _warrantyDurationUnit = WarrantyDurationUnit.years;
  bool _useManualWarrantyExpiry = false;
  WarrantyClaimStatus _warrantyClaimStatus = WarrantyClaimStatus.none;
  bool _warrantyMarkedExpired = false;
  bool _warrantyReminderEnabled = false;
  int _warrantyReminderDaysBefore = 30;
  StoredDocument? _invoiceDocument;
  StoredDocument? _warrantyDocument;
  bool _isPickingInvoice = false;
  bool _isPickingWarranty = false;
  bool _submitted = false;

  bool get _isEditing => widget.appliance != null;

  String _supportNumberForEditing(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '';
    }

    // Preserve 1800 and 1860 support numbers.
    if (digits.startsWith('1800') || digits.startsWith('1860')) {
      return digits;
    }

    // Convert a stored +91 mobile number back to 10 digits for editing.
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }

    return digits;
  }

  String _normalizeSupportNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return '';
    }

    // Do not add +91 to toll-free or service numbers.
    if (digits.startsWith('1800') || digits.startsWith('1860')) {
      return digits;
    }

    // Store normal Indian mobile numbers with the country code.
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return '+91$digits';
    }

    return digits;
  }

  @override
  void initState() {
    super.initState();
    final appliance = widget.appliance;

    _draftId =
        appliance?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _category = _categories.contains(appliance?.category)
        ? appliance!.category
        : _categories.first;
    _purchaseDate = appliance?.purchaseDate;
    _warrantyExpiryDate = appliance?.warrantyExpiryDate;
    _extendedWarrantyExpiryDate = appliance?.extendedWarrantyExpiryDate;
    final savedDurationUnit = appliance?.warrantyDurationUnit;
    final savedDurationValue = appliance?.warrantyDurationValue;
    _warrantyDurationUnit = savedDurationUnit ?? WarrantyDurationUnit.years;

    _useManualWarrantyExpiry =
        appliance?.warrantyExpiryDate != null &&
        appliance?.warrantyDurationValue == null;
    _warrantyClaimStatus =
        appliance?.warrantyClaimStatus ?? WarrantyClaimStatus.none;
    _warrantyMarkedExpired = appliance?.warrantyMarkedExpired ?? false;
    _warrantyReminderEnabled = appliance?.warrantyReminderEnabled ?? false;
    final savedReminderDays = appliance?.warrantyReminderDaysBefore ?? 30;
    _warrantyReminderDaysBefore = _reminderOptions.contains(savedReminderDays)
        ? savedReminderDays
        : 30;
    _invoiceDocument = appliance?.invoiceDocument;
    _warrantyDocument = appliance?.warrantyDocument;
    _originalDocumentPaths = {
      if (appliance?.invoiceDocument != null)
        appliance!.invoiceDocument!.localPath,
      if (appliance?.warrantyDocument != null)
        appliance!.warrantyDocument!.localPath,
    };

    _nameController = TextEditingController(text: appliance?.name ?? '');
    _brandController = TextEditingController(text: appliance?.brand ?? '');
    _modelController = TextEditingController(
      text: appliance?.modelNumber ?? '',
    );
    _serialController = TextEditingController(
      text: appliance?.serialNumber ?? '',
    );
    _supportProviderController = TextEditingController(
      text: appliance?.supportProvider ?? '',
    );
    _phoneController = TextEditingController(
      text: _supportNumberForEditing(appliance?.supportPhone),
    );

    _emailController = TextEditingController(
      text: appliance?.supportEmail ?? '',
    );
    _websiteController = TextEditingController(
      text: appliance?.supportWebsite ?? '',
    );
    _supportNotesController = TextEditingController(
      text: appliance?.supportNotes ?? '',
    );
    _invoiceController = TextEditingController(
      text: appliance?.invoiceReference ?? '',
    );
    _warrantyDurationController = TextEditingController(
      text: savedDurationValue?.toString() ?? '',
    );
    _warrantyProviderController = TextEditingController(
      text: appliance?.warrantyProvider ?? '',
    );
    _warrantyReferenceController = TextEditingController(
      text: appliance?.warrantyReference ?? '',
    );
    _warrantyTermsController = TextEditingController(
      text: appliance?.warrantyTerms ?? '',
    );
    _warrantyCoverageController = TextEditingController(
      text: appliance?.warrantyCoverageNotes ?? '',
    );
    _extendedWarrantyProviderController = TextEditingController(
      text: appliance?.extendedWarrantyProvider ?? '',
    );
    _extendedWarrantyReferenceController = TextEditingController(
      text: appliance?.extendedWarrantyReference ?? '',
    );
    _warrantyClaimNumberController = TextEditingController(
      text: appliance?.warrantyClaimNumber ?? '',
    );
    _notesController = TextEditingController(text: appliance?.notes ?? '');
  }

  @override
  void dispose() {
    if (!_submitted) {
      for (final document in _newDocuments.values) {
        unawaited(_documentStorageService.deleteStoredDocument(document));
      }
    }

    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _supportProviderController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _supportNotesController.dispose();
    _invoiceController.dispose();
    _warrantyDurationController.dispose();
    _warrantyProviderController.dispose();
    _warrantyReferenceController.dispose();
    _warrantyTermsController.dispose();
    _warrantyCoverageController.dispose();
    _extendedWarrantyProviderController.dispose();
    _extendedWarrantyReferenceController.dispose();
    _warrantyClaimNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int? get _enteredWarrantyDuration {
    final value = int.tryParse(_warrantyDurationController.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  DateTime? get _calculatedWarrantyExpiry {
    if (_useManualWarrantyExpiry) {
      return _warrantyExpiryDate;
    }

    final startDate = _purchaseDate;
    final duration = _enteredWarrantyDuration;
    if (startDate == null || duration == null) {
      return null;
    }

    return Appliance.calculateWarrantyExpiryDate(
      startDate: startDate,
      durationValue: duration,
      durationUnit: _warrantyDurationUnit,
    );
  }

  DateTime? get _effectiveDraftWarrantyExpiry {
    final standard = _calculatedWarrantyExpiry;
    final extended = _extendedWarrantyExpiryDate;

    if (standard == null) return extended;
    if (extended == null) return standard;
    return extended.isAfter(standard) ? extended : standard;
  }

  void _clearStaleOutOfWarrantyOverride() {
    if (!_warrantyMarkedExpired) return;

    final expiry = _effectiveDraftWarrantyExpiry;
    if (expiry == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);

    // "Mark as out of warranty" is a manual override for a warranty that was
    // voided/ended early. If the user edits the warranty terms so coverage is
    // valid through today or a future date, treat the old override as stale.
    // The user can still switch it on again afterward if the warranty was
    // genuinely voided early.
    if (!expiryDay.isBefore(today)) {
      _warrantyMarkedExpired = false;
    }
  }

  void _setManualWarrantyExpiry(bool useManual) {
    setState(() {
      if (useManual) {
        _warrantyExpiryDate = _calculatedWarrantyExpiry ?? _warrantyExpiryDate;
      }
      _useManualWarrantyExpiry = useManual;
      _clearStaleOutOfWarrantyOverride();
    });
  }

  Future<void> _selectDate({required _DateSelection selection}) async {
    final currentValue = switch (selection) {
      _DateSelection.purchase => _purchaseDate,
      _DateSelection.warranty => _warrantyExpiryDate,
      _DateSelection.extendedWarranty => _extendedWarrantyExpiryDate,
    };
    final isPurchaseDate = selection == _DateSelection.purchase;
    final initialDate =
        currentValue ??
        (isPurchaseDate
            ? DateTime.now()
            : DateTime.now().add(const Duration(days: 365)));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: isPurchaseDate
          ? DateTime.now()
          : DateTime.now().add(const Duration(days: 7300)),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      if (selection == _DateSelection.purchase) {
        _purchaseDate = selectedDate;
      } else if (selection == _DateSelection.warranty) {
        _warrantyExpiryDate = selectedDate;
      } else {
        _extendedWarrantyExpiryDate = selectedDate;
      }

      _clearStaleOutOfWarrantyOverride();
    });
  }

  Future<void> _pickDocument({required bool isInvoice}) async {
    setState(() {
      if (isInvoice) {
        _isPickingInvoice = true;
      } else {
        _isPickingWarranty = true;
      }
    });

    try {
      final selectedDocument = await _documentStorageService.pickAndStore(
        applianceId: _draftId,
        documentFolder: isInvoice ? 'invoice' : 'warranty',
      );

      if (selectedDocument == null || !mounted) {
        return;
      }

      final previousDocument = isInvoice ? _invoiceDocument : _warrantyDocument;

      if (previousDocument != null) {
        await _queueOrDeletePreviousDocument(previousDocument);
      }

      _newDocuments[selectedDocument.localPath] = selectedDocument;
      setState(() {
        if (isInvoice) {
          _invoiceDocument = selectedDocument;
        } else {
          _warrantyDocument = selectedDocument;
        }
      });
    } on DocumentStorageException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The document could not be attached. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isInvoice) {
            _isPickingInvoice = false;
          } else {
            _isPickingWarranty = false;
          }
        });
      }
    }
  }

  Future<void> _queueOrDeletePreviousDocument(
    StoredDocument previousDocument,
  ) async {
    final newlyAdded = _newDocuments.remove(previousDocument.localPath);
    if (newlyAdded != null) {
      await _documentStorageService.deleteStoredDocument(newlyAdded);
      return;
    }

    if (_originalDocumentPaths.contains(previousDocument.localPath)) {
      _documentsToDelete[previousDocument.localPath] = previousDocument;
    }
  }

  Future<void> _removeDocument({required bool isInvoice}) async {
    final document = isInvoice ? _invoiceDocument : _warrantyDocument;
    if (document == null) return;

    await _queueOrDeletePreviousDocument(document);

    if (!mounted) return;
    setState(() {
      if (isInvoice) {
        _invoiceDocument = null;
      } else {
        _warrantyDocument = null;
      }
    });
  }

  void _save() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final purchaseDate = _purchaseDate;
    final duration = _enteredWarrantyDuration;

    if (!_useManualWarrantyExpiry &&
        _warrantyDurationController.text.trim().isNotEmpty &&
        duration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a warranty duration greater than 0.'),
        ),
      );
      return;
    }

    if (!_useManualWarrantyExpiry && duration != null && purchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select the purchase / invoice date to calculate warranty expiry.',
          ),
        ),
      );
      return;
    }

    final warrantyDate = _useManualWarrantyExpiry
        ? _warrantyExpiryDate
        : _calculatedWarrantyExpiry;

    if (purchaseDate != null &&
        warrantyDate != null &&
        warrantyDate.isBefore(purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warranty expiry cannot be before the purchase date.'),
        ),
      );
      return;
    }

    final extendedWarrantyDate = _extendedWarrantyExpiryDate;
    if (extendedWarrantyDate != null &&
        purchaseDate != null &&
        extendedWarrantyDate.isBefore(purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Extended warranty expiry cannot be before the purchase date.',
          ),
        ),
      );
      return;
    }

    if (extendedWarrantyDate != null &&
        warrantyDate != null &&
        extendedWarrantyDate.isBefore(warrantyDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Extended warranty expiry cannot be before the standard warranty expiry.',
          ),
        ),
      );
      return;
    }

    if (!_warrantyMarkedExpired &&
        _warrantyReminderEnabled &&
        warrantyDate == null &&
        extendedWarrantyDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a warranty expiry date before enabling reminders.',
          ),
        ),
      );
      return;
    }

    final existingAppliance = widget.appliance;
    final appliance = Appliance(
      id: _draftId,
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      modelNumber: _modelController.text.trim(),
      serialNumber: _serialController.text.trim(),
      purchaseDate: _purchaseDate,
      warrantyExpiryDate: warrantyDate,
      warrantyDurationValue: _useManualWarrantyExpiry ? null : duration,
      warrantyDurationUnit: !_useManualWarrantyExpiry && duration != null
          ? _warrantyDurationUnit
          : null,
      supportProvider: _supportProviderController.text.trim(),
      supportPhone: _normalizeSupportNumber(_phoneController.text),
      supportEmail: _emailController.text.trim(),
      supportWebsite: _websiteController.text.trim(),
      supportNotes: _supportNotesController.text.trim(),
      invoiceReference: _invoiceController.text.trim(),
      warrantyProvider: _warrantyProviderController.text.trim(),
      warrantyReference: _warrantyReferenceController.text.trim(),
      warrantyTerms: _warrantyTermsController.text.trim(),
      warrantyCoverageNotes: _warrantyCoverageController.text.trim(),
      extendedWarrantyProvider: _extendedWarrantyProviderController.text.trim(),
      extendedWarrantyReference: _extendedWarrantyReferenceController.text
          .trim(),
      extendedWarrantyExpiryDate: _extendedWarrantyExpiryDate,
      warrantyClaimNumber: _warrantyClaimNumberController.text.trim(),
      warrantyClaimStatus: _warrantyClaimStatus,
      warrantyMarkedExpired: _warrantyMarkedExpired,
      warrantyReminderEnabled: _warrantyReminderEnabled,
      warrantyReminderDaysBefore: _warrantyReminderDaysBefore,
      invoiceDocument: _invoiceDocument?.copyWith(
        type: DocumentType.invoice,
        title: 'Invoice',
        reference: _invoiceController.text.trim(),
      ),
      warrantyDocument: _warrantyDocument?.copyWith(
        type: DocumentType.warrantyCard,
        title: 'Warranty card',
        reference: _warrantyReferenceController.text.trim(),
      ),
      additionalDocuments: existingAppliance?.additionalDocuments ?? const [],
      serviceRecords: existingAppliance?.serviceRecords ?? const [],
      notes: _notesController.text.trim(),
      cloudRevision: existingAppliance?.cloudRevision ?? 0,
      cloudUpdatedByDevice: existingAppliance?.cloudUpdatedByDevice ?? '',
      createdAt: existingAppliance?.createdAt ?? DateTime.now(),
    );

    _submitted = true;
    Navigator.of(context).pop(
      ApplianceFormResult(
        appliance: appliance,
        documentsAdded: _newDocuments.values.toList(growable: false),
        documentsToDelete: _documentsToDelete.values.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit appliance' : 'Add appliance'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(
                title: 'Appliance details',
                subtitle: _isEditing
                    ? 'Update the information used to identify this appliance.'
                    : 'Add the information used to identify this appliance.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Appliance name *',
                  hintText: 'Living room air conditioner',
                  prefixIcon: Icon(Icons.devices_other),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an appliance name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'Samsung, LG, Daikin...',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model number',
                  hintText: 'Example: AC-X123/2026',
                  prefixIcon: Icon(Icons.numbers),
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9._/\- ]'),
                  ),
                  LengthLimitingTextInputFormatter(30),
                ],
                validator: (value) {
                  final modelNumber = value?.trim() ?? '';

                  if (modelNumber.isEmpty) {
                    return null;
                  }

                  // Handles old saved records that may already exceed the limit.
                  if (modelNumber.length > 30) {
                    return 'Model number cannot exceed 30 characters.';
                  }

                  if (!RegExp(r'[A-Za-z0-9]').hasMatch(modelNumber)) {
                    return 'Model number must contain a letter or number.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial number',
                  hintText: 'Example: SN-AB12345678',
                  prefixIcon: Icon(Icons.qr_code_2),
                  counterText: '',
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                maxLength: 64,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[A-Za-z0-9._/\-]'),
                  ),
                  LengthLimitingTextInputFormatter(64),
                ],
                validator: (value) {
                  final serialNumber = value?.trim() ?? '';

                  if (serialNumber.isEmpty) {
                    return null;
                  }

                  if (!RegExp(r'[A-Za-z0-9]').hasMatch(serialNumber)) {
                    return 'Serial number must contain a letter or number.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Purchase and warranty',
                subtitle:
                    'Use the purchase / invoice date and a warranty duration in months or years to calculate expiry, then save references and documents.',
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Purchase / invoice date',
                value: _purchaseDate,
                icon: Icons.shopping_bag_outlined,
                onTap: () => _selectDate(selection: _DateSelection.purchase),
                onClear: () => setState(() => _purchaseDate = null),
              ),
              const SizedBox(height: 12),
              if (!_useManualWarrantyExpiry) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: const ValueKey('warrantyDurationValueField'),
                        controller: _warrantyDurationController,
                        decoration: InputDecoration(
                          labelText: 'Warranty duration',
                          hintText:
                              _warrantyDurationUnit ==
                                  WarrantyDurationUnit.years
                              ? 'Example: 2'
                              : 'Example: 18',
                          prefixIcon: const Icon(Icons.timelapse_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onChanged: (_) {
                          setState(_clearStaleOutOfWarrantyOverride);
                        },
                        validator: (value) {
                          if (_useManualWarrantyExpiry) return null;
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) return null;

                          final duration = int.tryParse(input);
                          if (duration == null || duration <= 0) {
                            return 'Enter a value above 0.';
                          }

                          final maxDuration =
                              _warrantyDurationUnit ==
                                  WarrantyDurationUnit.years
                              ? 50
                              : 600;
                          if (duration > maxDuration) {
                            final unit =
                                _warrantyDurationUnit ==
                                    WarrantyDurationUnit.years
                                ? 'years'
                                : 'months';
                            return 'Use $maxDuration $unit or less.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        label: 'Warranty duration unit',
                        child: DropdownButtonFormField<WarrantyDurationUnit>(
                          key: const ValueKey('warrantyDurationUnitField'),
                          initialValue: _warrantyDurationUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(),
                          items: WarrantyDurationUnit.values
                              .map(
                                (unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(
                                    unit == WarrantyDurationUnit.years
                                        ? 'Year'
                                        : 'Month',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (unit) {
                            if (unit == null || unit == _warrantyDurationUnit) {
                              return;
                            }
                            setState(() {
                              _warrantyDurationUnit = unit;
                              _clearStaleOutOfWarrantyOverride();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _CalculatedWarrantyField(
                  purchaseDate: _purchaseDate,
                  duration: _enteredWarrantyDuration,
                  durationUnit: _warrantyDurationUnit,
                  expiryDate: _calculatedWarrantyExpiry,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _setManualWarrantyExpiry(true),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Enter expiry date manually'),
                  ),
                ),
              ] else ...[
                _DateField(
                  label: 'Warranty expiry date',
                  value: _warrantyExpiryDate,
                  icon: Icons.verified_outlined,
                  onTap: () => _selectDate(selection: _DateSelection.warranty),
                  onClear: () => setState(() => _warrantyExpiryDate = null),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _setManualWarrantyExpiry(false),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calculate from warranty duration'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _invoiceController,
                decoration: const InputDecoration(
                  labelText: 'Invoice number/reference',
                  hintText: 'Example: INV-2025-00124',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DocumentAttachmentField(
                title: 'Invoice file',
                description: 'Upload a PDF, JPG, JPEG, or PNG up to 15 MB.',
                icon: Icons.receipt_long_outlined,
                document: _invoiceDocument,
                isLoading: _isPickingInvoice,
                onPick: () => _pickDocument(isInvoice: true),
                onRemove: () => _removeDocument(isInvoice: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warrantyProviderController,
                decoration: const InputDecoration(
                  labelText: 'Warranty provider',
                  hintText: 'Manufacturer, retailer, or service company',
                  prefixIcon: Icon(Icons.business_center_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warrantyReferenceController,
                decoration: const InputDecoration(
                  labelText: 'Warranty card number/reference',
                  hintText: 'Example: WC-987654',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DocumentAttachmentField(
                title: 'Warranty card file',
                description: 'Upload a PDF, JPG, JPEG, or PNG up to 15 MB.',
                icon: Icons.verified_outlined,
                document: _warrantyDocument,
                isLoading: _isPickingWarranty,
                onPick: () => _pickDocument(isInvoice: false),
                onRemove: () => _removeDocument(isInvoice: false),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warrantyTermsController,
                decoration: const InputDecoration(
                  labelText: 'Warranty terms',
                  hintText: 'Example: 2 years comprehensive warranty',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warrantyCoverageController,
                decoration: const InputDecoration(
                  labelText: 'Coverage and exclusions',
                  hintText: 'Parts covered, exclusions, and claim conditions',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              const _SectionTitle(
                title: 'Extended warranty',
                subtitle:
                    'Optional coverage purchased after the original warranty.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extendedWarrantyProviderController,
                decoration: const InputDecoration(
                  labelText: 'Extended warranty provider',
                  prefixIcon: Icon(Icons.add_business_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extendedWarrantyReferenceController,
                decoration: const InputDecoration(
                  labelText: 'Extended warranty reference',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Extended warranty expiry date',
                value: _extendedWarrantyExpiryDate,
                icon: Icons.verified_user_outlined,
                onTap: () =>
                    _selectDate(selection: _DateSelection.extendedWarranty),
                onClear: () =>
                    setState(() => _extendedWarrantyExpiryDate = null),
              ),
              const SizedBox(height: 20),
              const _SectionTitle(
                title: 'Warranty claim',
                subtitle: 'Track an existing claim or support case.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _warrantyClaimNumberController,
                decoration: const InputDecoration(
                  labelText: 'Claim number',
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WarrantyClaimStatus>(
                initialValue: _warrantyClaimStatus,
                decoration: const InputDecoration(
                  labelText: 'Claim status',
                  prefixIcon: Icon(Icons.fact_check_outlined),
                ),
                items: WarrantyClaimStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _warrantyClaimStatus = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                key: const ValueKey('warrantyMarkedExpiredSwitch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as out of warranty'),
                subtitle: const Text(
                  'Use this when the warranty was voided or ended before its recorded date.',
                ),
                value: _warrantyMarkedExpired,
                onChanged: (value) {
                  setState(() {
                    _warrantyMarkedExpired = value;
                    if (value) {
                      _warrantyReminderEnabled = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Warranty reminder'),
                subtitle: const Text(
                  'Schedule a local notification before the effective expiry date.',
                ),
                value: _warrantyReminderEnabled,
                onChanged: _warrantyMarkedExpired
                    ? null
                    : (value) {
                        setState(() => _warrantyReminderEnabled = value);
                      },
              ),
              if (_warrantyReminderEnabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _warrantyReminderDaysBefore,
                  decoration: const InputDecoration(
                    labelText: 'Remind me before expiry',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                  items: _reminderOptions
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text('$days days before'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _warrantyReminderDaysBefore = value);
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Customer support',
                subtitle:
                    'Keep the brand support details beside the appliance.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supportProviderController,
                decoration: const InputDecoration(
                  labelText: 'Support provider',
                  hintText: 'Brand, retailer, or authorized service center',
                  prefixIcon: Icon(Icons.support_agent_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Support contact number',
                  hintText: '9876543210 or 18001234567',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                maxLength: 11,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (value) {
                  final number = value?.trim() ?? '';

                  // Support contact is optional.
                  if (number.isEmpty) {
                    return null;
                  }

                  final isMobile = RegExp(r'^[6-9]\d{9}$').hasMatch(number);

                  final isServiceNumber = RegExp(
                    r'^(1800|1860)\d{6,7}$',
                  ).hasMatch(number);

                  if (!isMobile && !isServiceNumber) {
                    return 'Enter a support number for the provider.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Support email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isNotEmpty && !email.contains('@')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Support website',
                  hintText: 'support.example.com',
                  prefixIcon: Icon(Icons.language),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final website = value?.trim() ?? '';
                  if (!SupportActionService.isValidWebsite(website)) {
                    return 'Enter a valid website address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supportNotesController,
                decoration: const InputDecoration(
                  labelText: 'Support notes',
                  hintText: 'Working hours, service center, or account details',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.contact_support_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'General notes',
                subtitle: 'Save any other information about the appliance.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText:
                      'Service history, installation details, or reminders',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes),
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Save changes' : 'Save appliance'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DateSelection { purchase, warranty, extendedWarranty }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CalculatedWarrantyField extends StatelessWidget {
  const _CalculatedWarrantyField({
    required this.purchaseDate,
    required this.duration,
    required this.durationUnit,
    required this.expiryDate,
  });

  final DateTime? purchaseDate;
  final int? duration;
  final WarrantyDurationUnit durationUnit;
  final DateTime? expiryDate;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final String value;
    final String helper;
    final warrantyDuration = duration;

    if (warrantyDuration == null) {
      value = 'Enter warranty duration';
      helper =
          'Enter the warranty period and choose whether it is in months or years.';
    } else if (purchaseDate == null) {
      value = 'Select purchase / invoice date';
      helper = 'The expiry date is calculated from the selected start date.';
    } else {
      value = expiryDate == null ? 'Not available' : _formatDate(expiryDate!);
      helper =
          '$warrantyDuration ${durationUnit.labelFor(warrantyDuration)} from ${_formatDate(purchaseDate!)}.';
    }

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Calculated warranty expiry',
        prefixIcon: Icon(Icons.verified_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          const SizedBox(height: 4),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onClear;

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Clear date',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(value == null ? 'Not selected' : _formatDate(value!)),
      ),
    );
  }
}
