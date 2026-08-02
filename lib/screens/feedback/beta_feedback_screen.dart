import 'package:flutter/material.dart';

import '../../auth/auth_scope.dart';
import '../../models/beta_feedback.dart';
import '../../services/beta_feedback_service.dart';

class BetaFeedbackScreen extends StatefulWidget {
  const BetaFeedbackScreen({super.key});

  @override
  State<BetaFeedbackScreen> createState() => _BetaFeedbackScreenState();
}

class _BetaFeedbackScreenState extends State<BetaFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _service = BetaFeedbackService();

  FeedbackCategory _category = FeedbackCategory.bug;
  SelectedFeedbackScreenshot? _screenshot;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final selected = await _service.pickScreenshot();
      if (!mounted || selected == null) return;
      setState(() => _screenshot = selected);
    } on FeedbackSubmissionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final uid = AuthScope.read(context).user?.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      await _service.submit(
        uid: uid,
        feedback: BetaFeedback(
          category: _category,
          message: _messageController.text,
          screenshotFileName: _screenshot?.fileName,
          screenshotBase64: _screenshot?.base64Data,
        ),
      );

      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _screenshot = null;
        _category = FeedbackCategory.bug;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. Your feedback was sent.')),
      );
    } on FeedbackSubmissionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send beta feedback')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Describe what happened and how to reproduce it. '
                  'HomeVault automatically includes only the app version and '
                  'basic Android device information—not appliance or document data.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FeedbackCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Feedback category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: FeedbackCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              minLines: 6,
              maxLines: 12,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Describe the issue or suggestion',
                alignLabelWithHint: true,
                hintText:
                    'What did you do, what happened, and what did you expect?',
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;

                if (length < 10) {
                  return 'Enter at least 10 characters.';
                }

                if (length > 5000) {
                  return 'Keep feedback below 5000 characters.';
                }

                return null;
              },
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.screenshot_outlined),
                title: const Text('Optional screenshot'),
                subtitle: Text(
                  _screenshot?.fileName ??
                      'PNG or JPG, maximum 450 KB. Check that it contains no private information.',
                ),
                trailing: _screenshot == null
                    ? const Icon(Icons.attach_file)
                    : IconButton(
                        tooltip: 'Remove screenshot',
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _screenshot = null),
                        icon: const Icon(Icons.close),
                      ),
                onTap: _isSubmitting ? null : _pickScreenshot,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSubmitting ? 'Sending...' : 'Send feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
