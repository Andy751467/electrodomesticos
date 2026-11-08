import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

// En Chrome, el navegador administra PHPSESSID.
// withCredentials permite que la cookie se envie al dashboard y productos.
http.Client createApiClient() => BrowserClient()..withCredentials = true;
