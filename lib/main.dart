import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // Para copiar para a área de transferência
import 'dart:async'; // Para usar Future.delayed

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DataCollectorApp());
}

// Classe de Dados Estruturados (Item de Tabela)
class DataItem {
  String nome;
  String tamanho;
  String numero;
  double quantidade;

  DataItem({
    required this.nome,
    required this.tamanho,
    required this.numero,
    required this.quantidade,
  });

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'tamanho': tamanho,
    'numero': numero,
    'quantidade': quantidade,
  };

  factory DataItem.fromJson(Map<String, dynamic> json) {
    // Tratamento robusto de 'quantidade' para aceitar double ou string
    final dynamic rawQuantity = json['quantidade'];
    double parsedQuantity = 0.0;

    if (rawQuantity is double) {
      parsedQuantity = rawQuantity;
    } else if (rawQuantity is int) {
      parsedQuantity = rawQuantity.toDouble();
    } else if (rawQuantity != null) {
      final String quantityStr = rawQuantity.toString().replaceAll(',', '.');
      parsedQuantity = double.tryParse(quantityStr) ?? 0.0;
    }

    return DataItem(
      nome: json['nome'] as String,
      tamanho: json['tamanho'] as String,
      numero: json['numero']?.toString() ?? '',
      quantidade: parsedQuantity,
    );
  }
}

// Widget Principal do Aplicativo
class DataCollectorApp extends StatelessWidget {
  const DataCollectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coletor de Dados para Macro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DataCollectorScreen(),
    );
  }
}

// Tela Principal
class DataCollectorScreen extends StatefulWidget {
  const DataCollectorScreen({super.key});

  @override
  State<DataCollectorScreen> createState() => _DataCollectorScreenState();
}

class _DataCollectorScreenState extends State<DataCollectorScreen> {
  final List<DataItem> _dataList = [];

  // --- Dados do Cliente ---
  String _nomeCliente = '';
  String _telefoneCliente = '';

  final TextEditingController _clienteNomeController = TextEditingController();
  final TextEditingController _clienteTelefoneController =
      TextEditingController();

  // Controllers para entrada de novos dados
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _tamanhoController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();

