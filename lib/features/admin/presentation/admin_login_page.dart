import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import 'admin_providers.dart';
import 'admin_upload_page.dart';

/// Racine du panneau d'administration : thème de marque et écran d'entrée.
///
/// Le panneau est sombre, comme l'application artiste, mais reste un binaire
/// séparé (`lib/main_admin.dart`) : les écrans d'administration ne sont jamais
/// distribués dans les builds Google Play.
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVAA — Administration',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('fr'),
      supportedLocales: const <Locale>[Locale('fr')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AdminLoginPage(),
    );
  }
}

/// Connexion e-mail / mot de passe, réservée aux administrateurs.
///
/// L'écran observe [adminSessionProvider] : dès qu'une session administrateur
/// existe (connexion réussie, ou onglet déjà authentifié rechargé), il est
/// remplacé par [AdminUploadPage]. Les échecs (identifiants refusés, compte
/// sans droits d'administration) sont affichés sous le formulaire.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _submitting = false;
  bool _navigated = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Valide le formulaire puis délègue la connexion au service admin.
  ///
  /// Les `AdminException` portent un message prêt à afficher ; toute autre
  /// erreur (Firebase absent, réseau) est résumée sans exposer de détail.
  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate() || _submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(adminAuthServiceProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      // En cas de succès, la redirection est portée par le flux de session.
    } on AdminException catch (error) {
      setState(() => _errorMessage = error.message);
    } on Object {
      setState(() {
        _errorMessage =
            'Connexion impossible : le service d\'authentification est '
            'injoignable.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }



  /// Redirige vers l'upload dès qu'une session administrateur est active.
  ///
  /// L'écoute est faite dans `build` (contrat Riverpod), avec un garde-fou
  /// `_navigated` pour n'ouvrir qu'une seule fois l'écran d'upload.
  void _handleSession() {
    ref.listen<AsyncValue<User?>>(adminSessionProvider, (
      AsyncValue<User?>? previous,
      AsyncValue<User?> next,
    ) {
      final User? user = next.value;
      if (user != null && !_navigated && mounted) {
        _navigated = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AdminUploadPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _handleSession();
    final ThemeData theme = Theme.of(context);
    final String? errorMessage = _errorMessage;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Administration',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Accès réservé aux administrateurs.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                        validator: (String? value) {
                          final String text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Saisissez l\'adresse e-mail.';
                          }
                          if (!text.contains('@') || !text.contains('.')) {
                            return 'Adresse e-mail invalide.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (String? value) {
                          if ((value ?? '').isEmpty) {
                            return 'Saisissez le mot de passe.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      if (errorMessage != null) ...<Widget>[
                        _ErrorBanner(message: errorMessage),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_submitting ? 'Connexion…' : 'Se connecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur compact, affiché au-dessus du bouton de connexion.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

