import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class Authenticated extends AuthState {
  final dynamic user; 
  const Authenticated({required this.user});
  
  @override
  List<Object?> get props => [user];
}
class Unauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
  
  @override
  List<Object?> get props => [message];
}

// État quand le SMS a été envoyé avec succès par Firebase
class OtpSentState extends AuthState {}

// État quand le code OTP est validé avec succès
class OtpVerifiedState extends AuthState {}