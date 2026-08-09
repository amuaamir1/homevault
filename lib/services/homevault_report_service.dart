import '../models/appliance.dart';
import '../models/homevault_report.dart';
import '../models/service_record.dart';
import '../models/stored_document.dart';

class HomeVaultReportService {
  const HomeVaultReportService();

  HomeVaultReport build(Iterable<Appliance> appliances, {DateTime? now}) {
    final applianceList = appliances.toList(growable: false);
    final referenceDate = now ?? DateTime.now();

    final warrantyCounts = <WarrantyStatus, int>{
      for (final status in WarrantyStatus.values) status: 0,
    };
    final categoryCounts = <String, int>{};
    final documentCounts = <DocumentType, int>{
      for (final type in DocumentType.values) type: 0,
    };
    final serviceStatusCounts = <ServiceStatus, int>{
      for (final status in ServiceStatus.values) status: 0,
    };
    final maintenanceCosts = <MaintenanceCostSummary>[];
    final upcomingWarranties = <UpcomingWarrantySummary>[];
    final upcomingServices = <UpcomingServiceSummary>[];

    var totalDocuments = 0;
    var totalServiceRecords = 0;
    var totalServiceCost = 0.0;
    var activeServiceRecords = 0;
    var appliancesWithDocuments = 0;
    var appliancesWithSupport = 0;
    var appliancesWithWarrantyDate = 0;
    var appliancesWithServiceHistory = 0;

    for (final appliance in applianceList) {
      final category = appliance.category.trim().isEmpty
          ? 'Other'
          : appliance.category.trim();
      categoryCounts.update(category, (count) => count + 1, ifAbsent: () => 1);

      final warrantyStatus = appliance.warrantyStatusAt(referenceDate);
      warrantyCounts[warrantyStatus] =
          (warrantyCounts[warrantyStatus] ?? 0) + 1;

      if (appliance.hasDocuments) {
        appliancesWithDocuments++;
      }
      if (appliance.hasSupportDetails) {
        appliancesWithSupport++;
      }
      if (appliance.effectiveWarrantyExpiryDate != null) {
        appliancesWithWarrantyDate++;
      }
      if (appliance.serviceRecords.isNotEmpty) {
        appliancesWithServiceHistory++;
      }

      totalDocuments += appliance.documentCount;
      for (final document in appliance.allDocuments) {
        documentCounts[document.type] =
            (documentCounts[document.type] ?? 0) + 1;
      }

      totalServiceRecords += appliance.serviceRecordCount;
      totalServiceCost += appliance.totalServiceCost;
      if (appliance.totalServiceCost > 0) {
        maintenanceCosts.add(
          MaintenanceCostSummary(
            applianceId: appliance.id,
            applianceName: appliance.name,
            cost: appliance.totalServiceCost,
          ),
        );
      }

      final warrantyDays = appliance.warrantyDaysRemainingAt(referenceDate);
      final warrantyExpiry = appliance.effectiveWarrantyExpiryDate;
      if (warrantyDays != null &&
          warrantyExpiry != null &&
          warrantyDays >= 0 &&
          warrantyDays <= 90) {
        upcomingWarranties.add(
          UpcomingWarrantySummary(
            applianceId: appliance.id,
            applianceName: appliance.name,
            expiryDate: warrantyExpiry,
            daysRemaining: warrantyDays,
          ),
        );
      }

      for (final record in appliance.serviceRecords) {
        serviceStatusCounts[record.status] =
            (serviceStatusCounts[record.status] ?? 0) + 1;
        if (record.status.isActive) {
          activeServiceRecords++;
        }
      }

      final maintenanceRecord = appliance.maintenanceScheduleRecord;
      if (maintenanceRecord != null) {
        final serviceDays = maintenanceRecord.daysUntilNextService(
          referenceDate,
        );
        if (serviceDays != null && serviceDays >= 0 && serviceDays <= 30) {
          upcomingServices.add(
            UpcomingServiceSummary(
              applianceId: appliance.id,
              applianceName: appliance.name,
              record: maintenanceRecord,
              daysRemaining: serviceDays,
            ),
          );
        }
      }
    }

    maintenanceCosts.sort((a, b) => b.cost.compareTo(a.cost));
    upcomingWarranties.sort(
      (a, b) => a.daysRemaining.compareTo(b.daysRemaining),
    );
    upcomingServices.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return HomeVaultReport(
      totalAppliances: applianceList.length,
      totalDocuments: totalDocuments,
      totalServiceRecords: totalServiceRecords,
      totalServiceCost: totalServiceCost,
      activeServiceRecords: activeServiceRecords,
      appliancesWithDocuments: appliancesWithDocuments,
      appliancesWithSupport: appliancesWithSupport,
      appliancesWithWarrantyDate: appliancesWithWarrantyDate,
      appliancesWithServiceHistory: appliancesWithServiceHistory,
      warrantyCounts: Map.unmodifiable(warrantyCounts),
      categoryBreakdown: _sortedBreakdown(categoryCounts),
      documentBreakdown: DocumentType.values
          .where((type) => (documentCounts[type] ?? 0) > 0)
          .map(
            (type) => CountBreakdown(
              label: type.label,
              count: documentCounts[type] ?? 0,
            ),
          )
          .toList(growable: false),
      serviceStatusBreakdown: ServiceStatus.values
          .where((status) => (serviceStatusCounts[status] ?? 0) > 0)
          .map(
            (status) => CountBreakdown(
              label: status.label,
              count: serviceStatusCounts[status] ?? 0,
            ),
          )
          .toList(growable: false),
      topMaintenanceCosts: maintenanceCosts.take(5).toList(growable: false),
      upcomingWarranties: List.unmodifiable(upcomingWarranties),
      upcomingServices: List.unmodifiable(upcomingServices),
    );
  }

  List<CountBreakdown> _sortedBreakdown(Map<String, int> values) {
    final items = values.entries
        .map((entry) => CountBreakdown(label: entry.key, count: entry.value))
        .toList();
    items.sort((a, b) {
      final countComparison = b.count.compareTo(a.count);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.label.compareTo(b.label);
    });
    return List.unmodifiable(items);
  }
}
