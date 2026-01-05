// lib/services/google_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class IOHttpClient extends http.BaseClient {
  final Map<String, String> headers;
  IOHttpClient(this.headers);
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _inner.send(request);
  }
}

class GoogleService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      sheets.SheetsApi.spreadsheetsScope,
    ],
  );

  static Future<String?> exportExpenses(List<Map<String, dynamic>> expenses) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final client = IOHttpClient(authHeaders);

      final driveApi = drive.DriveApi(client);
      final file = drive.File()
        ..name = 'Credit Card Expenses ${DateFormat('yyyy-MM-dd').format(DateTime.now())}'
        ..mimeType = 'application/vnd.google-apps.spreadsheet';

      final created = await driveApi.files.create(file);
      final sheetId = created.id;
      if (sheetId == null) return null;

      final sheetsApi = sheets.SheetsApi(client);

      // Header
      await sheetsApi.spreadsheets.values.update(
        sheets.ValueRange(values: [['Card', 'Date', 'Amount', 'Description']]),
        sheetId,
        'A1',
        valueInputOption: 'USER_ENTERED',
      );

      if (expenses.isNotEmpty) {
        final values = expenses
            .map((e) => [e['card'], e['date'], e['amount'], e['desc']])
            .toList();
        await sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: values),
          sheetId,
          'A:D',
          valueInputOption: 'USER_ENTERED',
        );
      }

      return sheetId;
    } catch (e) {
      debugPrint('Google Sheets export error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> importExpenses(String sheetId) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final client = IOHttpClient(authHeaders);
      final sheetsApi = sheets.SheetsApi(client);

      final resp = await sheetsApi.spreadsheets.values.get(sheetId, 'A:D');
      final values = resp.values;
      if (values == null || values.isEmpty || values[0][0] != 'Card') return null;

      List<Map<String, dynamic>> result = [];
      for (var row in values.skip(1)) {
        if (row.length < 4) continue;
        result.add({
          'card': row[0],
          'date': row[1],
          'amount': double.tryParse(row[2].toString()) ?? 0.0,
          'desc': row[3],
        });
      }
      return result;
    } catch (e) {
      debugPrint('Google Sheets import error: $e');
      return null;
    }
  }
}