// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// define model for user profile with fields like first name, last name, email, etc.
class ProfileModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String? profilePictureUrl;

  ProfileModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.profilePictureUrl,
  });





  ProfileModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? profilePictureUrl,
  }) {
    return ProfileModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      uid: (map['uid'] ?? '').toString(),
      firstName: (map['firstName'] ?? '').toString(),
      lastName: (map['lastName'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      profilePictureUrl: map['profilePictureUrl']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ProfileModel.fromJson(String source) => ProfileModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ProfileModel(uid: $uid, firstName: $firstName, lastName: $lastName, email: $email, profilePictureUrl: $profilePictureUrl)';
  }

  @override
  bool operator ==(covariant ProfileModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.uid == uid &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.email == email &&
      other.profilePictureUrl == profilePictureUrl;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        email.hashCode ^
        profilePictureUrl.hashCode;
  }
}
