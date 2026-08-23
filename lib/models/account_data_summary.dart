import 'appliance.dart';

class AccountDataSummary {
  const AccountDataSummary({
    required this.applianceCount,
    required this.documentCount,
    required this.serviceRecordCount,
    required this.serviceRequestCount,
  });

  factory AccountDataSummary.fromAppliances(Iterable<Appliance> appliances) {
    var applianceCount = 0;
    var documentCount = 0;
    var serviceRecordCount = 0;
    var serviceRequestCount = 0;

    for (final appliance in appliances) {
      applianceCount++;
      documentCount += appliance.allAttachments.length;
      serviceRecordCount += appliance.serviceRecordCount;
      serviceRequestCount += appliance.serviceRequestCount;
    }

    return AccountDataSummary(
      applianceCount: applianceCount,
      documentCount: documentCount,
      serviceRecordCount: serviceRecordCount,
      serviceRequestCount: serviceRequestCount,
    );
  }

  final int applianceCount;
  final int documentCount;
  final int serviceRecordCount;
  final int serviceRequestCount;

  bool get isEmpty =>
      applianceCount == 0 &&
      documentCount == 0 &&
      serviceRecordCount == 0 &&
      serviceRequestCount == 0;
}
