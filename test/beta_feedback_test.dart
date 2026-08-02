import 'package:flutter_test/flutter_test.dart';
import 'package:homevault/models/beta_feedback.dart';

void main() {
  test('feedback requires a useful message length', () {
    expect(
      const BetaFeedback(
        category: FeedbackCategory.bug,
        message: 'Too short',
      ).isValid,
      isFalse,
    );

    expect(
      const BetaFeedback(
        category: FeedbackCategory.bug,
        message: 'The application closes after I open the warranty screen.',
      ).isValid,
      isTrue,
    );
  });

  test('feedback category labels are user friendly', () {
    expect(FeedbackCategory.featureRequest.label, 'Feature request');
    expect(FeedbackCategory.authentication.label, 'Authentication issue');
  });
}
