import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/formatters.dart';
import '../widgets/skeleton.dart';
import 'transfer_cubit.dart';

class TransferPage extends StatelessWidget {
  const TransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir entre mis cuentas')),
      body: SafeArea(
        child: BlocBuilder<TransferCubit, TransferState>(
          builder: (context, state) => switch (state.status) {
            TransferStatus.loadingAccounts => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SkeletonList(rows: 3),
            ),
            TransferStatus.success => _Receipt(state: state),
            _ => _Form(state: state),
          },
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.state});

  final TransferState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TransferCubit>();
    final submitting = state.status == TransferStatus.submitting;
    final from = state.from;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DropdownButtonFormField<String>(
          initialValue: state.fromId,
          decoration: InputDecoration(
            labelText: 'Desde',
            errorText: state.fieldErrors[TransferField.from],
            helperText: from == null
                ? null
                : 'Disponible: ${Formatters.money(from.balanceMinor)}',
          ),
          items: [
            for (final account in state.accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: submitting ? null : (id) => cubit.fromSelected(id!),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: state.toId,
          decoration: InputDecoration(
            labelText: 'Hacia',
            errorText: state.fieldErrors[TransferField.to],
          ),
          items: [
            for (final account in state.accounts)
              DropdownMenuItem(value: account.id, child: Text(account.name)),
          ],
          onChanged: submitting ? null : (id) => cubit.toSelected(id!),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          enabled: !submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Hasta 7 dígitos enteros y 2 decimales, con coma o punto.
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d{0,7}([.,]\d{0,2})?'),
            ),
          ],
          onChanged: cubit.amountChanged,
          decoration: InputDecoration(
            labelText: 'Monto (USD)',
            prefixText: r'$',
            errorText: state.fieldErrors[TransferField.amount],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.failure case final failure?) ...[
          if (state.connectionRestored)
            const InlineMessage(
              'Conexión recuperada. Toca Reintentar para completar la '
              'transferencia; no se duplicará.',
              tone: InlineMessageTone.info,
            )
          else
            InlineMessage(
              '${failure.message} Puedes reintentar con seguridad: '
              'la transferencia no se duplicará.',
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        FilledButton(
          onPressed: submitting ? null : cubit.submit,
          child: submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Transfiriendo',
                  ),
                )
              : Text(
                  state.status == TransferStatus.failure
                      ? 'Reintentar'
                      : 'Transferir ${Formatters.money(state.amountMinor)}',
                ),
        ),
      ],
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.state});

  final TransferState state;

  @override
  Widget build(BuildContext context) {
    final receipt = state.receipt!;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 72, color: AppColors.success),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              'Transferiste ${Formatters.money(receipt.amountMinor)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Referencia ${receipt.transferId.substring(0, 8).toUpperCase()}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
