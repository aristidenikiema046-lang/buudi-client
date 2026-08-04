import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// Événement pour vérifier l'état de connexion de l'utilisateur au démarrage de l'app
class AppStarted extends AuthEvent {}

// Événement déclenché lors d'une inscription (mis à jour avec l'otpCode)
class SignUpRequested extends AuthEvent {
  final UserModel user;
  final String password;
  final String otpCode;       // 👈 Ajout du code OTP requis par le backend Laravel
  final String? fcmToken; 

  const SignUpRequested({
    required this.user,
    required this.password,
    required this.otpCode,    // 👈 Requis dans le constructeur
    this.fcmToken, 
  });

  @override
  List<Object?> get props => [user, password, otpCode, fcmToken];
}

// Événement de connexion
class SignInRequested extends AuthEvent {
  final String phone;
  final String password;
  final String role;
  final String? fcmToken;

  const SignInRequested({
    required this.phone,
    required this.password,
    required this.role,
    this.fcmToken,
  });

  @override
  List<Object?> get props => [phone, password, role, fcmToken];
}

// Événement de déconnexion
class SignOutRequested extends AuthEvent {}

// Événement pour demander l'envoi du SMS OTP
class SendOtpEvent extends AuthEvent {
  final String phoneNumber;

  const SendOtpEvent({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

// Événement pour valider le code OTP saisi
class VerifyOtpEvent extends AuthEvent {
  final String smsCode;

  const VerifyOtpEvent({required this.smsCode});

  @override
  List<Object?> get props => [smsCode];
}

// Événements internes au Bloc pour lier les retours Firebase asynchrones
class OtpSentSuccessEvent extends AuthEvent {}

class VerifyOtpFailedEvent extends AuthEvent {
  final String message;

  const VerifyOtpFailedEvent({required this.message});

  @override
  List<Object?> get props => [message];
}