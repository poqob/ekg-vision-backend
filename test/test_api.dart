import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Replace with your actual JWT token and patient ID
  final token = 'YOUR_JWT_TOKEN_HERE';
  final patientId = 'YOUR_PATIENT_ID_HERE';

  // Test /patient/:id endpoint
  final patientResponse = await http.get(
    Uri.parse('http://localhost:8080/patient/$patientId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  print('GET /patient/$patientId: ${patientResponse.statusCode}');
  print(patientResponse.body);

  // Test /scan_results endpoint
  final scanResultsResponse = await http.get(
    Uri.parse('http://localhost:8080/scan_results'),
    headers: {'Authorization': 'Bearer $token'},
  );
  print('GET /scan_results: ${scanResultsResponse.statusCode}');
  print(scanResultsResponse.body);
}
