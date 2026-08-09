import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance.dart';
import '../../models/service_form_result.dart';
import '../../models/service_record.dart';
import '../../models/stored_document.dart';
import '../../services/document_storage_service.dart';
import '../../widgets/document_attachment_field.dart';

class AddServiceRecordScreen extends StatefulWidget {
  const AddServiceRecordScreen({
    super.key,
    required this.appliances,
    this.initialApplianceId,
    this.record,
  });

  final List<Appliance> appliances;
  final String? initialApplianceId;
  final ServiceRecord? record;

  @override
  State<AddServiceRecordScreen> createState() => _AddServiceRecordScreenState();
}

class _AddServiceRecordScreenState extends State<AddServiceRecordScreen> {
  static const _reminderOptions = [1, 3, 7, 14, 30];

  final _formKey = GlobalKey<FormState>();
  final _storageService = DocumentStorageService();

  late final TextEditingController _providerController;
  late final TextEditingController _technicianController;
  late final TextEditingController _ticketController;
  late final TextEditingController _problemController;
  late final TextEditingController _workController;
  late final TextEditingController _partsController;
  late final TextEditingController _chargeController;
  late final TextEditingController _paymentController;
  late final TextEditingController _serviceIntervalController;
  late final TextEditingController _notesController;

  late String _applianceId;
  late DateTime _serviceDate;
  DateTime? _nextServiceDate;
  late ServiceIntervalUnit _serviceIntervalUnit;
  late ServiceStatus _status;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 7;
  StoredDocument? _receiptDocument;
  StoredDocument? _reportDocument;
  bool _isPickingReceipt = false;
  bool _isPickingReport = false;
  bool _submitted = false;

  final Map<String, StoredDocument> _newDocuments = {};
  final Map<String, StoredDocument> _documentsToDelete = {};
  late final Set<String> _originalDocumentPaths;

  bool get _isEditing => widget.record != null;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    final requestedId = widget.initialApplianceId;
    _applianceId = widget.appliances.any((item) => item.id == requestedId)
        ? requestedId!
        : widget.appliances.first.id;
    _serviceDate = record?.serviceDate ?? DateTime.now();
    _nextServiceDate = record?.nextServiceDate;
    _serviceIntervalUnit =
        record?.serviceIntervalUnit ?? ServiceIntervalUnit.months;
    _status =
        record?.effectiveStatus(DateTime.now()) ?? ServiceStatus.completed;
    _reminderEnabled = record?.reminderEnabled ?? false;
    final reminderDays = record?.reminderDaysBefore ?? 7;
    _reminderDaysBefore = _reminderOptions.contains(reminderDays)
        ? reminderDays
        : 7;
    _receiptDocument = record?.receiptDocument;
    _reportDocument = record?.reportDocument;
    _originalDocumentPaths = {
      if (record?.receiptDocument != null) record!.receiptDocument!.localPath,
      if (record?.reportDocument != null) record!.reportDocument!.localPath,
    };

