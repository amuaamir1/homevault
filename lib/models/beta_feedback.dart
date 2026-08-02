enum FeedbackCategory {
  bug,
  featureRequest,
  performance,
  authentication,
  documents,
  other,
}

extension FeedbackCategoryDetails on FeedbackCategory {
  String get label => switch (this) {
    FeedbackCategory.bug => 'Bug',
    FeedbackCategory.featureRequest => 'Feature request',
    FeedbackCategory.performance => 'Performance issue',
    FeedbackCategory.authentication => 'Authentication issue',
    FeedbackCategory.documents => 'Document problem',
    FeedbackCategory.other => 'Other',
  };
}

class BetaFeedback {
  const BetaFeedback({
    required this.category,
    required this.message,
    this.screenshotFileName,
    this.screenshotBase64,
  });

  final FeedbackCategory category;
  final String message;
  final String? screenshotFileName;
  final String? screenshotBase64;

  bool get isValid {
    final trimmed = message.trim();
    return trimmed.length >= 10 && trimmed.length <= 5000;
  }
}
