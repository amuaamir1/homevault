import 'dart:async';

import 'package:flutter/material.dart';

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
  static const _categories = [
    'Air Conditioner',
    'Kitchen Appliance',
    'Laundry',
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
  late final TextEditingController _warrantyProviderController;
  late final TextEditingController _warrantyReferenceController;
  late final TextEditingController _notesController;
  late final String _draftId;

  final Map<String, StoredDocument> _newDocuments = {};
  final Map<String, StoredDocument> _documentsToDelete = {};
  late final Set<String> _originalDocumentPaths;

  late String _category;
  DateTime? _purchaseDate;
  DateTime? _warrantyExpiryDate;
  StoredDocument? _invoiceDocument;
  StoredDocument? _warrantyDocument;
  bool _isPickingInvoice = false;
  bool _isPickingWarranty = false;
  bool _submitted = false;

  bool get _isEditing => widget.appliance != null;

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
      text: appliance?.supportPhone ?? '',
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
    _warrantyProviderController = TextEditingController(
      text: appliance?.warrantyProvider ?? '',
    );
    _warrantyReferenceController = TextEditingController(
      text: appliance?.warrantyReference ?? '',
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
    _warrantyProviderController.dispose();
    _warrantyReferenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isWarrantyDate}) async {
    final initialDate = isWarrantyDate
        ? (_warrantyExpiryDate ?? DateTime.now().add(const Duration(days: 365)))
        : (_purchaseDate ?? DateTime.now());

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990),
      lastDate: isWarrantyDate
          ? DateTime.now().add(const Duration(days: 3650))
          : DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      if (isWarrantyDate) {
        _warrantyExpiryDate = selectedDate;
      } else {
        _purchaseDate = selectedDate;
      }
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
    final warrantyDate = _warrantyExpiryDate;
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

    final existingAppliance = widget.appliance;
    final appliance = Appliance(
      id: _draftId,
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      modelNumber: _modelController.text.trim(),
      serialNumber: _serialController.text.trim(),
      purchaseDate: _purchaseDate,
      warrantyExpiryDate: _warrantyExpiryDate,
      supportProvider: _supportProviderController.text.trim(),
      supportPhone: _phoneController.text.trim(),
      supportEmail: _emailController.text.trim(),
      supportWebsite: _websiteController.text.trim(),
      supportNotes: _supportNotesController.text.trim(),
      invoiceReference: _invoiceController.text.trim(),
      warrantyProvider: _warrantyProviderController.text.trim(),
      warrantyReference: _warrantyReferenceController.text.trim(),
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
      notes: _notesController.text.trim(),
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
                  prefixIcon: Icon(Icons.numbers),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(
                  labelText: 'Serial number',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Purchase and warranty',
                subtitle:
                    'Save the dates, references, invoice, and warranty card.',
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Purchase date',
                value: _purchaseDate,
                icon: Icons.shopping_bag_outlined,
                onTap: () => _selectDate(isWarrantyDate: false),
                onClear: () => setState(() => _purchaseDate = null),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: 'Warranty expiry date',
                value: _warrantyExpiryDate,
                icon: Icons.verified_outlined,
                onTap: () => _selectDate(isWarrantyDate: true),
                onClear: () => setState(() => _warrantyExpiryDate = null),
              ),
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
                  labelText: 'Support phone',
                  hintText: 'Include the country code when possible',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
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
