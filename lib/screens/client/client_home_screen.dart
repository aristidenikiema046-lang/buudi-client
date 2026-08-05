import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import '../../services/notification_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/formatters.dart';
import '../common/coming_soon_screen.dart';
import '../common/conversations_list_screen.dart';
import '../common/notifications_screen.dart';
import 'wallet_screen.dart';
import 'transfer_screen.dart';
import 'vtc/ride_request_screen.dart';
import 'client_activity_screen.dart';
import 'client_profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'supermarket/supermarket_list_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({Key? key}) : super(key: key);

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _currentIndex = 0;

  bool _loadingWallet = true;
  WalletBalance? _wallet;
  String? _walletError;

  bool _loadingTransactions = true;
  List<WalletTransactionModel> _recentTransactions = [];
  String? _transactionsError;

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _loadHomeData() async {
    final token = await _getToken();

    setState(() {
      _loadingWallet = true;
      _loadingTransactions = true;
    });

    final walletResult = await WalletService.getWallet(token);
    if (mounted) {
      setState(() {
        _loadingWallet = false;
        if (walletResult['success'] == true) {
          _wallet = walletResult['wallet'] as WalletBalance;
          _walletError = null;
        } else {
          _walletError = walletResult['message'] as String?;
        }
      });
    }

    final txResult = await WalletService.getTransactions(token, page: 1);
    if (mounted) {
      setState(() {
        _loadingTransactions = false;
        if (txResult['success'] == true) {
          final page = txResult['page'] as WalletTransactionsPage;
          _recentTransactions = page.items.take(3).toList();
          _transactionsError = null;
        } else {
          _transactionsError = txResult['message'] as String?;
        }
      });
    }

    await _loadUnreadCount(token: token);
  }

  // Rafraîchit uniquement le compteur (ex: retour de NotificationsScreen),
  // sans recharger le solde/les transactions.
  Future<void> _loadUnreadCount({String? token}) async {
    final jwtToken = token ?? await _getToken();
    final result = await NotificationService.fetchUnreadCount(jwtToken);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _unreadCount = result['count'] as int);
    }
  }

  void _openComingSoon(String title) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComingSoonScreen(title: title)));
  }

  void _showQrDialog(BuildContext context, UserModel? user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Mon QR Code", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: user?.uid.isNotEmpty == true ? user!.uid : 'unknown',
              version: QrVersions.auto,
              size: 200,
            ),
            const SizedBox(height: 12),
            Text(
              user?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user as UserModel? : null;

    final tabs = [
      _buildAccueilTab(context, user),
      const ClientActivityScreen(),
      const SizedBox.shrink(), // "Scanner" : action interceptée dans le onTap, jamais réellement affiché
      const ConversationsListScreen(),
      const ClientProfileScreen(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAccueilTab(BuildContext context, UserModel? user) {
    final firstName = (user?.name ?? '').split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: _buildDrawer(context, user),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHomeData,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                title: Builder(
                  builder: (context) => Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.black, size: 26),
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          _loadUnreadCount();
                        },
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5722),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _unreadCount > 9 ? '9+' : '$_unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        firstName.isNotEmpty ? "Bonjour, $firstName 👋" : "Bonjour 👋",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Où allons-nous aujourd'hui ?",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      _buildWalletCard(),
                      const SizedBox(height: 24),
                      const Text(
                        "Nos services",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      _buildServicesGrid(),
                      const SizedBox(height: 20),
                      _buildReferralBanner(),
                      const SizedBox(height: 24),
                      _buildTransactionsHeader(),
                      const SizedBox(height: 8),
                      _buildTransactionsSection(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, UserModel? user) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFFFF0EE),
                    child: Icon(Icons.person, color: Color(0xFFFF5722)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(user?.email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFFF5722)),
              title: const Text("Mon QR Code"),
              onTap: () {
                Navigator.pop(context);
                _showQrDialog(context, user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFF5722)),
              title: const Text("Portefeuille"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Solde BUUDI PAY",
                style: TextStyle(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              if (_loadingWallet)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5722)),
                )
              else if (_walletError != null)
                Text(
                  "Indisponible",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                )
              else
                Text(
                  formatCfa(_wallet?.balance ?? 0),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                ),
            ],
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen(openDepositOnStart: true)),
                  );
                  _loadHomeData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                child: const Text(
                  "Recharger",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                  _loadHomeData();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[800]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid() {
    final services = [
      {
        'label': 'Courses Taxi',
        'image': 'assets/branding/services/courses_taxi.png',
        'bg': const Color(0xFFFFF3D6),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideRequestScreen())),
      },
      {
        'label': 'Livraison',
        'image': 'assets/branding/services/livraison.png',
        'bg': const Color(0xFFFFE3DB),
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RideRequestScreen(initialServiceType: 'delivery')),
            ),
      },
      {
        'label': 'Supermarché',
        'image': 'assets/branding/services/supermarche.png',
        'bg': const Color(0xFFE3F5E1),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupermarketListScreen())),
      },
      {
        'label': 'Buudi',
        'image': 'assets/branding/services/wallet.png',
        'bg': const Color(0xFFE9E9EC),
        'onTap': () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
          _loadHomeData();
        },
      },
      {
        'label': "Transfert inter-réseaux",
        'image': 'assets/branding/services/envoyer_argent.png',
        'bg': const Color(0xFFE3ECFB),
        'onTap': () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()));
          _loadHomeData();
        },
      },
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: services.map((service) {
        return GestureDetector(
          onTap: service['onTap'] as VoidCallback,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: service['bg'] as Color,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(13),
                child: Image.asset(service['image'] as String, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Text(
                service['label'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReferralBanner() {
    return GestureDetector(
      onTap: () => _openComingSoon('Parrainage'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5722),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Parrainez et gagnez !",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Gagnez jusqu'à 10 000 FCFA à chaque parrainage",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Parrainer",
                style: TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Transactions récentes",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        TextButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
            _loadHomeData();
          },
          child: const Text("Voir tout", style: TextStyle(color: Color(0xFFFF5722), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection() {
    if (_loadingTransactions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
      );
    }
    if (_transactionsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_transactionsError!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      );
    }
    if (_recentTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text("Aucune transaction pour le moment.", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: _recentTransactions.asMap().entries.map((entry) {
          final index = entry.key;
          final tx = entry.value;
          return Column(
            children: [
              _buildTransactionTile(tx),
              if (index != _recentTransactions.length - 1) const Divider(height: 1, indent: 60),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel tx) {
    final isCredit = tx.isCredit;
    final amountColor = isCredit ? const Color(0xFF2E7D32) : Colors.black87;
    final amountSign = isCredit ? '+' : '-';
    final statusColor = tx.status == 'completed' ? const Color(0xFF2E7D32) : Colors.orange;
    final statusLabel = tx.status == 'completed' ? 'Terminé' : 'En attente';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_iconForCategory(tx.category), color: Colors.black54, size: 20),
      ),
      title: Text(
        _labelForCategory(tx.category),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
      ),
      subtitle: Text(
        formatShortDate(tx.createdAt),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "$amountSign${formatCfa(tx.amount)}",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: amountColor),
          ),
          const SizedBox(height: 2),
          Text(
            statusLabel,
            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  IconData _iconForCategory(String category) {
    if (category == 'deposit') return Icons.add_circle_outline_rounded;
    if (category == 'withdrawal') return Icons.remove_circle_outline_rounded;
    if (category.startsWith('transfer_')) return Icons.send_rounded;
    if (category.contains('ride') || category.contains('taxi')) return Icons.local_taxi_rounded;
    return Icons.receipt_long_rounded;
  }

  String _labelForCategory(String category) {
    switch (category) {
      case 'deposit':
        return 'Dépôt';
      case 'withdrawal':
        return 'Retrait';
      default:
        if (category.startsWith('transfer_')) {
          final operator = category.replaceFirst('transfer_', '');
          return 'Transfert ${operator.toUpperCase()}';
        }
        return category.isNotEmpty ? category : 'Transaction';
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen()));
            return;
          }
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFF5722),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Accueil"),
          const BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: "Activité"),
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFF5722), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
            ),
            label: "Scanner",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: "Messages"),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Profil"),
        ],
      ),
    );
  }
}
