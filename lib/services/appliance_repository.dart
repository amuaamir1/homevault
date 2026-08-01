import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/appliance.dart';

abstract class ApplianceRepository {
  Future<List<Appliance>> loadAppliances();

  Future<void> saveAppliances(List<Appliance> appliances);
}

class FileApplianceRepository implements ApplianceRepository {
  static const int _schemaVersion = 2;

  Future<File> _dataFile() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dataDirectory = Directory(
      path.join(documentsDirectory.path, 'homevault', 'data'),
    );
    await dataDirectory.create(recursive: true);
    return File(path.join(dataDirectory.path, 'appliances.json'));
  }

  @override
  Future<List<Appliance>> loadAppliances() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException('The saved data has an invalid format.');
      }

      final data = Map<String, dynamic>.from(decoded);
      final applianceData = data['appliances'];
      if (applianceData is! List) {
        return [];
      }

      return applianceData
          .whereType<Map>()
          .map((item) => Appliance.fromJson(Map<String, dynamic>.from(item)))
          .where((appliance) => appliance.id.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw ApplianceStorageException(
        'HomeVault could not read the saved appliance data.',
        error,
      );
    }
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    try {
      final file = await _dataFile();
      final temporaryFile = File('${file.path}.tmp');
      final payload = jsonEncode({
        'schemaVersion': _schemaVersion,
        'savedAt': DateTime.now().toIso8601String(),
        'appliances': appliances.map((item) => item.toJson()).toList(),
      });

      await temporaryFile.writeAsString(payload, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(file.path);
    } catch (error) {
      throw ApplianceStorageException(
        'HomeVault could not save the appliance data.',
        error,
      );
    }
  }
}

class MemoryApplianceRepository implements ApplianceRepository {
  MemoryApplianceRepository({List<Appliance> initialAppliances = const []})
    : _appliances = List<Appliance>.from(initialAppliances);

  List<Appliance> _appliances;

  @override
  Future<List<Appliance>> loadAppliances() async {
    return List<Appliance>.from(_appliances);
  }

  @override
  Future<void> saveAppliances(List<Appliance> appliances) async {
    _appliances = List<Appliance>.from(appliances);
  }
}

class ApplianceStorageException implements Exception {
  const ApplianceStorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
