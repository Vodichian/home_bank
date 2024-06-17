class User {
  String fullName;
  String userId;
  String? nickname; // Optional nickname
  String? imagePath; // Path to the user's image

  User({
    required this.fullName,required this.userId,
    this.nickname,
    this.imagePath,
  });
}