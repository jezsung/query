class Repository {
  const Repository({
    required this.name,
    required this.description,
    required this.watcherCount,
    required this.forkCount,
    required this.starCount,
  });

  final String name;
  final String description;
  final int watcherCount;
  final int forkCount;
  final int starCount;

  factory Repository.fromJson(Map<String, dynamic> json) {
    return Repository(
      name: json['name'],
      description: json['description'],
      watcherCount: json['subscribers_count'],
      forkCount: json['forks_count'],
      starCount: json['stargazers_count'],
    );
  }
}
