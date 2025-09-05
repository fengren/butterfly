import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/debug_console_page.dart';

class AuthService {
  static const _loginUrl = 'https://liangyi.29gpt.com/api/v1/auth/login';
  static const _csrfToken = 'wbAUCCJlAEB7Vfc8s5wLVqRTDfkUAD2r';

  static Future<bool> login() async {
    print('[LOGIN] POST $_loginUrl');
    final response = await http.post(
      Uri.parse(_loginUrl),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'X-CSRFTOKEN': _csrfToken,
      },
      body: jsonEncode({'username': 'test', 'password': 'test_password'}),
    );
    print(
      '[LOGIN] 响应: ${response.statusCode}\n${response.body}',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['code'] == 0) {
        final access = data['data']['access'];
        final refresh = data['data']['refresh'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', access);
        await prefs.setString('refresh_token', refresh);
        return true;
      }
    }
    return false;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }
}