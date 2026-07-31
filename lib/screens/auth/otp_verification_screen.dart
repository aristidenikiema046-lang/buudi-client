import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  Timer? _timer;
  int _start = 45; // Compte à rebours de 45 secondes comme sur ta maquette

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _start = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Permet de reconstruire le code à 6 chiffres à partir des 6 cases
  String _getOtpCode() {
    return _controllers.map((controller) => controller.text).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpVerifiedState) {
            // OTP validé ! On passe à l'étape suivante (Sécurité / Création de mot de passe)
            // ex: Navigator.pushNamed(context, '/security_register', arguments: state.firebaseToken);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Numéro vérifié avec succès !"), backgroundColor: Colors.green),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "Vérification du téléphone",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Nous avons envoyé un code de vérification à ${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 40),
                
                // Grille de saisie du code OTP (6 cases)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          
                          // Si toutes les cases sont remplies, on peut déclencher automatiquement la validation
                          if (_getOtpCode().length == 6) {
                            context.read<AuthBloc>().add(VerifyOtpEvent(smsCode: _getOtpCode()));
                          }
                        },
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 30),
                
                // Compte à rebours de renvoi
                _start > 0
                    ? Text(
                        "Renvoyer le code dans 00:${_start.toString().padLeft(2, '0')}",
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      )
                    : TextButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(SendOtpEvent(phoneNumber: widget.phoneNumber));
                          _startTimer();
                        },
                        child: const Text(
                          "Renvoyer le code",
                          style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                        ),
                      ),
                
                const Spacer(),
                
                // Bouton de validation manuel
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: state is AuthLoading
                        ? null
                        : () {
                            String code = _getOtpCode();
                            if (code.length == 6) {
                              context.read<AuthBloc>().add(VerifyOtpEvent(smsCode: code));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Veuillez entrer le code complet à 6 chiffres.")),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: state is AuthLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Continuer", style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}