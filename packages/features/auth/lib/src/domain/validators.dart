/// Validaciones de formulario. Replican las reglas del BFF para dar feedback
/// inmediato, pero el BFF sigue siendo la fuente de verdad: si sus reglas
/// cambian, sus errores 400 se muestran igual en el campo correspondiente.
///
/// Cada función devuelve `null` si el valor es válido, o el mensaje de error.
abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? fullName(String value) => value.trim().length < 3
      ? 'Ingresa tu nombre completo (mínimo 3 letras).'
      : null;

  static String? email(String value) => _email.hasMatch(value.trim())
      ? null
      : 'Ingresa un correo válido, por ejemplo nombre@correo.com.';

  static String? password(String value) {
    if (value.length < 8) return 'Usa al menos 8 caracteres.';
    if (!value.contains(RegExp('[A-Za-z]'))) return 'Incluye al menos una letra.';
    if (!value.contains(RegExp(r'\d'))) return 'Incluye al menos un número.';
    return null;
  }

  /// Para el login solo se exige que no esté vacía: las reglas de formato
  /// aplican al crearla, y revelarlas aquí no aporta.
  static String? requiredField(String value) =>
      value.isEmpty ? 'Este campo es obligatorio.' : null;
}
