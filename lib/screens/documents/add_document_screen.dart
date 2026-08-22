import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/appliance.dart';
import '../../models/document_form_result.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../services/homevault_error_presenter.dart';
import '../../widgets/document_attachment_field.dart';

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({
    super.key,
    required this.appliances,
    this.initialApplianceId,
    this.initialType,
    this.document,
  });

  final List<Appliance> appliances;
  final String? initialApplianceId;
  final DocumentType? initialType;
  final StoredDocument? document;

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = DocumentStorageService();
  late final TextEditingController _titleController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  late String _applianceId;
  late DocumentType _type;
  StoredDocument? _document;
  StoredDocument? _replacementDocument;
  bool _isPicking = false;
  bool _submitted = false;

  bool get _isEditing => widget.document != null;

  @override
  void initState() {
    super.initState();
    final requestedId = widget.initialApplianceId;
    _applianceId = widget.appliances.any((item) => item.id == requestedId)
        ? requestedId!
        : widget.appliances.first.id;

    final existingDocument = widget.document;
    _type =
        existingDocument?.type ?? widget.initialType ?? DocumentType.userManual;
    _document = existingDocument;
    _titleController = TextEditingController(
      text: existingDocument?.displayTitle ?? _type.label,
    );
    _referenceController = TextEditingController(
      text: existingDocument?.reference ?? '',
    );
    _notesController = TextEditingController(
      text: existingDocument?.notes ?? '',
    );
  }

  @override
  void dispose() {
    if (!_submitted && _replacementDocument != null) {
      unawaited(_storageService.deleteStoredDocument(_replacementDocument!));
    }
    _titleController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _changeAppliance(String applianceId) async {
    if (_isEditing || applianceId == _applianceId) return;

    final replacement = _replacementDocument;
    setState(() {
      _applianceId = applianceId;
      _document = null;
      _replacementDocument = null;
    });

    if (replacement != null) {
      try {
        await _storageService.deleteStoredDocument(replacement);
      } catch (_) {
        // A stale temporary file can be cleaned when the app data is removed.
      }
    }
  }

  void _changeType(DocumentType type) {
    final previousDefault = _type.label;
    setState(() {
      _type = type;
      if (_titleController.text.trim().isEmpty ||
          _titleController.text.trim() == previousDefault) {
        _titleController.text = type.label;
      }
    });
  }

  Future<void> _pickDocument() async {
    setState(() => _isPicking = true);

    try {
      final selected = await _storageService.pickAndStore(
        applianceId: _applianceId,
        documentFolder: _type.storageFolder,
      );

      if (selected == null || !mounted) return;

      final previousReplacement = _replacementDocument;
      final preparedDocument = selected.copyWith(
        id: widget.document?.id,
        type: _type,
        title: _titleController.text.trim(),
        reference: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
      );

      setState(() {
        _document = preparedDocument;
        _replacementDocument = preparedDocument;
      });

      if (previousReplacement != null) {
        try {
          await _storageService.deleteStoredDocument(previousReplacement);
        } catch (_) {
          // Keep the most recently selected file even if old cleanup fails.
        }
      }
    } catch (error) {
      if (!mounted) return;
      showHomeVaultError(
        context,
        error,
        fallback: 'The document could not be attached. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _removeDocument() async {
    final replacement = _replacementDocument;
    setState(() {
      _document = null;
      _replacementDocument = null;
    });

    if (replacement != null) {
      try {
        await _storageService.deleteStoredDocument(replacement);
      } catch (_) {
        // The user can still choose another file.
      }
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    final selectedDocument = _document;
    if (selectedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a document file first.')),
      );
      return;
    }

    _submitted = true;
    Navigator.of(context).pop(
      DocumentFormResult(
        applianceId: _applianceId,
        originalDocument: widget.document,
        document: selectedDocument.copyWith(
          type: _type,
          title: _titleController.text.trim(),
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit document' : 'Add document'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Document details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Attach manuals, service receipts, installation reports, and other appliance records.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _applianceId,
                decoration: const InputDecoration(
                  labelText: 'Appliance *',
                  prefixIcon: Icon(Icons.home_repair_service_outlined),
                ),
                items: widget.appliances
                    .map(
                      (appliance) => DropdownMenuItem(
                        value: appliance.id,
                        child: Text(
                          appliance.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isEditing
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(_changeAppliance(value));
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DocumentType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Document type *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: DocumentType.values
                    .where(
                      (type) =>
                          type != DocumentType.appliancePhoto &&
                          type != DocumentType.extendedWarranty &&
                          type != DocumentType.amcContract,
                    )
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _changeType(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document title *',
                  hintText: 'Example: Installation manual',
                  prefixIcon: Icon(Icons.title),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a document title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference number',
                  hintText: 'Optional receipt or document number',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Document notes',
                  hintText: 'Optional description or reminder',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              DocumentAttachmentField(
                title: 'Document file',
                description: 'Upload a PDF, JPG, JPEG, or PNG up to 15 MB.',
                icon: Icons.upload_file_outlined,
                document: _document,
                isLoading: _isPicking,
                onPick: _pickDocument,
                onRemove: _removeDocument,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isPicking ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isEditing ? 'Save changes' : 'Save document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
