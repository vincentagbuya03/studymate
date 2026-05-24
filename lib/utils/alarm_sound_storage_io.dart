import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> copyAlarmSoundToAppDocs({
  required String sourcePath,
  required String fileName,
}) async {
  final File selectedFile = File(sourcePath);
  final Directory appDocsDir = await getApplicationDocumentsDirectory();
  final String newFilePath = p.join(appDocsDir.path, fileName);
  await selectedFile.copy(newFilePath);
  return newFilePath;
}
