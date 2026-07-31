import 'package:flutter/material.dart';

class DeliveryRegisterScreen extends StatefulWidget {
  const DeliveryRegisterScreen({Key? key}) : super(key: key);

  @override
  State<DeliveryRegisterScreen> createState() => _DeliveryRegisterScreenState();
}

class _DeliveryRegisterScreenState extends State<DeliveryRegisterScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final List<String> _steps = ["Informations", "Véhicule", "Documents", "Confirmation"];

  // Form states
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  String _selectedVehicle = "Moto"; // Par défaut comme sur la maquette
  final TextEditingController _vehicleModel = TextEditingController();

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: _previousStep,
        ),
        title: const Text(
          "Inscription - Livreur",
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
                  _buildStep1Infos(),
                  _buildStep2Vehicule(),
                  _buildStep3Docs(),
                  _buildStep4Confirmation(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: List.generate(_steps.length, (index) {
          bool isCompleted = index < _currentStep;
          bool isActive = index == _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted ? const Color(0xFFFF5722) : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.check : null,
                      size: 14, color: Colors.white,
                    ),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(height: 2, color: isCompleted ? const Color(0xFFFF5722) : Colors.grey[200]),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- ÉTAPE 1 : INFOS ---
  Widget _buildStep1Infos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50, backgroundColor: const Color(0xFFFFF6F1),
              child: Icon(Icons.delivery_dining_rounded, size: 50, color: const Color(0xFFFF5722)),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Informations personnelles", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildTextField("Nom complet", "Kouassi Ibrahim", Icons.person_outline_rounded, _nameController),
          const SizedBox(height: 12),
          _buildTextField("Numéro de téléphone", "+225 07 12 34 56 78", Icons.phone_android_rounded, _phoneController),
          const SizedBox(height: 12),
          _buildTextField("Email", "ibrahim.kouassi@gmail.com", Icons.mail_outline_rounded, _emailController),
          const SizedBox(height: 12),
          _buildTextField("Ville de résidence", "Abidjan, Côte d'Ivoire", Icons.location_on_outlined, TextEditingController()),
          const SizedBox(height: 40),
          _buildButton("Continuer", _nextStep),
        ],
      ),
    );
  }

  // --- ÉTAPE 2 : MOYEN DE LIVRAISON ---
  Widget _buildStep2Vehicule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Informations du véhicule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Ajoutez les informations de votre moyen de livraison.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          const Text("Type de moyen", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildVehicleSelector("Moto", Icons.two_wheeler_rounded),
              const SizedBox(width: 12),
              _buildVehicleSelector("Vélo", Icons.pedal_bike_rounded),
              const SizedBox(width: 12),
              _buildVehicleSelector("Voiture", Icons.directions_car_rounded),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField("Marque / Modèle", "Yamaha XMAX 300", Icons.branding_watermark_outlined, _vehicleModel),
          const SizedBox(height: 12),
          _buildTextField("Année", "2022", Icons.calendar_today_rounded, TextEditingController()),
          const SizedBox(height: 12),
          _buildTextField("Couleur", "Noir", Icons.color_lens_outlined, TextEditingController()),
          const SizedBox(height: 12),
          _buildTextField("Numéro d'immatriculation", "1234AB01", Icons.subtitles_rounded, TextEditingController()),
          const SizedBox(height: 30),
          _buildButton("Continuer", _nextStep),
        ],
      ),
    );
  }

  // --- ÉTAPE 3 : DOCUMENTS ---
  Widget _buildStep3Docs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Documents requis", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Téléversez des photos claires et valides.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          _buildDocRow("Pièce d'identité", true),
          _buildDocRow("Permis de conduire", true),
          _buildDocRow("Carte grise / Immatriculation", true),
          _buildDocRow("Assurance du véhicule", false),
          const Spacer(),
          _buildButton("Continuer", _nextStep),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- ÉTAPE 4 : CONFIRMATION ---
  Widget _buildStep4Confirmation() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.check_circle_rounded, size: 90, color: Color(0xFF4CAF50)),
          const SizedBox(height: 20),
          const Text("Inscription terminée !", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Votre compte livreur a été soumis avec succès.\nNous vérifions vos informations sous peu.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          _buildButton("Retour à l'accueil", () {
            Navigator.popUntil(context, (route) => route.isFirst);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey, size: 18),
            filled: true, fillColor: const Color(0xFFF7F7F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelector(String type, IconData icon) {
    bool isSelected = _selectedVehicle == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedVehicle = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF6F1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFF2F2F5), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF5722) : Colors.black54, size: 28),
              const SizedBox(height: 8),
              Text(type, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocRow(String name, bool isUploaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF2F2F5))),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          isUploaded
              ? Row(children: const [Icon(Icons.check_circle, color: Colors.green, size: 16), SizedBox(width: 4), Text("Téléversé", style: TextStyle(color: Colors.green, fontSize: 12))])
              : ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722), minimumSize: const Size(80, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0), child: const Text("Téléverser", style: TextStyle(color: Colors.white, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }
}