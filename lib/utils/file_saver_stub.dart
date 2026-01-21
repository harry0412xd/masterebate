// Fallback stub for non-web platforms (or when web implementation isn't selected).
// This file will be used on non-web targets.

Future<String> saveCsvAndReturn(String csv, String filename) async {
  throw UnsupportedError('saveCsvAndReturn is not implemented for this platform.');
}
