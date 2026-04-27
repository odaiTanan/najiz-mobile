class UserProfileModel {
  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? avatarPath;

  const UserProfileModel({
    this.name,
    this.email,
    this.phone,
    this.address,
    this.avatarPath,
  });

  factory UserProfileModel.fromBackend(
    Map<String, dynamic>? json, {
    Map<String, String?>? fallback,
  }) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = json?[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return null;
    }

    return UserProfileModel(
      name: pick(['name', 'full_name', 'username']) ?? fallback?['name'],
      email: pick(['email']) ?? fallback?['email'],
      phone: pick(['phone', 'mobile']) ?? fallback?['phone'],
      address: pick(['address', 'full_address']) ?? fallback?['address'],
      avatarPath:
          pick(['avatar', 'avatar_url', 'profile_image']) ?? fallback?['avatarPath'],
    );
  }
}
