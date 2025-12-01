class CheckForm {
  final int id;
  final bool check;

  const CheckForm({required this.id, required this.check});

  factory CheckForm.fromJson(Map<String, dynamic> json) => CheckForm(
        id: json['id'] as int,
        check: json['check'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'check': check,
      };
}
