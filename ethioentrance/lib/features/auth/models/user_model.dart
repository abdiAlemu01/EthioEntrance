// user_model.dart

import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class UserFirebase {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePictureUrl;
  UserFirebase({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePictureUrl,
  });

  UserFirebase copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? profilePictureUrl,
  }) {
    return UserFirebase(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  factory UserFirebase.fromMap(Map<String, dynamic> map) {
    return UserFirebase(
      id: map['id'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      email: map['email'] as String,
      profilePictureUrl: map['profilePictureUrl'] != null ? map['profilePictureUrl'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserFirebase.fromJson(String source) => UserFirebase.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'UserFirebase(id: $id, firstName: $firstName, lastName: $lastName, email: $email, profilePictureUrl: $profilePictureUrl)';

  @override
  bool operator ==(covariant UserFirebase other) {
    if (identical(this, other)) return true;
  
    return 
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.email == email &&
      other.profilePictureUrl == profilePictureUrl;
  }

  @override
  int get hashCode => firstName.hashCode ^ lastName.hashCode ^ email.hashCode ^ profilePictureUrl.hashCode;
}
