import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAdapter adapter;
  late InMemoryTokenStore tokens;
  late InMemoryCacheStore cache;
  late AuthApiRepository repository;

  const userJson = {
    'id': 'u1',
    'email': 'ana@example.com',
    'fullName': 'Ana Gómez',
    'goal': 'invest',
    'segment': 'investor',
  };
  const authResponse = {
    'user': userJson,
    'session': {'accessToken': 'acc', 'refreshToken': 'ref'},
  };

  setUp(() {
    adapter = FakeAdapter();
    tokens = InMemoryTokenStore();
    cache = InMemoryCacheStore();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    repository = AuthApiRepository(
      api: ApiClient(dio),
      tokenStore: tokens,
      cache: cache,
    );
  });

  test('register envía el contrato del BFF y abre la sesión', () async {
    adapter.enqueueJson(201, authResponse);

    final result = await repository.register(
      const RegistrationData(
        fullName: ' Ana Gómez ',
        email: 'ana@example.com',
        password: 'Segura123',
        goal: FinancialGoal.invest,
      ),
    );

    final request = adapter.requests.single;
    expect(request.path, '/v1/auth/register');
    expect(request.data, {
      'fullName': 'Ana Gómez',
      'email': 'ana@example.com',
      'password': 'Segura123',
      'goal': 'invest',
      'acceptTerms': true,
    });
    expect(request.extra[AuthInterceptor.skipAuthKey], isTrue);
    expect(result.valueOrNull?.goal, FinancialGoal.invest);
    expect((await tokens.read())?.accessToken, 'acc');
    expect(await repository.cachedProfile(), result.valueOrNull);
  });

  test('login fallido no guarda tokens', () async {
    adapter.enqueueError(401, 'invalid_credentials');

    final result = await repository.login(email: 'a@b.co', password: 'x');

    expect(result, isA<Failure<UserProfile>>());
    expect(await repository.hasStoredSession(), isFalse);
  });

  test('logout revoca en el BFF y borra tokens y caché', () async {
    await tokens.save(const SessionTokens(accessToken: 'a', refreshToken: 'r'));
    await cache.write('accounts', [1, 2]);
    adapter.enqueueJson(204, null);

    await repository.logout();

    expect(adapter.requests.single.data, {'refreshToken': 'r'});
    expect(await tokens.read(), isNull);
    expect(await cache.read('accounts'), isNull);
  });

  test('logout sin red igual borra los datos locales', () async {
    await tokens.save(const SessionTokens(accessToken: 'a', refreshToken: 'r'));
    adapter.enqueueTransportError(DioExceptionType.connectionError);

    await repository.logout();

    expect(await tokens.read(), isNull);
  });

  test('fetchProfile actualiza el perfil en caché', () async {
    adapter.enqueueJson(200, userJson);

    await repository.fetchProfile();

    expect((await repository.cachedProfile())?.fullName, 'Ana Gómez');
  });
}
