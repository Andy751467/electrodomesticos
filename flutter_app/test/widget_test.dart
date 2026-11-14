import 'package:flutter_test/flutter_test.dart';
import 'package:electrohogar_mobile/main.dart';

void main() {
  test('ElectroHogar usa una direccion de API para conectar con PHP', () {
    final url = ApiService.instance.baseUrl;
    expect(url, contains('/api'));
  });

  test('La aplicacion Flutter ElectroHogarApp esta disponible', () {
    const app = ElectroHogarApp();
    expect(app, isA<ElectroHogarApp>());
  });
}
