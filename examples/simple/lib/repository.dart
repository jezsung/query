class Repository {
  const Repository({
    required this.name,
    required this.description,
    required this.watcherCount,
    required this.starCount,
    required this.forkCount,
  });

  final String name;
  final String description;
  final int watcherCount;
  final int starCount;
  final int forkCount;

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      name: json['name'],
      description: json['description'],
      watcherCount: json['subscribers_count'],
      starCount: json['stargazers_count'],
      forkCount: json['forks_count'],
    );
  }
}
