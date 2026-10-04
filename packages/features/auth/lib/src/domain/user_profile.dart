import 'package:equatable/equatable.dart';

/// Objetivo financiero declarado en el onboarding. Define el segmento inicial
/// del cliente y, con él, la personalización de su experiencia.
enum FinancialGoal {
  save('save', 'Ahorrar para una meta', 'Separa tu dinero y mira cómo crece.'),
  invest('invest', 'Invertir mi dinero', 'Pon a rendir tus ahorros.'),
  growBusiness(
    'grow_business',
    'Hacer crecer mi negocio',
    'Controla las ventas y pagos de tu emprendimiento.',
  );

  const FinancialGoal(this.apiValue, this.title, this.description);

  /// Valor que espera el BFF.
  final String apiValue;
  final String title;
  final String description;

  static FinancialGoal fromApi(String value) =>
      values.firstWhere((goal) => goal.apiValue == value);
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.goal,
    required this.segment,
  });

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    id: json['id']! as String,
    email: json['email']! as String,
    fullName: json['fullName']! as String,
    goal: FinancialGoal.fromApi(json['goal']! as String),
    segment: json['segment']! as String,
  );

  final String id;
  final String email;
  final String fullName;
  final FinancialGoal goal;

  /// Segmento calculado por el BFF (`saver`, `investor`, `entrepreneur`).
  final String segment;

  String get firstName => fullName.split(' ').first;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'goal': goal.apiValue,
    'segment': segment,
  };

  @override
  List<Object?> get props => [id, email, fullName, goal, segment];
}