    _providerController = TextEditingController(text: record?.provider ?? '');
    _technicianController = TextEditingController(
      text: record?.technicianName ?? '',
    );
    _ticketController = TextEditingController(text: record?.ticketNumber ?? '');
    _problemController = TextEditingController(
      text: record?.problemDescription ?? '',
    );
    _workController = TextEditingController(text: record?.workCompleted ?? '');
    _partsController = TextEditingController(text: record?.partsReplaced ?? '');
    _chargeController = TextEditingController(
      text: record == null || record.serviceCharge == 0
          ? ''
          : record.serviceCharge.toStringAsFixed(2),
    );
    _paymentController = TextEditingController(
      text: record?.paymentMethod ?? '',
    );
    _serviceIntervalController = TextEditingController(
      text: record?.serviceIntervalValue?.toString() ?? '',
    );
    _notesController = TextEditingController(text: record?.notes ?? '');
  }

  @override
  void dispose() {
    if (!_submitted) {
      for (final document in _newDocuments.values) {
        unawaited(_storageService.deleteStoredDocument(document));
      }
    }
    _providerController.dispose();
    _technicianController.dispose();
    _ticketController.dispose();
    _problemController.dispose();
    _workController.dispose();
    _partsController.dispose();
    _chargeController.dispose();
    _paymentController.dispose();
    _serviceIntervalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool nextService}) async {
    final current = nextService ? _nextServiceDate : _serviceDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 7300)),
    );
    if (selected == null) return;

    setState(() {
      if (nextService) {
        _nextServiceDate = selected;
      } else {
        _serviceDate = selected;
        _recalculateNextServiceDate();
        if (_status == ServiceStatus.scheduled) {
          _status = ServiceRecord.resolveStatus(
            status: _status,
            serviceDate: _serviceDate,
            now: DateTime.now(),
          );
        }
      }
    });
  }

  int? get _serviceIntervalValue {
    final value = int.tryParse(_serviceIntervalController.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  bool get _hasServiceInterval => _serviceIntervalValue != null;

  void _recalculateNextServiceDate() {
    final intervalValue = _serviceIntervalValue;
    if (intervalValue == null) return;

    _nextServiceDate = ServiceRecord.calculateNextServiceDate(
      serviceDate: _serviceDate,
      intervalValue: intervalValue,
      intervalUnit: _serviceIntervalUnit,
    );
  }

  String _date(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  Future<void> _changeAppliance(String applianceId) async {
    if (_isEditing || applianceId == _applianceId) return;

    final documents = _newDocuments.values.toList(growable: false);
    setState(() {
      _applianceId = applianceId;
      _receiptDocument = null;
      _reportDocument = null;
      _newDocuments.clear();
      _documentsToDelete.clear();
    });

    for (final document in documents) {
      try {
        await _storageService.deleteStoredDocument(document);
      } catch (_) {
        // The user can still continue with the selected appliance.
      }
    }
  }

  Future<void> _pickDocument({required bool receipt}) async {
    setState(() {
      if (receipt) {
        _isPickingReceipt = true;
      } else {
        _isPickingReport = true;
      }
    });

    try {
      final type = receipt
          ? DocumentType.serviceReceipt
          : DocumentType.serviceReport;
      final selected = await _storageService.pickAndStore(
        applianceId: _applianceId,
        documentFolder: type.storageFolder,
      );
      if (selected == null || !mounted) return;

      final current = receipt ? _receiptDocument : _reportDocument;
      final prepared = selected.copyWith(
        id: current?.id,
        type: type,
        title: receipt ? 'Service receipt' : 'Service report',
        reference: _ticketController.text.trim(),
      );

      if (current != null) {
        if (_originalDocumentPaths.contains(current.localPath)) {
          _documentsToDelete[current.localPath] = current;
        } else {
          _newDocuments.remove(current.localPath);
          try {
            await _storageService.deleteStoredDocument(current);
          } catch (_) {
            // Keep the new selection even if temporary cleanup fails.
          }
        }
      }

      if (!mounted) {
        try {
          await _storageService.deleteStoredDocument(prepared);
        } catch (_) {
          // The temporary file can be removed with app data later.
        }
        return;
      }

      _newDocuments[prepared.localPath] = prepared;
      setState(() {
        if (receipt) {
          _receiptDocument = prepared;
        } else {
          _reportDocument = prepared;
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
          if (receipt) {
            _isPickingReceipt = false;
          } else {
            _isPickingReport = false;
          }
        });
      }
    }
  }

  Future<void> _removeDocument({required bool receipt}) async {
    final current = receipt ? _receiptDocument : _reportDocument;
    if (current == null) return;

    setState(() {
      if (receipt) {
        _receiptDocument = null;
      } else {
        _reportDocument = null;
      }
    });

    if (_originalDocumentPaths.contains(current.localPath)) {
      _documentsToDelete[current.localPath] = current;
      return;
    }

    _newDocuments.remove(current.localPath);
    try {
      await _storageService.deleteStoredDocument(current);
    } catch (_) {
      // A stale temporary file can be removed with the app data later.
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final intervalValue = _serviceIntervalValue;
    final nextDate = intervalValue == null
        ? _nextServiceDate
        : ServiceRecord.calculateNextServiceDate(
            serviceDate: _serviceDate,
            intervalValue: intervalValue,
            intervalUnit: _serviceIntervalUnit,
          );
    if (nextDate != null && nextDate.isBefore(_serviceDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Next service date cannot be before the service date.'),
        ),
      );
      return;
    }
    if (_reminderEnabled && nextDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a next service date before enabling a reminder.',
          ),
        ),
      );
      return;
    }

    final chargeText = _chargeController.text.trim();
    final charge = chargeText.isEmpty ? 0.0 : double.tryParse(chargeText);
    if (charge == null || charge < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid service charge.')),
      );
      return;
    }

    final existing = widget.record;
    var record = ServiceRecord(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      serviceDate: _serviceDate,
      createdAt: existing?.createdAt ?? DateTime.now(),
      provider: _providerController.text.trim(),
      technicianName: _technicianController.text.trim(),
      ticketNumber: _ticketController.text.trim(),
      problemDescription: _problemController.text.trim(),
      workCompleted: _workController.text.trim(),
      partsReplaced: _partsController.text.trim(),
      serviceCharge: charge,
      paymentMethod: _paymentController.text.trim(),
      serviceIntervalValue: intervalValue,
      serviceIntervalUnit: _serviceIntervalUnit,
      nextServiceDate: nextDate,
      status: _status,
      notes: _notesController.text.trim(),
      reminderEnabled: _status == ServiceStatus.cancelled
          ? false
          : _reminderEnabled,
      reminderDaysBefore: _reminderDaysBefore,
      receiptDocument: _receiptDocument?.copyWith(
        type: DocumentType.serviceReceipt,
        title: 'Service receipt',
        reference: _ticketController.text.trim(),
      ),
      reportDocument: _reportDocument?.copyWith(
        type: DocumentType.serviceReport,
        title: 'Service report',
        reference: _ticketController.text.trim(),
      ),
    );

    final effectiveStatus = record.effectiveStatus(DateTime.now());
    if (effectiveStatus != record.status) {
      record = record.copyWith(status: effectiveStatus);
    }

    _submitted = true;
    Navigator.of(context).pop(
      ServiceFormResult(
        applianceId: _applianceId,
        record: record,
        originalRecord: existing,
        documentsAdded: _newDocuments.values.toList(growable: false),
        documentsToDelete: _documentsToDelete.values.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit service record' : 'Add service record'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _applianceId,
              decoration: const InputDecoration(
                labelText: 'Appliance *',
                prefixIcon: Icon(Icons.devices_other_outlined),
              ),
              items: widget.appliances
                  .map(
                    (appliance) => DropdownMenuItem(
                      value: appliance.id,
                      child: Text(appliance.name),
                    ),
                  )
                  .toList(),
              onChanged: _isEditing
                  ? null
                  : (value) {
                      if (value != null) _changeAppliance(value);
                    },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _status == ServiceStatus.completed
                    ? 'Last service date *'
                    : 'Service date *',
              ),
              subtitle: Text(_date(_serviceDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => _selectDate(nextService: false),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status *',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: ServiceStatus.values
                  .where((status) => status != ServiceStatus.inProgress)
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _status = ServiceRecord.resolveStatus(
                    status: value,
                    serviceDate: _serviceDate,
                    now: DateTime.now(),
                  );
                  if (_status == ServiceStatus.cancelled) {
                    _reminderEnabled = false;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _providerController,
              decoration: const InputDecoration(
                labelText: 'Service provider',
                prefixIcon: Icon(Icons.business_outlined),
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
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Complaint / ticket number',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _problemController,
              decoration: const InputDecoration(
                labelText: 'Problem or complaint *',
                hintText: 'Example: Cooling performance reduced',
                prefixIcon: Icon(Icons.report_problem_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Describe the service problem or request.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workController,
              decoration: const InputDecoration(
                labelText: 'Work completed',
                prefixIcon: Icon(Icons.build_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _partsController,
              decoration: const InputDecoration(
                labelText: 'Parts replaced',
                prefixIcon: Icon(Icons.settings_suggest_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _chargeController,
              decoration: const InputDecoration(
                labelText: 'Service charge',
                hintText: '0.00',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _paymentController,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                hintText: 'Cash, card, bank transfer...',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            Text(
              'Maintenance schedule',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set a recurring service interval and HomeVault will calculate the next service date automatically.',
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: const ValueKey('serviceIntervalValueField'),
                    controller: _serviceIntervalController,
                    decoration: const InputDecoration(
                      labelText: 'Service interval',
                      hintText: 'Example: 6',
                      prefixIcon: Icon(Icons.repeat_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    onChanged: (_) {
                      setState(() {
                        if (_serviceIntervalValue == null) {
                          _nextServiceDate = null;
                          _reminderEnabled = false;
                        } else {
                          _recalculateNextServiceDate();
                        }
                      });
                    },
                    validator: (value) {
                      final input = value?.trim() ?? '';
                      if (input.isEmpty) return null;

                      final interval = int.tryParse(input);
                      if (interval == null || interval <= 0) {
                        return 'Enter a value above 0.';
                      }

                      final maxInterval =
                          _serviceIntervalUnit == ServiceIntervalUnit.years
                          ? 20
                          : 240;
                      if (interval > maxInterval) {
                        final unit =
                            _serviceIntervalUnit == ServiceIntervalUnit.years
                            ? 'years'
                            : 'months';
                        return 'Use $maxInterval $unit or less.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ServiceIntervalUnit>(
                    key: const ValueKey('serviceIntervalUnitField'),
                    initialValue: _serviceIntervalUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: ServiceIntervalUnit.values
                        .map(
                          (unit) => DropdownMenuItem(
                            value: unit,
                            child: Text(unit.label),
                          ),
                        )
                        .toList(),
                    onChanged: (unit) {
                      if (unit == null || unit == _serviceIntervalUnit) return;
                      setState(() {
                        _serviceIntervalUnit = unit;
                        _recalculateNextServiceDate();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.next_plan_outlined),
              title: const Text('Next service date'),
              subtitle: Text(
                _nextServiceDate == null
                    ? 'Not scheduled'
                    : _hasServiceInterval
                    ? '${_date(_nextServiceDate!)} • Calculated automatically'
                    : _date(_nextServiceDate!),
              ),
              trailing: _hasServiceInterval
                  ? const Icon(
                      Icons.auto_awesome_outlined,
                      semanticLabel: 'Calculated automatically',
                    )
                  : Wrap(
                      children: [
                        if (_nextServiceDate != null)
                          IconButton(
                            tooltip: 'Clear date',
                            onPressed: () {
                              setState(() {
                                _nextServiceDate = null;
                                _reminderEnabled = false;
                              });
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Choose date',
                          onPressed: () => _selectDate(nextService: true),
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                      ],
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Maintenance reminder'),
              subtitle: const Text('Notify me before the next service date.'),
              value: _reminderEnabled,
              onChanged: _status == ServiceStatus.cancelled
                  ? null
                  : (value) => setState(() => _reminderEnabled = value),
            ),
            if (_reminderEnabled)
              DropdownButtonFormField<int>(
                initialValue: _reminderDaysBefore,
                decoration: const InputDecoration(
                  labelText: 'Reminder period',
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
                    setState(() => _reminderDaysBefore = value);
                  }
                },
              ),
            const SizedBox(height: 16),
            DocumentAttachmentField(
              title: 'Service receipt',
              description: 'Attach the payment receipt or service invoice.',
              icon: Icons.receipt_long_outlined,
              document: _receiptDocument,
              isLoading: _isPickingReceipt,
              onPick: () => _pickDocument(receipt: true),
              onRemove: () => _removeDocument(receipt: true),
            ),
            const SizedBox(height: 12),
            DocumentAttachmentField(
              title: 'Service / inspection report',
              description: 'Attach the technician or inspection report.',
              icon: Icons.fact_check_outlined,
              document: _reportDocument,
              isLoading: _isPickingReport,
              onPick: () => _pickDocument(receipt: false),
              onRemove: () => _removeDocument(receipt: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional notes',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isPickingReceipt || _isPickingReport ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Save changes' : 'Save service record'),
            ),
          ],
        ),
      ),
    );
  }
}