  final FocusNode _nomeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _tamanhoController.dispose();
    _numeroController.dispose();
    _quantidadeController.dispose();
    _nomeFocusNode.dispose();
    _clienteNomeController.dispose();
    _clienteTelefoneController.dispose();
    super.dispose();
  }

  // --- Persistência ---
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = prefs.getString('macro_data');
    final savedNome = prefs.getString('cliente_nome') ?? '';
    final savedTelefone = prefs.getString('cliente_telefone') ?? '';

    if (mounted) {
      setState(() {
        _nomeCliente = savedNome;
        _telefoneCliente = savedTelefone;
        _clienteNomeController.text = savedNome;
        _clienteTelefoneController.text = savedTelefone;

        if (dataJson != null) {
          try {
            final List<dynamic> jsonList = jsonDecode(dataJson);
            _dataList.clear();
            for (var item in jsonList) {
              // Garante que apenas objetos válidos sejam adicionados
              if (item is Map<String, dynamic>) {
                _dataList.add(DataItem.fromJson(item));
              }
            }
          } catch (e) {
            // Em caso de erro de parsing, limpa os dados corrompidos
            print('Erro ao carregar lista de dados: $e');
            prefs.remove('macro_data');
          }
        }
      });
    }
  }

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _dataList
        .map((item) => item.toJson())
        .toList();
    prefs.setString('macro_data', jsonEncode(jsonList));
    prefs.setString('cliente_nome', _nomeCliente);
    prefs.setString('cliente_telefone', _telefoneCliente);
  }

  void _showSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // Verifica se o contexto está montado antes de mostrar o Snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: duration));
  }

  // --- Ações ---
  void _addItem() {
    final nome = _nomeController.text.trim();
    final tamanho = _tamanhoController.text.trim();
    final numero = _numeroController.text.trim();
    final quantidadeStr = _quantidadeController.text.trim().replaceAll(
      ',',
      '.', // Substitui vírgula por ponto para parsing correto de double
    );

    if (tamanho.isEmpty) {
      _showSnackbar('TAMANHO deve ser preenchido.');
      return;
    }

    final isNameFilled = nome.isNotEmpty;
    final isNumberFilled = numero.isNotEmpty;
    final isQuantityFilled = quantidadeStr.isNotEmpty;

    if (!isNameFilled && !isNumberFilled && !isQuantityFilled) {
      _showSnackbar(
        'Preencha pelo menos NOME, NÚMERO ou QUANTIDADE (além de TAMANHO).',
      );
      return;
    }

    double quantidade = 0.0;
    if (isQuantityFilled) {
      final double? parsedQuantity = double.tryParse(quantidadeStr);
      if (parsedQuantity == null) {
        _showSnackbar('O campo Quantidade deve ser um número válido.');
        return;
      }
      quantidade = parsedQuantity;
    }

    // Se a tela não estiver montada, evita chamar setState
    if (!mounted) return;
    setState(() {
      _dataList.insert(
        0,
        DataItem(
          nome: nome,
          tamanho: tamanho,
          numero: numero,
          quantidade: quantidade,
        ),
      );
    });

    _nomeController.clear();
    _numeroController.clear();
    _quantidadeController.clear();

    // Pequeno delay para garantir que o foco seja aplicado após o rebuild
    Future.delayed(const Duration(milliseconds: 100), () {
      _nomeFocusNode.requestFocus();
    });

    _saveData();
  }

  void _removeItem(int index) {
    if (!mounted) return;
    setState(() {
      _dataList.removeAt(index);
    });
    _saveData();
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Todos os Dados?'),
        content: const Text(
          'Tem certeza de que deseja remover todos os registros e os dados do cliente? Esta ação não pode ser desfeita.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _dataList.clear();
                  _nomeCliente = '';
                  _telefoneCliente = '';
                  _clienteNomeController.clear();
                  _clienteTelefoneController.clear();
                });
              }
              _saveData();
              Navigator.of(context).pop();
              _showSnackbar('Todos os dados foram limpos.');
            },
            child: const Text('Limpar Tudo'),
          ),
        ],
      ),
    );
  }

  // --- CSV ---
  String _formatQuantity(double qty) {
    // Se for 0.0, retorna vazio, senão formata.
    if (qty == 0.0) return '';
    // Se for inteiro (ex: 5.0), retorna como inteiro (5)
    if (qty == qty.toInt().toDouble()) return qty.toInt().toString();
    // Senão, retorna com 2 casas decimais, usando vírgula como separador decimal
    return qty.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _createCsvString() {
    // --- 1. DADOS DO CLIENTE (Linhas de cabeçalho personalizadas) ---
    final List<List<dynamic>> initialRows = [
      ['DADOS DO CLIENTE', ''],
      ['NOME', _nomeCliente],
      ['TELEFONE', _telefoneCliente],
      ['', ''], // linha em branco
      [
        'ITEM',
        'TAMANHO',
        'NÚMERO',
        'QUANTIDADE',
      ], // Cabeçalho da tabela de itens
    ];

    // --- 2. DADOS DOS ITENS ---
    final itemData = _dataList
        .map(
          (item) => [
            item.nome,
            item.tamanho,
            item.numero,
            _formatQuantity(item.quantidade),
          ],
        )
        .toList();

    // Adiciona todas as partes juntas: Cliente + Cabeçalho + Itens
    final List<List<dynamic>> rows = [...initialRows, ...itemData];

    // Cria o conversor com delimitador de campo ';'
    return const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      eol: '\n',
    ).convert(rows);
  }

  void _exportAndShareCsv() async {
    if (_dataList.isEmpty && _nomeCliente.isEmpty && _telefoneCliente.isEmpty) {
      _showSnackbar('Não há dados para exportar ou compartilhar.');
      return;
    }

    final csvString = _createCsvString();

    // Cria um nome de arquivo formatado
    final sanitizedNome = _nomeCliente.isEmpty
        ? 'Cliente'
        : _nomeCliente.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final sanitizedTelefone = _telefoneCliente.replaceAll(RegExp(r'[^\d]'), '');
    final now = DateTime.now();

    // Ignorando o download e focando na cópia, que é mais confiável no ambiente web
    await Clipboard.setData(ClipboardData(text: csvString));

    _showSnackbar(
      '✅ Conteúdo CSV copiado para a área de transferência!',
      duration: const Duration(seconds: 4),
    );
  }

  // --- Widgets ---
  Widget _buildInputCell(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
    FocusNode? focusNode,
    bool isLast = false,
  }) {
    // A flex é baseada no hint: Nome (flex 3), outros (flex 2)
    final int flexValue = hint == 'Nome' ? 3 : 2;

    // O Expanded é obrigatório dentro de Row para usar flex
    return Expanded(
      flex: flexValue,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          keyboardType: type,
          textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (value) {
            if (isLast) {
              _addItem();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
        ),
      ),
    );
  }

  Widget _buildClientField(
    TextEditingController controller,
    String hint,
    String key, {
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
        fillColor: Colors.white,
        filled: true,
      ),
      keyboardType: type,
      textInputAction: TextInputAction.next,
      onChanged: (value) {
        if (!mounted) return;
        setState(() {
          if (key == 'cliente_nome') {
            _nomeCliente = value;
          } else if (key == 'cliente_telefone') {
            _telefoneCliente = value;
          }
        });
        _saveData();
      },
    );
  }

  Widget _buildClientInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.2),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dados do Cliente',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2, // Distribui 2/3 do espaço para o nome
                    child: _buildClientField(
                      _clienteNomeController,
                      'Nome do Cliente',
                      'cliente_nome',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1, // Distribui 1/3 do espaço para o telefone
                    child: _buildClientField(
                      _clienteTelefoneController,
                      'Telefone',
                      'cliente_telefone',
                      type: TextInputType.phone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coletor de Dados (Planilha)'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Copiar CSV para a área de transferência',
            onPressed:
                (_dataList.isNotEmpty ||
                    _nomeCliente.isNotEmpty ||
                    _telefoneCliente.isNotEmpty)
                ? _exportAndShareCsv
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpar todos os dados salvos',
            onPressed:
                (_dataList.isNotEmpty ||
                    _nomeCliente.isNotEmpty ||
                    _telefoneCliente.isNotEmpty)
                ? _clearAllData
                : null,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 1. INPUT DE DADOS DO CLIENTE
          _buildClientInput(),

          // 2. INPUT DE NOVO ITEM
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                _buildInputCell(
                  _nomeController,
                  'Nome',
                  focusNode: _nomeFocusNode,
                ),
                _buildInputCell(_tamanhoController, 'Tam.'),
                _buildInputCell(
                  _numeroController,
                  'Núm.',
                  type: const TextInputType.numberWithOptions(decimal: false),
                ),
                _buildInputCell(
                  _quantidadeController,
                  'Qtde.',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  isLast: true,
                ),
                // Botão de Adicionar
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Tooltip(
                    message: 'Adicionar Item',
                    child: IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: _addItem,
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. CABEÇALHO DA TABELA
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Row(
              children: [
                // Os Expanded aqui devem refletir os flex dos inputs (3:2:2:2)
                const Expanded(
                  flex: 3,
                  child: Text(
                    'NOME',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'TAM.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'NÚMERO',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'QTDE.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 48), // Espaço para o botão de remoção
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. LISTA DE ITENS (Ocupa o espaço restante)
          Expanded(
            child: _dataList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.list_alt,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Nenhum item de coleta adicionado.',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _dataList.length,
                    itemBuilder: (context, index) {
                      final item = _dataList[index];
                      return Container(
                        color: index % 2 == 0
                            ? Colors.white
                            : Colors.indigo.shade50,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  // Linhas da Tabela
                                  Expanded(flex: 3, child: Text(item.nome)),
                                  Expanded(flex: 2, child: Text(item.tamanho)),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.numero.isEmpty ? '-' : item.numero,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _formatQuantity(item.quantidade),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // Botão de Remover
                                  SizedBox(
                                    width: 48,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeItem(index),
                                      tooltip: 'Remover',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index < _dataList.length - 1)
                              Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                                indent: 10,
                                endIndent: 10,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 5. RODAPÉ (TOTAL)
          Container(
            padding: const EdgeInsets.all(12.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Total de Itens na Lista: ${_dataList.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
