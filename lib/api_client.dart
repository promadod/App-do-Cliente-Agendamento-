import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio = Dio(
    BaseOptions(
      // ⚠️ ATENÇÃO: Se usar Emulador use 10.0.2.2. Se usar celular real, use o IP do PC (ex: 192.168.0.10)
      baseUrl: 'https://oneiratech01.pythonanywhere.com/api/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
}
