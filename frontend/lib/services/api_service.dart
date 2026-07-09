import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http_parser/http_parser.dart';

class ApiService {
  final String baseUrl;
  final int agencyId;
  final String? token;

  ApiService({required this.baseUrl, required this.agencyId, this.token});

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    final response = await http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get data: ${response.statusCode}');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to put data: ${response.statusCode}');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to post data: ${response.statusCode}');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> sendVoiceCommand(String transcript) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/agent/command'),
      headers: _headers,
      body: jsonEncode({'transcript': transcript}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send voice command');
    }
  }

  Future<Map<String, dynamic>> sendInvoiceImage(List<int> bytes, String filename) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/agent/vision/invoice'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'), // Simplified for MVP
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to parse invoice image');
    }
  }

  Future<Map<String, dynamic>> sendBankStatementCsv(List<int> bytes, String filename) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/agent/allocate'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('text', 'csv'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to auto-allocate bank statement');
    }
  }

  Future<List<dynamic>> fetchProperties({String? search}) async {
    final uri = search != null && search.isNotEmpty 
        ? Uri.parse('$baseUrl/properties/?search=$search')
        : Uri.parse('$baseUrl/properties/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load properties');
    }
  }

  Future<List<dynamic>> fetchLandlords({String? search}) async {
    final uri = search != null && search.isNotEmpty 
        ? Uri.parse('$baseUrl/landlords/?search=$search')
        : Uri.parse('$baseUrl/landlords/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load landlords');
    }
  }

  Future<List<dynamic>> fetchTenants({String? search}) async {
    final uri = search != null && search.isNotEmpty 
        ? Uri.parse('$baseUrl/tenants/?search=$search')
        : Uri.parse('$baseUrl/tenants/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load tenants');
    }
  }

  Future<void> createBasicProperty(String address, String city, String postcode, int landlordId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/properties/'),
      headers: _headers,
      body: jsonEncode({
        'address_line_1': address,
        'city': city,
        'postcode': postcode,
        'landlord_id': landlordId,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to create property: ${response.body}');
  }

  Future<void> advancedSetup(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/properties/advanced-setup/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to setup property: ${response.body}');
  }

  Future<void> updateProperty(int id, String? roomNo, String address, String city, String postcode, int landlordId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/properties/$id'),
      headers: _headers,
      body: jsonEncode({
        'room_no': roomNo,
        'address_line_1': address,
        'city': city,
        'postcode': postcode,
        'landlord_id': landlordId,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to update property');
  }

  Future<void> addLandlord(String firstName, String lastName, {String? co, String? address1, String? address2, String? city, String? county, String? postcode, String? email, String? phone, String? communicationPreference}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/landlords/'),
      headers: _headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'co': co,
        'address_line_1': address1,
        'address_line_2': address2,
        'city': city,
        'county': county,
        'postcode': postcode,
        'email': email,
        'phone': phone,
        'communication_preference': communicationPreference,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to add landlord');
  }

  Future<void> updateLandlord(int id, String firstName, String lastName, {String? co, String? address1, String? address2, String? city, String? county, String? postcode, String? email, String? phone, String? communicationPreference}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/landlords/$id'),
      headers: _headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'co': co,
        'address_line_1': address1,
        'address_line_2': address2,
        'city': city,
        'county': county,
        'postcode': postcode,
        'email': email,
        'phone': phone,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to update landlord');
  }

  Future<void> addTenant(String firstName, String lastName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tenants/'),
      headers: _headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to add tenant');
  }

  Future<void> updateTenant(int id, String firstName, String lastName, {String? address1, String? address2, String? city, String? county, String? postcode, String? email, String? phone, String? communicationPreference}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$id'),
      headers: _headers,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'address_line_1': address1,
        'address_line_2': address2,
        'city': city,
        'county': county,
        'postcode': postcode,
        'email': email,
        'phone': phone,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to update tenant');
  }

  Future<Map<String, dynamic>> uploadTenantIdProof(int tenantId, List<int> bytes, String filename, bool useAi) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/tenants/$tenantId/upload-id?use_ai=$useAi'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload ID proof: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadAgencyLogo(List<int> bytes, String filename) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/agencies/logo'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload agency logo: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateAgencyName(String agencyName) async {
    final response = await http.put(
      Uri.parse('$baseUrl/agencies'),
      headers: _headers,
      body: jsonEncode({'agency_name': agencyName}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update agency name: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getAgencyProfile() async {
    final response = await http.get(Uri.parse('$baseUrl/agency/profile'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch agency profile: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateAgencyVatSettings({
    required bool vatEnabled,
    required double defaultVatRate,
    required bool vatRegistered,
    required String? vatRegistrationNumber,
    required String agencyName,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/agencies'),
      headers: _headers,
      body: jsonEncode({
        'agency_name': agencyName,
        'vat_enabled': vatEnabled,
        'default_vat_rate': defaultVatRate,
        'vat_registered': vatRegistered,
        'vat_registration_number': vatRegistrationNumber,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update VAT settings: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateAgencyDetails(
    String agencyName, {
    String? address,
    String? contactNumber,
    String? emailAddress,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/agencies'),
      headers: _headers,
      body: jsonEncode({
        'agency_name': agencyName,
        'address': address,
        'contact_number': contactNumber,
        'email_address': emailAddress,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update agency details: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> updateUserName(String name) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/me'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update profile name: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadUserAvatar(List<int> bytes, String filename) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/users/avatar'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    ));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload profile picture: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load current user profile');
    }
  }

  Future<void> updateTenantVerifyStatus(int tenantId, String status, String? notes) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tenants/$tenantId/verify-status'),
      headers: _headers,
      body: jsonEncode({
        'status': status,
        'notes': notes,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to update verification status');
  }

  Future<List<dynamic>> fetchMaintenance(int propertyId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/properties/$propertyId/maintenance/'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load maintenance records');
    }
  }

  Future<List<dynamic>> fetchServiceProviders({String? search}) async {
    final uri = search != null && search.isNotEmpty
        ? Uri.parse('$baseUrl/service-providers/?search=$search')
        : Uri.parse('$baseUrl/service-providers/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load service providers');
    }
  }

  Future<void> createServiceProvider(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/service-providers/'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to add service provider');
  }

  Future<void> updateServiceProvider(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/service-providers/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw Exception('Failed to update service provider');
  }

  Future<void> deleteServiceProvider(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/service-providers/$id'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to delete service provider');
  }

  Future<void> addMaintenance({
    required int propertyId,
    required String type,
    required String details,
    required double cost,
    required double actualCost,
    double baseCost = 0.0,
    double vatRate = 0.0,
    double vatAmount = 0.0,
    required DateTime date,
    int? serviceProviderId,
    List<int>? invoiceBytes,
    String? filename,
  }) async {
    var queryParams = 'maintenance_type=$type&details=$details&cost=$cost&actual_cost=$actualCost&base_cost=$baseCost&vat_rate=$vatRate&vat_amount=$vatAmount&maintenance_date=${date.toIso8601String()}';
    if (serviceProviderId != null) queryParams += '&service_provider_id=$serviceProviderId';
    
    var uri = Uri.parse('$baseUrl/properties/$propertyId/maintenance/?$queryParams');
    
    if (invoiceBytes != null) {
      var request = http.MultipartRequest('POST', uri);
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        invoiceBytes,
        filename: filename ?? 'invoice.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
      var response = await request.send();
      if (response.statusCode != 200) throw Exception('Failed to add maintenance with invoice');
    } else {
      final response = await http.post(uri, headers: _headers);
      if (response.statusCode != 200) throw Exception('Failed to add maintenance');
    }
  }

  Future<void> deleteMaintenance(int propertyId, int maintenanceId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/properties/$propertyId/maintenance/$maintenanceId'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to delete maintenance');
  }

  Future<List<dynamic>> fetchBankEntries() async {
    final response = await http.get(Uri.parse('$baseUrl/finance/bank-entries/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load bank entries');
  }

  Future<void> createBankEntry(Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/finance/bank-entries/'), headers: _headers, body: jsonEncode(data));
    if (response.statusCode != 200) throw Exception('Failed to add bank entry');
  }

  Future<List<dynamic>> fetchExpectedPayments() async {
    final response = await http.get(Uri.parse('$baseUrl/finance/expected-payments/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load expected payments');
  }

  Future<void> allocatePayment(Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/finance/allocate/'), headers: _headers, body: jsonEncode(data));
    if (response.statusCode != 200) throw Exception('Failed to allocate payment: ${response.body}');
  }

  Future<List<dynamic>> fetchGroupedLandlordPayouts() async {
    final response = await http.get(Uri.parse('/finance/landlord-payouts/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load grouped payouts');
  }

  Future<void> executeLandlordPayout(int landlordId) async {
    final response = await http.post(Uri.parse('/finance/landlord-payouts/execute/'), headers: _headers, body: jsonEncode({'landlord_id': landlordId}));
    if (response.statusCode != 200) throw Exception('Failed to execute payout');
  }

  Future<List<dynamic>> fetchPayouts({String? paymentType, String? status, String? timeframe}) async {
    List<String> queryParams = [];
    if (paymentType != null && paymentType.isNotEmpty) queryParams.add('payment_type=$paymentType');
    if (status != null && status.isNotEmpty) queryParams.add('status=$status');
    if (timeframe != null && timeframe.isNotEmpty) queryParams.add('timeframe=$timeframe');
    
    String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await http.get(Uri.parse('$baseUrl/finance/payouts/$queryString'), headers: _headers);
    
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load payouts');
  }

  Future<List<dynamic>> fetchPaymentPlan(int tenancyId) async {
    final response = await http.get(Uri.parse('$baseUrl/tenancies/$tenancyId/payment-plan/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load payment plan');
  }

  Future<void> quickCollect(int tenancyId, double amount, String reference) async {
    final response = await http.post(
      Uri.parse('$baseUrl/finance/quick-collect/?tenancy_id=$tenancyId&amount=$amount&reference=$reference'),
      headers: _headers,
    );
    if (response.statusCode != 200) throw Exception('Failed to collect rent: ${response.body}');
  }

  Future<List<dynamic>> fetchUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users/'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> createSubAgent(String name, String email, String password, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to create sub-agent: ${response.body}');
  }

  Future<void> updateUserByAdmin(int userId, String name, String email, String? password, String role) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to update agent: ${response.body}');
  }

  Future<List<dynamic>> fetchAllPayouts() async {
    final response = await http.get(Uri.parse('$baseUrl/finance/payouts/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load payouts');
  }
  
  Future<Map<String, dynamic>> fetchPayoutsSummary() async {
    final response = await http.get(Uri.parse('$baseUrl/finance/payouts/summary'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load payouts summary');
  }

  Future<void> updatePayoutStatus(int payoutId, String status, {String? referenceNumber}) async {
    final body = {'status': status};
    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      body['reference_number'] = referenceNumber;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/finance/payouts/$payoutId/status'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update payout status: ${response.body}');
    }
  }

  Future<List<dynamic>> fetchPropertyStatements(int propertyId) async {
    final response = await http.get(Uri.parse('$baseUrl/properties/$propertyId/statements/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load statements');
  }

  Future<void> issueLandlordAdvance(int landlordId, double amount, String notes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/finance/advances/'),
      headers: _headers,
      body: jsonEncode({
        'landlord_id': landlordId,
        'amount': amount,
        'notes': notes,
      }),
    );
    if (response.statusCode != 200) throw Exception('Failed to issue advance: ${response.body}');
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/stats/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load dashboard stats');
  }


  
  Future<Map<String, dynamic>> previewReport(Map<String, dynamic> requestData) async {
    requestData['agency_id'] = agencyId;
    final response = await http.post(
      Uri.parse('$baseUrl/reports/preview'),
      headers: _headers,
      body: jsonEncode(requestData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to preview report: ${response.body}');
  }

  Future<Map<String, dynamic>> generateReportPdf(Map<String, dynamic> reportData) async {
    reportData['agency_id'] = agencyId;
    final response = await http.post(
      Uri.parse('$baseUrl/reports/generate'),
      headers: _headers,
      body: jsonEncode(reportData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate report PDF: ${response.body}');
  }

  Future<List<dynamic>> fetchDailyReports() async {
    final response = await http.get(Uri.parse('$baseUrl/agency/reports/daily/'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load daily daily reports');
  }

  Future<Map<String, dynamic>> getDepositInfo(int tenantId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tenants/$tenantId/deposit-info'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load deposit info: ${response.body}');
  }

  Future<void> refundDeposit(int tenantId, double amount, String reference) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tenants/$tenantId/refund-deposit'),
      headers: _headers,
      body: json.encode({
        'amount': amount,
        'reference': reference,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to refund deposit: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> generateDailyReport(String? date) async {
    final response = await http.post(
      Uri.parse('$baseUrl/agency/reports/daily/'),
      headers: _headers,
      body: jsonEncode({'date': date}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate daily report: ${response.body}');
  }

  
  Future<Map<String, dynamic>> fetchEmailActivitySummary() async {
    final response = await http.get(Uri.parse('$baseUrl/email-activity/summary?agency_id=$agencyId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'total_sent_today': 0, 'total_opened': 0, 'total_unopened': 0, 'total_auto_reminders': 0, 'total_failed': 0};
  }
  
  Future<Map<String, dynamic>> fetchEmailActivityLogs({int? propertyId, int? tenantId, String? status, int limit = 50, int offset = 0}) async {
    String url = '$baseUrl/email-activity/logs?agency_id=$agencyId&limit=$limit&offset=$offset';
    if (propertyId != null) url += '&property_id=$propertyId';
    if (tenantId != null) url += '&tenant_id=$tenantId';
    if (status != null && status != 'All') url += '&status=$status';
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'total': 0, 'logs': []};
  }

  Future<Map<String, dynamic>> fetchDashboardEmails() async {
    final response = await http.get(Uri.parse('$baseUrl/communications/dashboard?agency_id=$agencyId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'total_received_today': 0, 'total_sent_today': 0, 'unread': 0};
  }
  
  Future<List<dynamic>> fetchPropertyCommunications(int propertyId) async {
    final response = await http.get(Uri.parse('$baseUrl/communications/property/$propertyId?agency_id=$agencyId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> fetchUnassignedCommunications() async {
    final response = await http.get(Uri.parse('$baseUrl/communications/unassigned?agency_id=$agencyId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<void> markCommunicationRead(int msgId) async {
    await http.put(Uri.parse('$baseUrl/communications/$msgId/read?agency_id=$agencyId'), headers: _headers);
  }

  Future<void> linkCommunicationProperty(int msgId, int propertyId) async {
    await http.put(
      Uri.parse('$baseUrl/communications/$msgId/link_property?agency_id=$agencyId'),
      headers: _headers,
      body: jsonEncode({'property_id': propertyId}),
    );
  }
  
  Future<dynamic> sendCommunicationWithAttachment({
    required Map<String, dynamic> data,
    List<int>? fileBytes,
    String? fileName,
    String? localFilePath,
    String? systemReportType,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/communications/send_with_attachment?agency_id=$agencyId'),
    );
    
    // Add headers manually
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    // Add form fields
    data.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });
    
    if (systemReportType != null) {
      request.fields['system_report_type'] = systemReportType;
    }
    
    // Add file
    if (fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    } else if (localFilePath != null && !kIsWeb) {
      request.files.add(await http.MultipartFile.fromPath('file', localFilePath));
    }
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send communication: ${response.body}');
  }

  Future<dynamic> sendCommunication(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/communications/send?agency_id=$agencyId'),
      headers: _headers,
      body: jsonEncode(data)
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to send communication: ${response.body}');
  }
  
  Future<Map<String, dynamic>> getCommunicationConfig() async {
    final response = await http.get(Uri.parse('$baseUrl/communications/config?agency_id=$agencyId'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to get config');
  }

  Future<void> updateCommunicationConfig(Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse('$baseUrl/communications/config?agency_id=$agencyId'), headers: _headers, body: jsonEncode(data));
    if (response.statusCode != 200) throw Exception('Failed to update config');
  }

  // --- MAGIC LINK & LANDLORD PORTAL ---

  Future<Map<String, dynamic>> requestMagicLink(String email) async {
    String clientUrl = 'http://localhost:3000';
    try {
      clientUrl = Uri.base.origin;
    } catch (e) {
      // Ignore if not on web
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/magic-link/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'client_url': clientUrl})
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to request magic link: ${response.body}');
  }

  Future<Map<String, dynamic>> verifyMagicLink(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/magic-link/verify?token=$token')
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to verify magic link: ${response.body}');
  }

  Future<List<dynamic>> fetchLandlordProperties() async {
    final response = await http.get(Uri.parse('$baseUrl/landlord/properties'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to fetch landlord properties: ${response.body}');
  }

  Future<List<dynamic>> fetchLandlordInvoices() async {
    final response = await http.get(Uri.parse('$baseUrl/landlord/invoices'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to fetch landlord invoices: ${response.body}');
  }

  Future<List<dynamic>> fetchLandlordCommunications() async {
    final response = await http.get(Uri.parse('$baseUrl/landlord/communications'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to fetch landlord communications: ${response.body}');
  }

  Future<void> logLandlordAudit(String action, String resourceType, int? resourceId, String details) async {
    final response = await http.post(
      Uri.parse('$baseUrl/landlord/audit?action=$action&resource_type=$resourceType&details=$details' + (resourceId != null ? '&resource_id=$resourceId' : '')),
      headers: _headers
    );
    if (response.statusCode != 200) print('Failed to log audit: ${response.body}');
  }

  // Templates endpoints
  Future<List<dynamic>> fetchTemplates() async {
    final response = await http.get(Uri.parse('$baseUrl/api/templates'), headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load templates: ${response.statusCode}');
    }
  }

  Future<void> deleteTemplate(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/api/templates/$id'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete template: ${response.statusCode}');
    }
  }
}

