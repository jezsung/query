class Pagination {
  final int number;
  final int size;

  const Pagination({required this.number, required this.size});

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        number: json['number'] as int,
        size: json['size'] as int,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'size': size,
      };
}
