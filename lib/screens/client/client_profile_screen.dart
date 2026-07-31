import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';
import '../../services/profile_service.dart';

/// Onglet "Profil". Les données affichées viennent de l'utilisateur déjà
/// authentifié en mémoire (réponse de connexion/inscription) : il n'existe
/// pas de GET /v1/client/profile côté Laravel pour les re-récupérer à jour.
/// Le formulaire "Modifier" est prêt, mais l'enregistrement dépend de
/// PUT /v1/client/profile qui n'existe pas non plus (voir profile_service.dart).
class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({Key? key}) : super(key: key);

  static const _orange = Color(0xFFFF5722);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user as UserModel? : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text("Profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil('/role_selection', (route) => false);
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeaderCard(user),
            const SizedBox(height: 16),
            _buildInfoCard(context, user),
            const SizedBox(height: 24),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFFFF0EE),
            child: Icon(Icons.person, color: _orange, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.isNotEmpty == true ? user!.name : "Utilisateur",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  "Membre depuis ${_formatMonthYear(user?.createdAt)}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.person_outline_rounded, "Nom complet", user?.name),
          const Divider(height: 1, indent: 60),
          _buildInfoRow(Icons.mail_outline_rounded, "Email", user?.email),
          const Divider(height: 1, indent: 60),
          _buildInfoRow(Icons.phone_outlined, "Téléphone", user?.phone),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: _EditProfileButton(user: user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    final displayValue = (value == null || value.isEmpty) ? "Non renseigné" : value;
    return ListTile(
      leading: Icon(icon, color: Colors.grey[500], size: 20),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(
        displayValue,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: displayValue == "Non renseigné" ? Colors.grey[400] : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
      label: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatMonthYear(DateTime? date) {
    if (date == null) return "récemment";
    const mois = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return "${mois[date.month - 1]} ${date.year}";
  }
}

class _EditProfileButton extends StatelessWidget {
  final UserModel? user;

  const _EditProfileButton({required this.user});

  static const _orange = Color(0xFFFF5722);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openEditSheet(context),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text("Modifier"),
      style: ElevatedButton.styleFrom(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    bool submitting = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Modifier mon profil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildField("Nom complet", nameController, enabled: !submitting),
                  const SizedBox(height: 12),
                  _buildField("Email", emailController, enabled: !submitting, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildField("Téléphone", phoneController, enabled: !submitting, keyboardType: TextInputType.phone),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) {
                              setSheetState(() => errorText = "Le nom ne peut pas être vide.");
                              return;
                            }
                            setSheetState(() {
                              submitting = true;
                              errorText = null;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('jwt_token') ?? '';
                            final result = await ProfileService.updateProfile(
                              token,
                              name: nameController.text.trim(),
                              email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                              phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            );

                            if (result['code'] == 'ENDPOINT_MISSING') {
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text("Endpoint manquant"),
                                    content: Text(result['message']?.toString() ?? ''),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Compris")),
                                    ],
                                  ),
                                );
                              }
                              return;
                            }

                            if (result['success'] == true) {
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Profil mis à jour.")),
                                );
                              }
                            } else {
                              setSheetState(() {
                                submitting = false;
                                errorText = result['message']?.toString() ?? 'Une erreur est survenue.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text("Enregistrer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool enabled = true, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
