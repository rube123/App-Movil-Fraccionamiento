class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  factory UserModel.empty() =>
      UserModel(uid: "", name: "", email: "", photoUrl: "");

  get displayName => null;
}
