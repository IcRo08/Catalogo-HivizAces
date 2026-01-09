import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroPage extends StatefulWidget {
  final Map<String, dynamic>? produtoParaEditar;

  const CadastroPage({super.key, this.produtoParaEditar});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nomeController = TextEditingController();
  final _barcodeController = TextEditingController(); // NOVO: Campo do código de barras
  final _precoVendaController = TextEditingController();
  final _precoCustoController = TextEditingController();
  final _estoqueController = TextEditingController();
  final _variantesController = TextEditingController();
  
  File? _imagemSelecionada;
  String? _urlImagemExistente;
  bool _carregando = false;

  List<String> _categorias = [];
  String? _categoriaSelecionada;
  bool _carregandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _buscarCategorias();
    _preencherDadosSeForEdicao();
  }

  void _preencherDadosSeForEdicao() {
    if (widget.produtoParaEditar != null) {
      final p = widget.produtoParaEditar!;
      _nomeController.text = p['nome'];
      _barcodeController.text = p['codigo_barras'] ?? ''; // Carrega o código se existir
      _precoVendaController.text = p['preco'].toString();
      _precoCustoController.text = (p['preco_custo'] ?? 0).toString();
      _estoqueController.text = (p['estoque'] ?? 0).toString();
      _variantesController.text = p['variantes'] ?? '';
      _categoriaSelecionada = p['categoria'];
      _urlImagemExistente = p['imagem_url'];
    }
  }

  Future<void> _buscarCategorias() async {
    try {
      final response = await Supabase.instance.client
          .from('categorias').select('nome').order('nome');
      
      final lista = (response as List).map((e) => e['nome'] as String).toList();
      
      setState(() {
        _categorias = lista;
        _carregandoCategorias = false;
        if (widget.produtoParaEditar != null) {
          final catAtual = widget.produtoParaEditar!['categoria'];
          if (catAtual != null && !_categorias.contains(catAtual)) {
            _categorias.add(catAtual);
          }
        }
      });
    } catch (e) {
      print('Erro categorias: $e');
    }
  }

  Future<void> _criarCategoria() async {
    final controllerNovaCat = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(controller: controllerNovaCat, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controllerNovaCat.text.isNotEmpty) {
                await Supabase.instance.client.from('categorias').insert({'nome': controllerNovaCat.text});
                Navigator.pop(context);
                _buscarCategorias();
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  // Lógica da Câmera vs Galeria (CORRIGIDA)
  Future<void> _escolherImagem() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar Foto'),
                onTap: () {
                  _pegarImagem(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  _pegarImagem(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pegarImagem(ImageSource origem) async {
    final ImagePicker picker = ImagePicker();
    // imageQuality: 50 ajuda a foto não ficar pesada demais no banco
    final XFile? imagem = await picker.pickImage(source: origem, imageQuality: 50);

    if (imagem != null) {
      setState(() {
        _imagemSelecionada = File(imagem.path);
      });
    }
  }

  Future<void> _salvarProduto() async {
    if (_nomeController.text.isEmpty || _categoriaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha nome e categoria!')));
      return;
    }

    setState(() { _carregando = true; });

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl = _urlImagemExistente;

      if (_imagemSelecionada != null) {
        final nomeArquivo = '${DateTime.now().millisecondsSinceEpoch}_img.jpg';
        await supabase.storage.from('vitrine').upload(nomeArquivo, _imagemSelecionada!);
        imageUrl = supabase.storage.from('vitrine').getPublicUrl(nomeArquivo);
      }

      final dados = {
        'nome': _nomeController.text,
        'codigo_barras': _barcodeController.text, // SALVA O CÓDIGO AQUI
        'categoria': _categoriaSelecionada,
        'variantes': _variantesController.text,
        'preco': double.tryParse(_precoVendaController.text.replaceAll(',', '.')) ?? 0.0,
        'preco_custo': double.tryParse(_precoCustoController.text.replaceAll(',', '.')) ?? 0.0,
        'estoque': int.tryParse(_estoqueController.text) ?? 0,
        'imagem_url': imageUrl,
      };

      if (widget.produtoParaEditar != null) {
        await supabase.from('produtos').update(dados).eq('id', widget.produtoParaEditar!['id']);
      } else {
        await supabase.from('produtos').insert(dados);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!')));
      }
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $erro')));
    } finally {
      setState(() { _carregando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.produtoParaEditar != null ? 'Editar Produto' : 'Novo Produto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Área da Imagem
              GestureDetector(
                onTap: _escolherImagem,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey)),
                  child: _imagemSelecionada != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_imagemSelecionada!, fit: BoxFit.cover))
                      : (_urlImagemExistente != null 
                          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_urlImagemExistente!, fit: BoxFit.cover))
                          : const Center(child: Icon(Icons.add_a_photo, size: 40, color: Colors.grey))),
                ),
              ),
              const SizedBox(height: 20),

              // Categoria
              Row(children: [
                Expanded(child: _carregandoCategorias ? const LinearProgressIndicator() : DropdownButtonFormField<String>(
                  value: _categoriaSelecionada, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _categoriaSelecionada = v))),
                IconButton(icon: const Icon(Icons.add_box, size: 30, color: Colors.deepPurple), onPressed: _criarCategoria)
              ]),
              const SizedBox(height: 15),

              // NOVO: Código de Barras
              // Dica: Colocamos autfocus false, mas se ela usar o leitor, ele preenche sozinho
              TextField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Código de Barras (Scan)',
                  hintText: 'Bipe o produto aqui',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner),
                  suffixIcon: Icon(Icons.usb), // Ícone para indicar suporte a USB
                ),
              ),
              const SizedBox(height: 15),

              TextField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome do Produto', border: OutlineInputBorder(), prefixIcon: Icon(Icons.abc))),
              const SizedBox(height: 15),
              TextField(controller: _variantesController, decoration: const InputDecoration(labelText: 'Variantes (P, M, G)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.style))),
              const SizedBox(height: 15),
              
              Row(children: [
                Expanded(child: TextField(controller: _precoCustoController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _precoVendaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Venda', border: OutlineInputBorder()))),
              ]),
              const SizedBox(height: 15),
              TextField(controller: _estoqueController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estoque', border: OutlineInputBorder())),
              
              const SizedBox(height: 30),
              _carregando ? const Center(child: CircularProgressIndicator()) : ElevatedButton(
                onPressed: _salvarProduto,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                child: Text(widget.produtoParaEditar != null ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR', style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
