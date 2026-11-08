import 'package:http/http.dart' as http;

// Mantiene la compatibilidad con la app Android original.
http.Client createApiClient() => http.Client();
