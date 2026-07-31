import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({Key? key}) : super(key: key);

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<String> _steps = ["Informations", "Vérification", "Sécurité", "Confirmation"];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _countryCode = "+225"; 

  final List<String> _africanCities = [
    "Abidjan, Côte d'Ivoire",
    "Yamoussoukro, Côte d'Ivoire",
    "Bouaké, Côte d'Ivoire",
    "San-Pédro, Côte d'Ivoire",
    "Korhogo, Côte d'Ivoire",
    "Man, Côte d'Ivoire",
    "Daloa, Côte d'Ivoire",
    "Ouagadougou, Burkina Faso",
    "Bobo-Dioulasso, Burkina Faso",
    "Bamako, Mali",
    "Lomé, Togo",
    "Cotonou, Bénin",
    "Dakar, Sénégal",
    "Niamey, Niger",
    "Conakry, Guinée",
  ];
  List<String> _filteredCities = [];
  final FocusNode _cityFocusNode = FocusNode();

  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _gender = "Homme";

  @override
  void initState() {
    super.initState();
    _cityController.addListener(_onCityChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _birthController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityFocusNode.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCityChanged() {
    final query = _cityController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filteredCities = []);
    } else {
      setState(() {
        _filteredCities = _africanCities
            .where((city) => city.toLowerCase().contains(query))
            .toList();
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF5722),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5722)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _startEmailVerification() {
    final email = _emailController.text.trim();
    
    if (_nameController.text.trim().isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir au moins le nom et l'adresse email")),
      );
      return;
    }

    context.read<AuthBloc>().add(SendOtpEvent(phoneNumber: email));
  }

  void _verifyOtp() {
    final smsCode = _otpControllers.map((c) => c.text.trim()).join();
    if (smsCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir les 6 chiffres du code reçu")),
      );
      return;
    }

    context.read<AuthBloc>().add(VerifyOtpEvent(smsCode: smsCode));
  }

  void _submitRegistration() {
    if (_passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le mot de passe doit contenir au moins 4 caractères")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }

    final localPhone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    final fullPhone = localPhone.isNotEmpty ? '$_countryCode$localPhone' : '';
    final smsCode = _otpControllers.map((c) => c.text.trim()).join();

    final userModel = UserModel(
      uid: '', 
      name: _nameController.text.trim(),
      phone: fullPhone,
      email: _emailController.text.trim(),
      role: 'Client',
      createdAt: DateTime.now(), 
      city: _cityController.text.trim(),
      birthDate: _birthController.text.trim(),
      gender: _gender,
    );

    context.read<AuthBloc>().add(
      SignUpRequested(
        user: userModel, 
        password: _passwordController.text,
        otpCode: smsCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
          );
        } else if (state is OtpSentState) {
          _nextStep();
        } else if (state is OtpVerifiedState) {
          _nextStep();
        } else if (state is Authenticated) {
          _nextStep();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
              onPressed: state is AuthLoading ? null : _previousStep,
            ),
            title: const Text(
              "Inscription - Client",
              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildStepper(),
                const SizedBox(height: 20),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1Informations(state),
                      _buildStep2Verification(state),
                      _buildStep3Securite(state),
                      _buildStep4Confirmation(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length, (index) {
              bool isCompleted = index < _currentStep;
              bool isActive = index == _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isActive || isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: isActive || isCompleted ? Colors.white : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (index < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (index) {
              bool isActive = index == _currentStep;
              return Expanded(
                child: Text(
                  _steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? const Color(0xFFFF5722) : Colors.grey[400],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Informations(AuthState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Informations personnelles", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildTextField("Nom complet", "Koffi Jean", Icons.person_outline_rounded, _nameController, enabled: state is! AuthLoading),
          const SizedBox(height: 12),
          _buildTextField("Email", "jeankoffi@gmail.com", Icons.mail_outline_rounded, _emailController, keyboardType: TextInputType.emailAddress, enabled: state is! AuthLoading),
          const SizedBox(height: 12),

          const Text("Numéro de téléphone (Optionnel)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 6),
          IntlPhoneField(
            controller: _phoneController,
            enabled: state is! AuthLoading,
            initialCountryCode: 'CI',
            autovalidateMode: AutovalidateMode.disabled,
            disableLengthCheck: true,
            decoration: InputDecoration(
              hintText: "0712345678",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: state is! AuthLoading ? const Color(0xFFF7F7F9) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            languageCode: "fr",
            validator: (phone) {
              if (_phoneController.text.trim().isEmpty) return null;
              if (phone == null || phone.completeNumber.length < 8) return "Numéro invalide";
              return null;
            },
            onChanged: (phone) {
              _countryCode = phone.countryCode;
            },
            onCountryChanged: (country) {
              _countryCode = "+${country.dialCode}";
            },
          ),
          const SizedBox(height: 12),
          
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    "Ville de résidence", "Abidjan, Côte d'Ivoire", Icons.location_on_outlined, _cityController, 
                    focusNode: _cityFocusNode, enabled: state is! AuthLoading
                  ),
                ],
              ),
              if (_filteredCities.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 72),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCities.length,
                    itemBuilder: (context, index) {
                      final city = _filteredCities[index];
                      return ListTile(
                        dense: true,
                        title: Text(city, style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          setState(() {
                            _cityController.text = city;
                            _filteredCities.clear();
                          });
                          _cityFocusNode.unfocus();
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text("Informations complémentaires", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Date de naissance", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 6),
              InkWell(
                onTap: state is AuthLoading ? null : _selectBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextField(
                    controller: _birthController,
                    decoration: InputDecoration(
                      hintText: "1995-05-12",
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: Icon(Icons.calendar_month_outlined, color: Colors.grey[400], size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          const Text("Genre", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Radio<String>(
                value: "Homme",
                groupValue: _gender,
                activeColor: const Color(0xFFFF5722),
                onChanged: state is AuthLoading ? null : (value) => setState(() => _gender = value!),
              ),
              const Text("Homme"),
              const SizedBox(width: 20),
              Radio<String>(
                value: "Femme",
                groupValue: _gender,
                activeColor: const Color(0xFFFF5722),
                onChanged: state is AuthLoading ? null : (value) => setState(() => _gender = value!),
              ),
              const Text("Femme"),
            ],
          ),
          const SizedBox(height: 30),
          _buildButton("Continuer", _startEmailVerification, isLoading: state is AuthLoading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep2Verification(AuthState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_unread_rounded, size: 80, color: Colors.black87),
          const SizedBox(height: 20),
          const Text("Vérification de l'email", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Nous avons envoyé un code de vérification à l'adresse\n${_emailController.text}",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => SizedBox(
              width: 45,
              height: 52,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5)),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
                  } else if (value.isEmpty && index > 0) {
                    FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
                  }
                },
              ),
            )),
          ),
          const SizedBox(height: 30),
          _buildButton("Vérifier", _verifyOtp, isLoading: state is AuthLoading),
        ],
      ),
    );
  }

  Widget _buildStep3Securite(AuthState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("Sécurité du compte", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Définissez un mot de passe sécurisé pour votre compte.", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 25),
          _buildTextField("Mot de passe", "••••••••", Icons.lock_outline_rounded, _passwordController, obscureText: true, enabled: state is! AuthLoading),
          const SizedBox(height: 15),
          _buildTextField("Confirmer le mot de passe", "••••••••", Icons.lock_outline_rounded, _confirmPasswordController, obscureText: true, enabled: state is! AuthLoading),
          const Spacer(),
          _buildButton("Terminer l'inscription", _submitRegistration, isLoading: state is AuthLoading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep4Confirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 80, color: Color(0xFFFF5722)),
          const SizedBox(height: 15),
          const Text("Inscription réussie !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Votre compte a été créé avec succès. Bienvenue sur Buudi.", 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 25),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Récapitulatif de votre compte", 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow("Nom complet", _nameController.text.trim()),
                const SizedBox(height: 8),
                _buildSummaryRow("Téléphone", _phoneController.text.trim().isNotEmpty ? "$_countryCode ${_phoneController.text.trim()}" : "Non renseigné"),
                const SizedBox(height: 8),
                _buildSummaryRow("Email", _emailController.text.trim()),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Type de compte", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Color(0xFFFF5722)),
                        const SizedBox(width: 4),
                        const Text("Client", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          
          _buildButton("Accéder à l'accueil", () {
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/client_home', 
              (route) => false,
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Flexible(
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller, {bool obscureText = false, TextInputType keyboardType = TextInputType.text, FocusNode? focusNode, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 18),
            filled: true,
            fillColor: enabled ? const Color(0xFFF7F7F9) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed, {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5722),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return Colors.grey[300]!;
            }
            return const Color(0xFFFF5722);
          }),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}