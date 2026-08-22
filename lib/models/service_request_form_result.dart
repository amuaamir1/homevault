import 'service_request.dart';

class ServiceRequestFormResult {
  const ServiceRequestFormResult({
    required this.applianceId,
    required this.request,
    this.originalRequest,
  });

  final String applianceId;
  final ServiceRequest request;
  final ServiceRequest? originalRequest;

  bool get isEditing => originalRequest != null;
}
