import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cadastro_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // Suas chaves originais
    url: 'https://ukzkiijpldsjzhpftumk.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVremtpaWpwbGRzanpocGZ0dW1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxMjk4MzksImV4cCI6MjA4MjcwNTgzOX0.KybTo0IPM5atFgwlQ4o4yKcQyC053fv2dXBR08-0TJA', 
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogo da Mãe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black, // Fundo Preto
        
        // Configuração de Cores Escuras
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, 
          surface: const Color(0xFF1E1E1E), // Cor base para superfícies
        ),
        
        // Ícones brancos
        iconTheme: const IconThemeData(color: Colors.white),

        // REMOVI O 'cardTheme' DAQUI PARA PARAR O ERRO NO SEU LINUX.
        // Vamos configurar a cor direto no Cartão lá embaixo.
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _todosProdutos = [];
  List<String> _todasCategorias = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarDados();
  }

  Future<void> _buscarDados() async {
    setState(() => _carregando = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Busca Categorias
      final respCat = await supabase.from('categorias').select('nome').order('nome');
      final listaCat = (respCat as List).map((e) => e['nome'] as String).toList();

      // 2. Busca Produtos
      final respProd = await supabase.from('produtos').select().order('nome');
      final listaProd = List<Map<String, dynamic>>.from(respProd as List);

      setState(() {
        _todasCategorias = listaCat;
        _todosProdutos = listaProd;
        _carregando = false;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
      setState(() => _carregando = false);
    }
  }

  Future<void> _deletarProduto(int id) async {
    final confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Produto?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      await Supabase.instance.client.from('produtos').delete().eq('id', id);
      _buscarDados();
    }
  }

  Future<void> _compartilharWhatsApp(Map<String, dynamic> item) async {
    final nome = item['nome'];
    final preco = item['preco'];
    final id = item['id'];
    final imgUrl = item['imagem_url'] ?? '';

    final linkSite = "https://loja-da-mae.vercel.app/detalhe?id=$id";
    
    final texto = 
      "Oie! Olha esse produto novo:\n*$nome*\n💲 R\$ $preco\n\n👇 *Veja detalhes no site:*\n$linkSite\n\n(Foto: $imgUrl)";
    
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(texto)}");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _abrirGerenciadorCategorias() {
    showDialog(
      context: context,
      builder: (context) => const GerenciadorCategoriasDialog(),
    ).then((_) => _buscarDados());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque & Catálogo'),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Gerenciar Categorias',
            onPressed: _abrirGerenciadorCategorias,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _buscarDados,
        child: _carregando 
            ? const Center(child: CircularProgressIndicator())
            : _todasCategorias.isEmpty 
                ? const Center(child: Text('Nenhuma categoria criada.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _todasCategorias.length,
                    itemBuilder: (context, index) {
                      final categoriaNome = _todasCategorias[index];
                      final produtosDestaCategoria = _todosProdutos.where((p) => p['categoria'] == categoriaNome).toList();

                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(
                            categoriaNome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurpleAccent),
                          ),
                          leading: const Icon(Icons.folder, color: Colors.deepPurple),
                          childrenPadding: const EdgeInsets.all(10),
                          children: [
                            if (produtosDestaCategoria.isEmpty)
                              const Padding(padding: EdgeInsets.all(8.0), child: Text('Nenhum produto nesta categoria.')),
                            
                            ...produtosDestaCategoria.map((produto) {
                              return _buildProdutoGaveta(produto);
                            }),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const CadastroPage()));
          _buscarDados();
        },
        label: const Text('Novo Produto', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProdutoGaveta(Map<String, dynamic> item) {
    final String variantesRaw = item['variantes'] ?? '';
    final List<String> listaVariantes = variantesRaw.isNotEmpty 
        ? variantesRaw.split(',').map((e) => e.trim()).toList() 
        : [];

    return Card(
      // --- CORREÇÃO DO ERRO ---
      // Definimos a cor e o formato AQUI, localmente, em vez de no ThemeData.
      color: const Color(0xFF1E1E1E), // Cinza Escuro
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 5),
      
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        leading: item['imagem_url'] != null
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['imagem_url'], width: 50, height: 50, fit: BoxFit.cover))
            : const Icon(Icons.image, size: 50, color: Colors.grey),
        title: Text(item['nome'], style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        subtitle: Text('R\$ ${item['preco']}  |  Estoque: ${item['estoque']}', style: const TextStyle(color: Colors.greenAccent)),
        trailing: Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
        
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (item['codigo_barras'] != null && item['codigo_barras'] != '')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.qr_code, size: 16, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text('Cód: ${item['codigo_barras']}', style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),

		// ... (código anterior do buildProdutoGaveta) ...

                if (listaVariantes.isNotEmpty) ...[
                  const Text('Variações:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 5),

                  Builder(
                    builder: (context) {
                      // 1. DEFINA SUAS CORES AQUI (Cores vibrantes para fundo escuro)
                      final cores = [
                        Colors.cyanAccent,
                        Colors.orangeAccent,
                        Colors.purpleAccent,
                        Colors.greenAccent,
                        Colors.pinkAccent,
                        Colors.amberAccent,
                      ];

                      return Wrap(
                        spacing: 8,
                        // Usamos .asMap().entries para pegar o ÍNDICE (0, 1, 2...) e o VALOR (P, M...)
                        children: listaVariantes.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String texto = entry.value;

                          // Pega a cor baseada no índice (se acabar a lista, volta pro começo com %)
                          Color corFundo = cores[idx % cores.length];

                          return Chip(
                            label: Text(
                              texto,
                              // Texto preto fica mais legível em cores neon
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w900)
                            ),
                            backgroundColor: corFundo,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none, // Sem borda para ficar estilo "adesivo"
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          );
                        }).toList(),
                      );
                    }
                  ),
                  const SizedBox(height: 15),
                ],

// ... (restante do código) ...

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blueAccent),
                      label: const Text('Editar', style: TextStyle(color: Colors.blueAccent)),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroPage(produtoParaEditar: item)));
                        _buscarDados();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                      label: const Text('Apagar', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => _deletarProduto(item['id']),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 18, color: Colors.white),
                      label: const Text('Zap', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _compartilharWhatsApp(item),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class GerenciadorCategoriasDialog extends StatefulWidget {
  const GerenciadorCategoriasDialog({super.key});

  @override
  State<GerenciadorCategoriasDialog> createState() => _GerenciadorCategoriasDialogState();
}

class _GerenciadorCategoriasDialogState extends State<GerenciadorCategoriasDialog> {
  List<dynamic> _categorias = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await Supabase.instance.client.from('categorias').select().order('nome');
    setState(() { _categorias = data; _loading = false; });
  }

  Future<void> _editar(Map<String, dynamic> cat) async {
    final controller = TextEditingController(text: cat['nome']);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear Categoria'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Novo nome')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != cat['nome']) {
                await Supabase.instance.client.from('categorias').update({'nome': controller.text}).eq('id', cat['id']);
                await Supabase.instance.client.from('produtos').update({'categoria': controller.text}).eq('categoria', cat['nome']);
                Navigator.pop(ctx);
                _load();
              }
            },
            child: const Text('Salvar'),
          )
        ],
      ),
    );
  }

  Future<void> _deletar(int id) async {
    await Supabase.instance.client.from('categorias').delete().eq('id', id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerenciar Categorias'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _categorias.length,
                itemBuilder: (ctx, i) {
                  final cat = _categorias[i];
                  return ListTile(
                    title: Text(cat['nome']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editar(cat)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deletar(cat['id'])),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
