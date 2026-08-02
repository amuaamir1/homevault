import 'appliance.dart';
import 'service_record.dart';

class CountBreakdown {
  const CountBreakdown({required this.label, required this.count});

  final String label;
  final int count;
}

class MaintenanceCostSummary {
  const MaintenanceCostSummary({
    required this.applianceId,
    required this.applianceName,
    required this.cost,
  });

  final String applianceId;
  final String applianceName;
  final double cost;
}

class UpcomingWarrantySummary {
  const UpcomingWarrantySummary({
    required this.applianceId,
    required this.applianceName,
    required this.expiryDate,
    required this.daysRemaining,
  });

  final String applianceId;
  final String applianceName;
  final DateTime expiryDate;
  final int daysRemaining;
}

class UpcomingServiceSummary {
  const UpcomingServiceSummary({
    required this.applianceId,
    required this.applianceName,
    required this.record,
    required this.daysRemaining,
  });

  final String applianceId;
  final String applianceName;
  final ServiceRecord record;
  final int daysRemaining;
}

class HomeVaultReport {
  const HomeVaultReport({
    required this.totalAppliances,
    required this.totalDocuments,
    required this.totalServiceRecords,
    required this.totalServiceCost,
    required this.activeServiceRecords,
    required this.appliancesWithDocuments,
    required this.appliancesWithSupport,
    required this.appliancesWithWarrantyDate,
    required this.appliancesWithServiceHistory,
    required this.warrantyCounts,
    required this.categoryBreakdown,
    required this.documentBreakdown,
    required this.serviceStatusBreakdown,
    required this.topMaintenanceCosts,
    required this.upcomingWarranties,
    required this.upcomingServices,
  });

  final int totalAppliances;
  final int totalDocuments;
  final int totalServiceRecords;
  final double totalServiceCost;
  final int activeServiceRecords;
  final int appliancesWithDocuments;
  final int appliancesWithSupport;
  final int appliancesWithWarrantyDate;
  final int appliancesWithServiceHistory;
  final Map<WarrantyStatus, int> warrantyCounts;
  final List<CountBreakdown> categoryBreakdown;
  final List<CountBreakdown> documentBreakdown;
  final List<CountBreakdown> serviceStatusBreakdown;
  final List<MaintenanceCostSummary> topMaintenanceCosts;
  final List<UpcomingWarrantySummary> upcomingWarranties;
  final List<UpcomingServiceSummary> upcomingServices;

  int warrantyCount(WarrantyStatus status) => warrantyCounts[status] ?? 0;

  int get appliancesWithoutDocuments =>
      totalAppliances - appliancesWithDocuments;

  int get appliancesWithoutSupport => totalAppliances - appliancesWithSupport;

  int get appliancesWithoutWarrantyDate =>
      totalAppliances - appliancesWithWarrantyDate;

  int get appliancesWithoutServiceHistory =>
      totalAppliances - appliancesWithServiceHistory;

  double completionRate(int completed) {
    if (totalAppliances == 0) {
      return 0;
    }
    return completed / totalAppliances;
  }
}
