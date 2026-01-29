import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'main.dart'; 

class AgendamentoScreen extends StatefulWidget {
  final int clienteId;
  final String clienteNome;
  final int salaoId;
  final String salaoNome;
  final String salaoTelefone;
  final String? salaoInstagram;
  final String? salaoEndereco;

  const AgendamentoScreen({
    super.key,
    required this.clienteId,
    required this.clienteNome,
    required this.salaoId,
    required this.salaoNome,
    required this.salaoTelefone,
    this.salaoInstagram,
    this.salaoEndereco,
  });

  @override
  State<AgendamentoScreen> createState() => _AgendamentoScreenState();
}

class _AgendamentoScreenState extends State<AgendamentoScreen> {
  final ApiClient _client = ApiClient();
  List<dynamic> _servicos = [];
  int? _idServicoSelecionado;

  DateTime _dataSelecionada = DateTime.now();
  TimeOfDay _horaSelecionada = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarServicos();
  }

  void _carregarServicos() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client.dio.get('servicos/?salao=${widget.salaoId}');
      setState(() {
        _servicos = response.data;
        _isLoading = false;
      });
    } catch (e) {
      print("Erro: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- NOVA FUNÇÃO: FORMATAÇÃO DE HORAS (Igual ao Admin) ---
  String _formatarDuracaoTexto(int minutosTotais) {
    if (minutosTotais < 60) {
      return "$minutosTotais min";
    } else {
      int horas = minutosTotais ~/ 60;
      int minutos = minutosTotais % 60;
      
      if (minutos == 0) {
        return "${horas}h"; 
      } else {
        String minFormatado = minutos.toString().padLeft(2, '0');
        return "${horas}h ${minFormatado}min"; 
      }
    }
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('pt', 'BR'),
      initialDate: _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFE91E63)), 
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dataSelecionada = picked);
  }

  Future<void> _selecionarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _horaSelecionada,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFE91E63)), 
            timePickerTheme: TimePickerThemeData(dialHandColor: const Color(0xFFE91E63), dialBackgroundColor: Colors.pink[50]),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _horaSelecionada = picked);
  }

  void _abrirWhatsAppSalao() async {
    final numLimpo = widget.salaoTelefone.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri url = Uri.parse("https://wa.me/55$numLimpo?text=Olá, vim pelo App Bela Agenda.");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp")));
    }
  }

  void _abrirInstagram() async {
    final String instaRaw = (widget.salaoInstagram != null && widget.salaoInstagram!.isNotEmpty) 
        ? widget.salaoInstagram! 
        : "@belaagenda"; 
    
    final String username = instaRaw.replaceAll('@', '').trim();
    final Uri url = Uri.parse("https://instagram.com/$username");
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao abrir Instagram")));
    }
  }

  void _abrirMapa() async {
     final String endereco = (widget.salaoEndereco != null && widget.salaoEndereco!.isNotEmpty)
        ? widget.salaoEndereco!
        : "Endereço do Salão"; 

     final Uri url = Uri.parse("http://maps.google.com/?q=${Uri.encodeComponent(endereco)}");
     
     if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao abrir Mapa")));
     }
  }

  void _confirmarAgendamento() async {
    if (_idServicoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione um serviço!")));
      return;
    }

    final servico = _servicos.firstWhere((s) => s['id'] == _idServicoSelecionado);
    final DateTime dataInicio = DateTime(_dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day, _horaSelecionada.hour, _horaSelecionada.minute);
    final int duracaoMinutos = int.tryParse(servico['duracao_minutos'].toString()) ?? 30;
    final DateTime dataFim = dataInicio.add(Duration(minutes: duracaoMinutos));

    try {
      await _client.dio.post('agenda/', data: {
        "cliente": widget.clienteId,
        "servico": servico['id'],
        "salao": widget.salaoId,
        "data_hora_inicio": dataInicio.toIso8601String(),
        "data_hora_fim": dataFim.toIso8601String(),
        "valor_cobrado": servico['preco'],
        "status": "PENDENTE",
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Solicitação Enviada! 🎉", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text("Aguarde a confirmação para o dia ${DateFormat('dd/MM').format(_dataSelecionada)} às ${_horaSelecionada.format(context)}.", style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("OK", style: TextStyle(color: Color(0xFFE91E63)))
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      String msg = "Erro ao agendar.";
      if (e.response?.data is List) {
        msg = e.response?.data[0];
      } else if (e.response?.data is Map && e.response?.data.containsKey('detail')) {
        msg = e.response?.data['detail']; // Mensagens de erro do Django (conflito de horário, loja fechada, etc)
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final String textoEndereco = (widget.salaoEndereco != null && widget.salaoEndereco!.isNotEmpty) 
        ? widget.salaoEndereco! 
        : "Ver localização no mapa";

    return Stack(
      children: [
        Positioned.fill(child: Image.asset('assets/images/login_bg.jpeg', fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.white.withOpacity(0.7))),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.salaoNome, style: GoogleFonts.poppins(color: const Color(0xFF880E4F), fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFFE91E63)),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandingScreen())),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Olá, ${widget.clienteNome}", style: GoogleFonts.poppins(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      Text("1. Escolha o Serviço", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF880E4F))),
                      const SizedBox(height: 10),
                      if (_servicos.isEmpty)
                        const Text("Nenhum serviço disponível.")
                      else
                        Column(
                          children: _servicos.map((item) {
                            final isSelected = item['id'] == _idServicoSelecionado;
                            final preco = double.tryParse(item['preco'].toString()) ?? 0.0;
                            final duracaoMinutos = item['duracao_minutos'] ?? 30;
                            
                            // AQUI A MÁGICA: USA A FORMATAÇÃO "1h 30min"
                            final duracaoTexto = _formatarDuracaoTexto(duracaoMinutos);

                            return GestureDetector(
                              onTap: () => setState(() => _idServicoSelecionado = item['id']),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFCE4EC) : Colors.white.withOpacity(0.9),
                                  border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['nome'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                        // MOSTRA O TEXTO FORMATADO
                                        Text(duracaoTexto, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    Text(moeda.format(preco), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFE91E63))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 30),

                      Text("2. Escolha Data e Hora", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF880E4F))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelector(
                              icon: Icons.calendar_month,
                              text: DateFormat('dd/MM', 'pt_BR').format(_dataSelecionada),
                              onTap: _selecionarData,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildSelector(
                              icon: Icons.access_time,
                              text: "${_horaSelecionada.hour.toString().padLeft(2, '0')}:${_horaSelecionada.minute.toString().padLeft(2, '0')}",
                              onTap: _selecionarHora,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _confirmarAgendamento,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            elevation: 5,
                            shadowColor: const Color(0xFFE91E63).withOpacity(0.4),
                          ),
                          child: Text("CONFIRMAR AGENDAMENTO", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),

                      const SizedBox(height: 30),
                      
                      Center(
                        child: Column(
                          children: [
                            Text("Fale Conosco ou Visite-nos", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
                            const SizedBox(height: 10),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _abrirWhatsAppSalao,
                                  style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFF25D366), 
                                     foregroundColor: Colors.white,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8)
                                  ),
                                  icon: const Icon(Icons.chat, size: 18),
                                  label: const Text("WhatsApp"),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _abrirInstagram,
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: const Color(0xFFE1306C), 
                                     foregroundColor: Colors.white,
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                     padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8)
                                  ),
                                  icon: const Icon(Icons.camera_alt, size: 18), 
                                  label: const Text("Instagram"),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 10),

                            TextButton.icon(
                              onPressed: _abrirMapa,
                              icon: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 20),
                              label: Text(
                                textoEndereco, 
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 12, decoration: TextDecoration.underline)
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSelector({required IconData icon, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE91E63)),
            const SizedBox(height: 5),
            Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}