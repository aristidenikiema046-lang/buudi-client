import 'dart:io';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 Import de flutter_dotenv



// --- IMPORT DU SERVICE FCM ---

import 'services/fcm_service.dart';



// --- IMPORTS DES ÉCRANS & BLOCS ---

import 'screens/auth/role_selection_screen.dart';

import 'screens/auth/login_screen.dart';

import 'screens/driver/driver_navigation_shell.dart';

import 'screens/client/client_home_screen.dart';



import 'blocs/auth/auth_bloc.dart';

import 'blocs/auth/auth_event.dart';



/// Contournement SSL pour le développement local (certificats auto-signés & HTTP)

class MyHttpOverrides extends HttpOverrides {

  @override

  HttpClient createHttpClient(SecurityContext? context) {

    return super.createHttpClient(context)

      ..badCertificateCallback =

          (X509Certificate cert, String host, int port) => true;

  }

}



// Clé globale pour la navigation via notifications FCM

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();



void main() async {

  WidgetsFlutterBinding.ensureInitialized();



  // 1. Chargement du fichier .env avant d'initialiser l'application

  await dotenv.load(fileName: ".env");



  // Active le contournement SSL avant tout appel réseau

  HttpOverrides.global = MyHttpOverrides();



  // Capture globale des erreurs Flutter pour le débogage

  FlutterError.onError = (FlutterErrorDetails details) {

    FlutterError.presentError(details);

    debugPrint('==================================================');

    debugPrint('⚠️ ERREUR DETECTEE PAR FLUTTER: ${details.exception}');

    debugPrint('📍 SOURCE EXACTE (STACK TRACE):\n${details.stack}');

    debugPrint('==================================================');

  };



  // Démarre Firebase

  await Firebase.initializeApp();



  // Initialise FCM

  await FcmService.init(navigatorKey);



  runApp(const BuudiApp());

}



class BuudiApp extends StatelessWidget {

  const BuudiApp({Key? key}) : super(key: key);



  @override

  Widget build(BuildContext context) {

    return BlocProvider<AuthBloc>(

      create: (context) => AuthBloc()..add(AppStarted()),

      child: MaterialApp(

        title: 'Buudi Africa',

        navigatorKey: navigatorKey,

        debugShowCheckedModeBanner: false,

        theme: ThemeData(

          primaryColor: const Color(0xFFFF5722),

          scaffoldBackgroundColor: Colors.white,

          fontFamily: 'Roboto',

        ),



        // Écran initial

        home: const RoleSelectionScreen(),



        // Table de routage

        routes: {

          '/role_selection': (context) => const RoleSelectionScreen(),

          '/login': (context) => const LoginScreen(),



          // ROUTE DU CHAUFFEUR

          '/driver_home': (context) => const DriverNavigationShell(),



          '/driver_waiting': (context) => const Scaffold(

                body: Center(

                    child: Text("Compte Chauffeur en attente de validation")),

              ),



          // ROUTE DU CLIENT (Écran principal style Yango)

          '/client_home': (context) => const ClientHomeScreen(),



          '/delivery_home': (context) => const Scaffold(

                body: Center(child: Text("Accueil Livreur")),

              ),

        },

      ),

    );

  }

} 

