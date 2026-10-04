import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../bridge/bridge_protocol.dart';
import '../domain/mini_app.dart';
import 'mini_app_cubit.dart';

/// Anfitrión de una mini app de terceros.
///
/// Garantías de aislamiento:
/// - Solo carga mini apps del catálogo y solo navega dentro de su origen.
/// - Solo acepta mensajes del protocolo versionado (`parseBridgeMessage`).
/// - Le entrega un token delegado (5 min, alcance mínimo), nunca la sesión.
/// - Las operaciones sensibles las confirma el usuario en UI nativa.
class MiniAppPage extends StatefulWidget {
  const MiniAppPage({
    required this.definition,
    required this.environment,
    this.firstName,
    super.key,
  });

  final MiniAppDefinition definition;
  final AppEnvironment environment;
  final String? firstName;

  @override
  State<MiniAppPage> createState() => _MiniAppPageState();
}

class _MiniAppPageState extends State<MiniAppPage> {
  WebViewController? _controller;
  bool _pageLoading = true;
  bool _pageError = false;
  bool _miniAppReady = false;

  MiniAppCubit get _cubit => context.read<MiniAppCubit>();

  WebViewController _createController() {
    final origin = widget.definition.origin;
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('SuperAppHost', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              Uri.tryParse(request.url)?.origin == origin
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (_) => setState(() {
            _pageLoading = true;
            _pageError = false;
          }),
          onPageFinished: (_) => setState(() => _pageLoading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _pageLoading = false;
                _pageError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(widget.definition.entryUrl);
  }

  Future<void> _onMessage(JavaScriptMessage raw) async {
    final message = parseBridgeMessage(raw.message);
    switch (message) {
      case null:
        _cubit.bridgeMessageRejected();
      case BridgeReady():
        _miniAppReady = true;
        await _sendContext();
      case BridgeGetToken():
        await _cubit.authorize(); // El listener reenvía el contexto.
      case BridgeClose():
        if (mounted) context.pop();
      case BridgeRequestCredit():
        await _confirmCredit(message);
    }
  }

  Future<void> _sendContext() async {
    final token = _cubit.state.token;
    if (token == null || !_miniAppReady || !mounted) return;
    final scheme = Theme.of(context).colorScheme;
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    await _deliver('context', {
      'token': token.token,
      'expiresAt': token.expiresAt.toIso8601String(),
      'apiBaseUrl': widget.environment.apiBaseUrl,
      'firstName': widget.firstName,
      'theme': {
        'primary': hex(scheme.primary),
        'on-primary': hex(scheme.onPrimary),
        'surface': hex(scheme.surface),
        'on-surface': hex(scheme.onSurface),
        'card': hex(scheme.surfaceContainerHighest),
        'muted': hex(scheme.onSurfaceVariant),
      },
    });
  }

  Future<void> _confirmCredit(BridgeRequestCredit request) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CreditConfirmation(request: request),
    );
    if (!mounted) return;
    if (confirmed != true) {
      await _deliver('credit_result', {'status': 'cancelled'});
      return;
    }
    final result = await _cubit.requestCredit(
      amountMinor: request.amountMinor,
      termMonths: request.termMonths,
    );
    await _deliver('credit_result', switch (result) {
      Success(value: final id) => {
        'status': 'submitted',
        'reference': id.substring(0, 8).toUpperCase(),
      },
      Failure() => {'status': 'error'},
    });
  }

  Future<void> _deliver(String type, Map<String, Object?> payload) async {
    await _controller?.runJavaScript(bridgeDeliveryScript(type, payload));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.definition.title),
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<MiniAppCubit, MiniAppState>(
        listenWhen: (prev, next) => prev.token?.token != next.token?.token,
        listener: (context, state) => _sendContext(),
        builder: (context, state) => switch (state.status) {
          MiniAppStatus.authorizing => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Conectando'),
          ),
          MiniAppStatus.unavailable => const _Message(
            'Esta funcionalidad no está disponible por ahora.',
            tone: InlineMessageTone.info,
          ),
          MiniAppStatus.failure => _Message(
            state.failure?.message ?? 'No pudimos abrir la mini app.',
            onRetry: _cubit.authorize,
          ),
          MiniAppStatus.ready => _webView(),
        },
      ),
    );
  }

  Widget _webView() {
    final controller = _controller ??= _createController();
    if (_pageError) {
      // Caída parcial: el simulador (otro servicio) no responde, pero la
      // app sigue funcionando y se puede reintentar.
      return _Message(
        'El simulador no está disponible en este momento.',
        onRetry: () {
          _miniAppReady = false;
          controller.reload();
        },
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_pageLoading)
          const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
    this.text, {
    this.onRetry,
    this.tone = InlineMessageTone.error,
  });

  final String text;
  final VoidCallback? onRetry;
  final InlineMessageTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InlineMessage(
            text,
            tone: tone,
            action: onRetry == null
                ? null
                : TextButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CreditConfirmation extends StatelessWidget {
  const _CreditConfirmation({required this.request});

  final BridgeRequestCredit request;

  static String _usd(int minor) {
    final dollars = (minor ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '\$$dollars,${(minor % 100).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirma tu solicitud',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'El simulador es un servicio aliado. La solicitud la envía tu '
              'banca, solo con tu confirmación.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Monto: ${_usd(request.amountMinor)}'),
            Text('Plazo: ${request.termMonths} meses'),
            Text('Cuota referencial: ${_usd(request.monthlyPaymentMinor)}'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar solicitud'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
