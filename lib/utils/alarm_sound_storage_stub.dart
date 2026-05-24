Future<String> copyAlarmSoundToAppDocs({
  required String sourcePath,
  required String fileName,
}) {
  throw UnsupportedError(
    'Custom alarm sounds are only supported on IO builds.',
  );
}
