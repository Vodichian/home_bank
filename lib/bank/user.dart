class UserDepr {
  String fullName;
  int userId;
  String? username;
  String? imagePath; // Path to the user's image

  UserDepr({
    required this.fullName,
    required this.userId,
    required this.username,
    this.imagePath,
  });

  @override
  String toString() {
    return username ?? fullName;
  }
}