class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final DateTime? joinedAt;

  /// Public customer id, e.g. GMX100534.
  String get customerId => 'GMX${100000 + id.hashCode.abs() % 900000}';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'joinedAt': joinedAt?.toIso8601String(),
  };
}
