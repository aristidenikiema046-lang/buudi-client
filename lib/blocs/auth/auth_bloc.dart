import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://buudi.net/api';

  AuthBloc() : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SendOtpEvent>(_onSendEmailVerification); 
    on<VerifyOtpEvent>(_onVerifyOtpCode);       
    on<SignUpRequested>(_onSignUpRequested);
    on<SignInRequested>(_onSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<OtpSentSuccessEvent>((event, emit) => emit(OtpSentState()));
    on<VerifyOtpFailedEvent>(
        (event, emit) => emit(AuthError(message: event.message)));
  }

  // Restaure la session à partir du token stocké, s'il existe et est encore
  // valide (vérifié via GET /v1/client/profile). Sans ça, un utilisateur déjà
  // connecté retomberait toujours sur l'écran de bienvenue au relancement.
  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      emit(Unauthenticated());
      return;
    }

    final result = await ProfileService.getProfile(token);
    if (result['success'] == true) {
      emit(Authenticated(user: UserModel.fromJson(result['user'])));
    } else {
      await prefs.remove('jwt_token');
      emit(Unauthenticated());
    }
  }

  // --- ENVOI DE L'E-MAIL DE VÉRIFICATION / OTP ---
  Future<void> _onSendEmailVerification(SendOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final email = event.phoneNumber; 

      final response = await http.post(
        Uri.parse("$_baseUrl/client/send-email-otp"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({'email': email}),
      );

      // --- DEBUG : Afficher la réponse brute dans la console VS Code ---
      print('--- DEBUG LARAVEL RESPONSE (send-email-otp) ---');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('---------------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 201) {
        emit(OtpSentState());
      } else {
        final errorData = jsonDecode(response.body);
        
        // --- DEBUG : Afficher les erreurs détaillées de validation ---
        print('Validation Errors: ${errorData['errors'] ?? errorData['message']}');

        emit(AuthError(message: errorData['message'] ?? "Impossible d'envoyer l'e-mail de vérification."));
      }
    } catch (e) {
      print('Exception réseau send-email-otp : ${e.toString()}');
      emit(AuthError(message: "Erreur réseau lors de l'envoi de l'e-mail : ${e.toString()}"));
    }
  }

  // --- VÉRIFICATION DU CODE OTP REÇU PAR EMAIL ---
  Future<void> _onVerifyOtpCode(VerifyOtpEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      emit(OtpVerifiedState());
    } catch (e) {
      emit(const AuthError(message: "Code de vérification incorrect ou expiré."));
    }
  }

  // --- INSCRIPTION CLIENT SUR LARAVEL ---
  Future<void> _onSignUpRequested(
      SignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final Map<String, dynamic> registerData = {
        'name': event.user.name,
        'phone': event.user.phone, 
        'email': event.user.email,
        'city': event.user.city,
        'birth_date': event.user.birthDate,
        'gender': event.user.gender,
        'password': event.password,
        'otp_code': event.otpCode, 
        if (event.fcmToken != null) 'fcm_token': event.fcmToken,
      };

      final response = await http.post(
        Uri.parse("$_baseUrl/client/verify-register"),
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode(registerData),
      );

      print('--- DEBUG LARAVEL RESPONSE (verify-register) ---');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('----------------------------------------------');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final String jwtToken =
            responseData['access_token'] ?? responseData['token'] ?? "";
        if (jwtToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', jwtToken);
        }

        final userJson = responseData['user'] ?? responseData;
        final newUser = UserModel.fromJson(userJson);

        emit(Authenticated(user: newUser));
      } else {
        try {
          final errorData = jsonDecode(response.body);
          String detailedError = "";

          if (errorData['errors'] != null && errorData['errors'] is Map) {
            final Map<String, dynamic> validationErrors = errorData['errors'];
            List<String> errorsList = [];

            validationErrors.forEach((key, value) {
              if (value is List) {
                errorsList.add("${key.toUpperCase()} : ${value.join(', ')}");
              } else {
                errorsList.add("${key.toUpperCase()} : $value");
              }
            });

            detailedError = errorsList.join('\n');
          } else {
            detailedError = errorData['message'] ?? "Erreur lors de l'enregistrement sur le serveur.";
          }

          print('Detailed Validation Error: $detailedError');
          emit(AuthError(message: detailedError));
        } catch (_) {
          print('Raw Server Error: ${response.body}');
          emit(AuthError(message: "Erreur serveur (${response.statusCode}) : ${response.body}"));
        }
      }
    } catch (e) {
      print('Exception réseau verify-register : ${e.toString()}');
      emit(AuthError(message: "Erreur de connexion avec le serveur : ${e.toString()}"));
    }
  }

  // --- LOGIQUE DE CONNEXION (EMAIL OU TÉLÉPHONE) ---
  Future<void> _onSignInRequested(
      SignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final Map<String, dynamic> body = {
        'login': event.phone, 
        'password': event.password,
        if (event.fcmToken != null) 'fcm_token': event.fcmToken,
      };

      final response = await http.post(
        Uri.parse("$_baseUrl/login"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(body),
      );

      print('--- DEBUG LARAVEL RESPONSE (login) ---');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('--------------------------------------');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final String jwtToken =
            responseData['access_token'] ?? responseData['token'] ?? "";
        if (jwtToken.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', jwtToken);
        }

        final userJson = responseData['user'] ?? responseData;
        final loggedUser = UserModel.fromJson(userJson);

        emit(Authenticated(user: loggedUser));
      } else {
        try {
          final errorData = jsonDecode(response.body);
          emit(AuthError(message: errorData['message'] ?? "Identifiants incorrects."));
        } catch (_) {
          emit(AuthError(message: "Échec de l'authentification (${response.statusCode})"));
        }
      }
    } catch (e) {
      emit(AuthError(message: "Impossible de joindre le serveur : ${e.toString()}"));
    }
  }

  Future<void> _onSignOutRequested(
      SignOutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');

    await _firebaseAuth.signOut();
    emit(Unauthenticated());
  }
}