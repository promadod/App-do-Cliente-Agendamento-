import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'agendamento_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  runApp(
    MaterialApp(
      title: 'Bela Agenda - Cliente',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          prefixIconColor: const Color(0xFFE91E63),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),

      // ROTEAMENTO INTELIGENTE (SLUG OU ID)
      onGenerateRoute: (settings) {
        String? slugDetectado;

        if (settings.name != null && settings.name != '/') {
          // Remove a barra inicial (de "/15" para "15")
          slugDetectado = settings.name!.replaceAll('/', '');
        }

        return MaterialPageRoute(
          builder: (_) => LandingScreen(slugViaUrl: slugDetectado),
        );
      },
    ),
  );
}

// ============================================================================
// TELA 1: LANDING (O PORTEIRO INTELIGENTE COM SUPORTE A ID)
// ============================================================================
class LandingScreen extends StatefulWidget {
  final String? slugViaUrl; // Pode ser nome ("bronzedagil") ou ID ("15")

  const LandingScreen({super.key, this.slugViaUrl});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final ApiClient _client = ApiClient();
  final TextEditingController _buscaController = TextEditingController();

  String _mensagemStatus = "Carregando...";
  bool _modoBusca = false;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _iniciarAcesso);
  }

  void _iniciarAcesso() async {
    // 1. Prioridade Total: URL (Link com ID ou Nome)
    if (widget.slugViaUrl != null && widget.slugViaUrl!.isNotEmpty) {
      // Verifica se é um NÚMERO (Novo padrão) ou TEXTO (Antigo)
      if (int.tryParse(widget.slugViaUrl!) != null) {
        _buscarPorId(int.parse(widget.slugViaUrl!));
      } else {
        _buscarPorSlug(widget.slugViaUrl!); // Mantém suporte a links antigos
      }
      return;
    }

    // 2. Se não tem URL, tenta a memória (Cache)
    final prefs = await SharedPreferences.getInstance();
    
    // Tenta recuperar ID primeiro (mais seguro)
    final ultimoId = prefs.getInt('ultimo_salao_id');
    if (ultimoId != null) {
      _buscarPorId(ultimoId);
      return;
    }

    // Se não tiver ID, tenta slug antigo
    final ultimoSlug = prefs.getString('ultimo_salao_slug');
    if (ultimoSlug != null) {
      _buscarPorSlug(ultimoSlug);
      return;
    }

    // 3. Último caso: Mostra campo de busca
    setState(() {
      _modoBusca = true;
      _mensagemStatus = "Digite o ID ou Link da loja";
    });
  }

  // --- NOVA FUNÇÃO: BUSCA POR ID (MUITO MAIS SEGURA) ---
  void _buscarPorId(int id) async {
    setState(() {
      _modoBusca = false;
      _erro = false;
      _mensagemStatus = "Acessando loja #$id...";
    });

    try {
      // Chama a rota nova que criamos no Django
      final response = await _client.dio.get('salao-id/$id/');
      final dadosSalao = response.data;

      // Salva na memória o ID (que nunca muda!)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ultimo_salao_id', id);

      if (mounted) {
        _irParaLogin(dadosSalao);
      }
    } catch (e) {
      setState(() {
        _erro = true;
        _modoBusca = true;
        _mensagemStatus = "Loja #$id não encontrada.";
      });
    }
  }

  // --- FUNÇÃO LEGADA: BUSCA POR SLUG (PARA LINKS ANTIGOS) ---
  void _buscarPorSlug(String slug) async {
    setState(() {
      _modoBusca = false;
      _erro = false;
      _mensagemStatus = "Acessando $slug...";
    });

    try {
      final response = await _client.dio.get('salao-info/$slug/');
      final dadosSalao = response.data;

      // Aproveita e já salva o ID para o futuro
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ultimo_salao_id', dadosSalao['id']);

      if (mounted) {
        _irParaLogin(dadosSalao);
      }
    } catch (e) {
      setState(() {
        _erro = true;
        _modoBusca = true;
        _mensagemStatus = "Loja '$slug' não encontrada.";
      });
    }
  }

  void _irParaLogin(dynamic dadosSalao) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => IdentificacaoScreen(
          salaoId: dadosSalao['id'],
          salaoNome: dadosSalao['nome'],
          salaoTelefone: dadosSalao['telefone'] ?? "",
          salaoInstagram: dadosSalao['instagram'],
          salaoEndereco: dadosSalao['endereco'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/login_bg.jpeg', fit: BoxFit.cover),
        ),
        Positioned.fill(child: Container(color: Colors.white.withOpacity(0.7))),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront,
                      size: 50,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  const SizedBox(height: 30),

                  if (!_modoBusca) ...[
                    const CircularProgressIndicator(color: Color(0xFFE91E63)),
                    const SizedBox(height: 20),
                    Text(
                      _mensagemStatus,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF880E4F),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "Bem-vindo(a)!",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF880E4F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _erro ? _mensagemStatus : "Digite o ID ou Link da loja:",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: _erro ? Colors.red : Colors.grey[700],
                        fontWeight: _erro ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CAMPO DE BUSCA INTELIGENTE (Aceita número ou texto)
                    TextField(
                      controller: _buscaController,
                      keyboardType: TextInputType.text, // Aceita letras e números
                      decoration: const InputDecoration(
                        hintText: "Ex: 15 ou bronzedagil",
                        prefixIcon: Icon(Icons.link),
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (val) {
                         if (int.tryParse(val) != null) {
                           _buscarPorId(int.parse(val));
                         } else {
                           _buscarPorSlug(val);
                         }
                      },
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final texto = _buscaController.text.trim();
                          if (texto.isNotEmpty) {
                            if (int.tryParse(texto) != null) {
                               _buscarPorId(int.parse(texto));
                             } else {
                               _buscarPorSlug(texto);
                             }
                          }
                        },
                        child: Text(
                          "ACESSAR LOJA",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TELA 2: IDENTIFICAÇÃO (PERMANECE IGUAL)
// ============================================================================
class IdentificacaoScreen extends StatefulWidget {
  final int salaoId;
  final String salaoNome;
  final String salaoTelefone;
  final String? salaoInstagram;
  final String? salaoEndereco;

  const IdentificacaoScreen({
    super.key,
    required this.salaoId,
    required this.salaoNome,
    required this.salaoTelefone,
    this.salaoInstagram,
    this.salaoEndereco,
  });

  @override
  State<IdentificacaoScreen> createState() => _IdentificacaoScreenState();
}

class _IdentificacaoScreenState extends State<IdentificacaoScreen> {
  final ApiClient _client = ApiClient();
  final TextEditingController _zapController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();

  bool _carregando = false;
  bool _precisaCadastrar = false;

  void _verificarOuCadastrar() async {
    if (_zapController.text.isEmpty) return;
    setState(() => _carregando = true);
    String telLimpo = _zapController.text.replaceAll(RegExp(r'[^0-9]'), '');

    try {
      if (!_precisaCadastrar) {
        final response = await _client.dio.post(
          'clientes/verificar/',
          data: {'whatsapp': telLimpo},
        );

        if (response.data['existe'] == true) {
          _irParaAgendamento(response.data['id'], response.data['nome']);
        } else {
          setState(() {
            _precisaCadastrar = true;
            _carregando = false;
          });
        }
      } else {
        final response = await _client.dio.post(
          'clientes/',
          data: {
            'nome': _nomeController.text,
            'telefone': telLimpo,
            'email': '$telLimpo@temp.com',
            'salao': widget.salaoId,
          },
        );
        _irParaAgendamento(response.data['id'], response.data['nome']);
      }
    } catch (e) {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _irParaAgendamento(int clienteId, String clienteNome) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AgendamentoScreen(
          clienteId: clienteId,
          clienteNome: clienteNome,
          salaoId: widget.salaoId,
          salaoNome: widget.salaoNome,
          salaoTelefone: widget.salaoTelefone,
          salaoInstagram: widget.salaoInstagram,
          salaoEndereco: widget.salaoEndereco,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/login_bg.jpeg', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.4),
                  const Color(0xFFE91E63).withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Bem-vindo(a) ao",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.salaoNome,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        const Shadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _zapController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Seu WhatsApp",
                            prefixIcon: Icon(Icons.phone_iphone),
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_precisaCadastrar)
                          Column(
                            children: [
                              TextField(
                                controller: _nomeController,
                                decoration: const InputDecoration(
                                  labelText: "Seu Nome",
                                  prefixIcon: Icon(Icons.person),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _carregando
                                ? null
                                : _verificarOuCadastrar,
                            child: _carregando
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _precisaCadastrar ? "CADASTRAR" : "ENTRAR",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}