import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front_end/register.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:rx_notifier/rx_notifier.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false, // Remover a fita "debug"
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FocusNode _focusNode = FocusNode();
  static const int MAX_LIVES = 10;
  static const int RECOVERY_TIME_MINUTES = 5;

  // RxNotifier para controlar o estado
  final RxNotifier<List<Map<String, dynamic>>> conversations = RxNotifier([]);
  final RxNotifier<List<Map<String, dynamic>>> prompts = RxNotifier([]);
  final RxNotifier<String> newMessage = RxNotifier('');
  final RxNotifier<bool> isLoading = RxNotifier(false);
  final RxNotifier<bool> isTyping = RxNotifier(false);
  final RxNotifier<int> lives = RxNotifier(0);
  final RxNotifier<Duration> recoveryTime = RxNotifier(Duration.zero);
  final ScrollController _scrollController = ScrollController();

  String userId = '';
  String conversationId = '';
  String selectedTheme = '';
  String email = '';
  String password = '';

  String baseUrl = 'http://localhost:8000'; // Substitua pelo seu backend
  //String baseUrl = 'https://sistema-engsoft-65e29175f699.herokuapp.com';

  final TextEditingController _controller = TextEditingController();

  final Map<String, String> themes = {
    'Levantamento de Requisitos': '''
     Dada a seguinte descrição sobre requisitos: Os requisitos de um sistema descrevem o que ele deve fazer, os serviços que oferece e as restrições aplicáveis ao seu funcionamento. Eles são divididos em Requisitos Funcionais, que especificam as ações que o sistema deve realizar, e Requisitos Não-Funcionais, que delineiam as restrições e condições sob as quais o sistema deve operar. Além disso, os requisitos podem ser classificados como de Usuário, escritos em linguagem natural e diagramas para descrever os serviços oferecidos aos usuários e suas restrições, e de Sistema, que são descrições detalhadas do funcionamento do software, incluindo suas funções, serviços e restrições.

     Requisitos não-funcionais são subdivididos em três categorias: Requisitos de Produto, que abordam o desempenho do software, como a rapidez das transações; Requisitos Organizacionais, que envolvem políticas e procedimentos da organização cliente e desenvolvedora, como normas a serem seguidas; e Requisitos Externos, que são influenciados por fatores externos, como legislações e normas técnicas. Bons requisitos devem ser corretos, precisos, completos, consistentes e verificáveis, garantindo que não haja ambiguidades, que todas as funcionalidades sejam cobertas, e que seja possível testar se eles estão sendo atendidos.

     A partir dos requisitos, elaboram-se os casos de uso, que são escritos da perspectiva do ator que utilizará o sistema para alcançar um objetivo específico. Cada caso de uso inclui um fluxo normal e extensões para representar situações de erro ou variações no processo. Isso ajuda a assegurar que todas as possíveis interações e cenários de uso do sistema sejam considerados, proporcionando uma base sólida para o desenvolvimento e a verificação do software. Você será um assistente para auxiliar no levantamento de requisitos dos alunos de uma disciplina de Engenharia de Software. PROIBIDO CÓDIGO. PROIBIDO TUDO FORA DE REQUISITOS. LIMITE DE 700 TOKENS NA RESPOSTA. Resposta em português do Brasil
    ''',

    // 'Arquitetura e Projeto de Software': '''
    // Dado o seguinte texto sobre padrões de projeto e arquitetura de software:

    // Um projeto de software é um conjunto de princípios, conceitos e práticas que guiam o desenvolvimento de um produto de alta qualidade. Ele deve manter a integridade conceitual, garantindo coerência e coesão em todas as partes do sistema, e aplicar o ocultamento de informação, modularizando funcionalidades para facilitar o desenvolvimento paralelo, aumentar a flexibilidade e melhorar a legibilidade do código.

    // Outros princípios importantes incluem coesão, que agrupa atividades relacionadas em um único módulo, e acoplamento, que minimiza as dependências entre módulos para reduzir o impacto das alterações. A arquitetura de software organiza e estrutura o sistema, conectando o projeto à engenharia de requisitos e definindo os componentes principais e suas interações.

    // Existem diversos padrões arquiteturais, como a arquitetura em camadas, Model-View-Controller (MVC), microsserviços, orientada a mensagens, orientada a eventos, pipes e filtros, cliente/servidor e peer-to-peer. Cada padrão oferece vantagens específicas, dependendo do contexto do projeto, como a separação de responsabilidades, independência de módulos e facilitação da comunicação assíncrona.

    // Para escolher a melhor arquitetura, a abordagem ATAM (Architecture Trade-off Analysis Method) pode ser utilizada, consistindo em atividades como coleta de cenários, levantamento de requisitos e restrições, descrição dos padrões arquiteturais, avaliação de atributos de qualidade (confiabilidade, desempenho, segurança, flexibilidade), e identificação das sensibilidades desses atributos diante de mudanças. Através dessa análise crítica, é possível descartar alternativas menos viáveis e detalhar as arquiteturas restantes, reiniciando o processo até encontrar a solução mais adequada.

    // Você será um assistente para auxiliar na decisão de padrões de projeto e de arquitetura dos alunos de uma disciplina de Engenharia de Software. Não gere código automaticamente, apenas auxilie o aluno com exemplos para que ele consiga desenvolver sozinho. Se for perguntado algo que não seja sobre Projeto e Arquitetura de Software, responda que não é seu escopo.
    // ''',
    //'Testes': '''
    
    //Dada a seguinte descrição sobre testes:

    //Os testes de software são um conjunto de instruções planejadas e executadas sistematicamente para garantir que o programa funcione conforme esperado e corrigir quaisquer defeitos antes de seu uso comercial. Existem três grupos principais de testes automatizados: testes de unidade, que verificam pequenos trechos de código; testes de integração, que verificam funcionalidades completas do sistema e podem usar componentes externos; e testes de sistema, que simulam sessões de uso do sistema pelo usuário final, sendo mais caros e sensíveis a mudanças. 

    //Os testes de software podem ser realizados de duas maneiras: testes caixa-preta, que avaliam se o software cumpre suas funções sem se preocupar com a estrutura interna, e testes caixa-branca, que analisam o funcionamento interno do código. Testes caixa-preta se concentram nos requisitos funcionais e podem identificar uma classe diferente de erros em comparação com os testes caixa-branca, que envolvem uma análise rigorosa da lógica do código. É essencial selecionar um número limitado de caminhos lógicos importantes para rodar os testes. 

    //Existem várias abordagens para ambas as filosofias de teste. Para testes caixa-branca, temos o teste do caminho básico, que avalia todos os caminhos independentes no grafo de fluxo; o teste de condição, que exercita as condições lógicas; e o teste de ciclo, que avalia os ciclos no fluxo. Para testes caixa-preta, existem o particionamento de equivalência, que divide as entradas em classes de equivalência; a análise de valor limite, que avalia entradas nas fronteiras dos domínios; e o teste de interface, que testa os elementos da interface dos componentes desenvolvidos. 

    //Você será um assistente para auxiliar na elaboração de testes dos softwares dos alunos de uma disciplina de Engenharia de Software. PROIBIDO MAIS QUE 1 FUNÇÃO DE TESTE. PROIBIDO TUDO FORA DE TESTES. LIMITE DE 700 TOKENS NA RESPOSTA. Resposta em português do Brasil

    //  ''',
    // 'Refatoração': '''
    // Dada a seguinte descrição sobre refatoração:

    // Refatoração é o processo de modificar o código de software sem alterar seu comportamento externo, com o objetivo de melhorar sua estrutura interna. Durante o desenvolvimento de software, o design do código é continuamente aprimorado, e não em um único passo. À medida que novas alterações são feitas, a complexidade interna do software aumenta e sua qualidade diminui, podendo levar à necessidade de substituição do sistema. A refatoração estabiliza o deterioramento do software, permitindo sua manutenção contínua.

    // Existem vários tipos de refatoração, cada um aplicável a diferentes situações. A extração de método, por exemplo, envolve mover um trecho de código para um novo método, facilitando a reutilização e reduzindo a duplicação. Já o inline de método faz o oposto, removendo métodos com pouco reuso e inserindo seu código diretamente nos pontos de chamada. Outras técnicas incluem a movimentação de método para classes mais adequadas, extração de classes e interfaces a partir de classes grandes, e renomeação de elementos para melhorar a legibilidade.

    // Outras práticas de refatoração incluem a extração de variáveis para melhorar a legibilidade do código, remoção de flags substituindo variáveis de controle por comandos como break ou return, e substituição de condicionais por polimorfismo para reduzir o tamanho e complexidade do código. A remoção de código morto elimina trechos não utilizados, simplificando a manutenção. Essas técnicas visam tornar o código mais coeso, menos acoplado e mais fácil de entender e manter.

    // Você será um assistente para auxiliar com sugestões de refatoração do software dos alunos de uma disciplina de Engenharia de Software. Não gere código automaticamente, apenas faça sugestões ao aluno para que ele consiga desenvolver sozinho. Se for perguntado algo que não seja sobre Refatoração, responda que não é seu escopo.
    // ''',
  };

  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(minutes: 5), (Timer t) => _updateUserStatus());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateUserStatus() async {
    if (userId.isNotEmpty) {
      final response =
          await http.get(Uri.parse('$baseUrl/user-status/$userId'));
      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        lives.value = responseData['lives'];
        recoveryTime.value =
            Duration(seconds: responseData['recovery_time']?.round() ?? 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat App'),
        actions: [
          RxBuilder(
            builder: (_) {
              return Row(
                children: [
                  _buildLivesDisplay(),
                  SizedBox(width: 10),
                  Text(
                    'Vida Cheia em: ${_formatDuration(recoveryTime.value)}',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: RxBuilder(
          builder: (_) {
            if (isLoading.value) {
              return Center(child: CircularProgressIndicator());
            }
            return Row(
              children: [
                if (userId.isEmpty) Expanded(child: _buildLoginSection()),
                if (userId.isNotEmpty) _buildConversationsSection(),
                if (conversationId.isNotEmpty) _buildChatSection(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLivesDisplay() {
    return RxBuilder(
      builder: (_) => Row(
        children: List.generate(
          MAX_LIVES,
          (index) => Icon(
            index < lives.value ? Icons.favorite : Icons.favorite_border,
            color: index < lives.value ? Colors.red : Colors.grey,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes minutos';
  }

  String _formatDateTime(String dateTimeStr) {
    final DateTime dateTimeUtc = DateTime.parse(dateTimeStr).toUtc();
    final DateTime dateTimeBrasilia = dateTimeUtc.add(Duration(hours: -3));
    return DateFormat('dd/MM/yyyy, HH:mm').format(dateTimeBrasilia);
  }

  Widget _buildLoginSection() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(labelText: 'Email'),
          onChanged: (value) => email = value,
          onSubmitted: (_) => _login(),
        ),
        TextField(
          decoration: InputDecoration(labelText: 'Senha'),
          onChanged: (value) => password = value,
          obscureText: true,
          onSubmitted: (_) => _login(),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _login,
          child: Text('Login'),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RegisterScreen()),
            );
          },
          child: Text('Criar conta'),
        ),
      ],
    );
  }

  Widget _buildConversationsSection() {
    return Container(
      width: 300,
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _loadConversations,
            child: Text('Carregar Conversas'),
          ),
          SizedBox(height: 10),
          RxBuilder(
            builder: (_) {
              if (conversations.value.isEmpty) {
                return Center(
                    child: Text('Clique em Criar nova conversa para começar.'));
              }
              return Expanded(
                child: ListView.builder(
                  itemCount: conversations.value.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations.value[index];
                    return ListTile(
                      title: Text(
                          'Conversa ${conversation['conversation_number']}: ${conversation['theme']}'),
                      subtitle: Text(
                          'Data e Hora: ${_formatDateTime(conversation['timestamp'])}'),
                      onTap: () => _loadConversationPrompts(
                          conversation['conversation_id']),
                    );
                  },
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: _showThemeSelectionDialog,
            child: Text('Criar nova conversa'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Expanded(
      child: Column(
        children: [
          RxBuilder(
            builder: (_) {
              if (isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (prompts.value.isEmpty) {
                return Center(child: Text('Envie um prompt para começar.'));
              }

              return Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: prompts.value.length,
                  itemBuilder: (context, index) {
                    final prompt = prompts.value[index];
                    return _buildMessage(
                      'Eu: ${prompt['prompt'] ?? ''}',
                      prompt['response'] ?? '',
                      prompt['promptId'] ?? '',
                      prompt['liked_interaction'] ?? false,
                      prompt['disliked_interaction'] ?? false,
                    );
                  },
                ),
              );
            },
          ),
          if (isTyping.value)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text("Digitando..."),
                  SizedBox(width: 10),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.multiline,
            maxLines: null, // Permite múltiplas linhas
            decoration: InputDecoration(labelText: 'Nova Mensagem'),
            onChanged: (value) => newMessage.value = value,
          ),
          ElevatedButton(
            onPressed: isTyping.value ? null : _sendPrompt,
            child: Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String prompt, String response, String promptId,
      bool isLiked, bool isDisliked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(left: 40),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: _formatText(prompt),
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(right: 40),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(15),
              ),
              child: SelectableText.rich(
                TextSpan(
                  children: _formatText(response.isNotEmpty
                      ? response
                      : 'Aguardando resposta...'),
                ),
              ),
            ),
          ),
          if (response.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                    color: isLiked ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    _toggleLikePrompt(promptId, isLiked);
                  },
                ),
                Text(isLiked ? "Curtido" : "Curtir"),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(
                    isDisliked
                        ? Icons.thumb_down
                        : Icons.thumb_down_alt_outlined,
                    color: isDisliked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    _toggleDislikePrompt(promptId, isDisliked);
                  },
                ),
                Text(isDisliked ? "Não curtido" : "Não curtir"),
              ],
            ),
          Divider(),
        ],
      ),
    );
  }

  Future<void> _toggleLikePrompt(String promptId, bool isLiked) async {
    final response = await http.post(
      Uri.parse('$baseUrl/like-prompt/$promptId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final updatedPrompts = prompts.value.map((prompt) {
        if (prompt['promptId'] == promptId) {
          return {
            ...prompt,
            'liked_interaction': !isLiked,
            'disliked_interaction': false,
          };
        }
        return prompt;
      }).toList();

      prompts.value = updatedPrompts;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao curtir/descurtir a resposta.')),
      );
    }
  }

  Future<void> _toggleDislikePrompt(String promptId, bool isDisliked) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dislike-prompt/$promptId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final updatedPrompts = prompts.value.map((prompt) {
        if (prompt['promptId'] == promptId) {
          return {
            ...prompt,
            'disliked_interaction': !isDisliked,
            'liked_interaction': false,
          };
        }
        return prompt;
      }).toList();

      prompts.value = updatedPrompts;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao descurtir a resposta.')),
      );
    }
  }

  List<TextSpan> _formatText(String text) {
    List<TextSpan> spans = [];
    List<String> lines = text.split('\n');

    final headerPatterns = {
      r'^######\s+(.*)': TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      r'^#####\s+(.*)': TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      r'^####\s+(.*)': TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      r'^###\s+(.*)': TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      r'^##\s+(.*)': TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      r'^#\s+(.*)': TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    };

    final boldPattern = RegExp(r'\*\*(.*?)\*\*');

    for (var line in lines) {
      bool matched = false;

      for (var pattern in headerPatterns.keys) {
        final headerPattern = RegExp(pattern);
        final headerMatch = headerPattern.firstMatch(line);
        if (headerMatch != null) {
          spans.add(
            TextSpan(
              text: headerMatch.group(1)! + '\n',
              style: headerPatterns[pattern],
            ),
          );
          matched = true;
          break;
        }
      }

      if (!matched) {
        final matches = boldPattern.allMatches(line);
        int lastMatchEnd = 0;

        for (final match in matches) {
          if (match.start > lastMatchEnd) {
            spans
                .add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
          }

          spans.add(
            TextSpan(
              text: line.substring(match.start + 2, match.end - 2),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );

          lastMatchEnd = match.end;
        }

        if (lastMatchEnd < line.length) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd)));
        }

        spans.add(TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  Future<void> _login() async {
    isLoading.value = true;

    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    isLoading.value = false;

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      userId = responseData['user_id'];
      lives.value = responseData['lives'];
      _loadConversations();
    } else if (response.statusCode == 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuário ou senha incorretos')),
      );
    } else if (response.statusCode >= 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro no servidor, tente novamente mais tarde.')),
      );
    }
  }

  Future<void> _register() async {
    final response = await http.post(
      Uri.parse('$baseUrl/register/'),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuário registrado com sucesso')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao registrar usuário')),
      );
    }
  }

  Future<void> _loadConversations() async {
    isLoading.value = true;

    final response =
        await http.get(Uri.parse('$baseUrl/user-conversations/$userId'));

    isLoading.value = false;

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      conversations.value =
          List<Map<String, dynamic>>.from(responseData['conversations']);
    } else {
      print('Erro ao carregar conversas: ${response.body}');
    }
  }

  Future<void> _createNewConversation() async {
    if (selectedTheme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selecione um tema para a conversa')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/create-conversation/'),
      body: jsonEncode({
        'user_id': userId,
        'theme': selectedTheme,
        'system_prompt': themes[selectedTheme],
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      conversationId = responseData['conversation_id'];
      prompts.value = [];
      _loadConversations();
    } else {
      print('Erro ao criar conversa: ${response.body}');
    }
  }

  Future<void> _loadConversationPrompts(String convId) async {
    isLoading.value = true;
    prompts.value = [];

    try {
      final response =
          await http.get(Uri.parse('$baseUrl/conversation-prompts/$convId'));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        prompts.value = List<Map<String, dynamic>>.from(responseData['prompts'])
            .map((prompt) {
          return {
            ...prompt,
            'liked_interaction': prompt['liked_interaction'] ?? false,
            'disliked_interaction': prompt['disliked_interaction'] ?? false,
          };
        }).toList();
        conversationId = convId;
        _scrollToBottom();
      } else {
        print('Erro ao carregar prompts: ${response.body}');
      }
    } catch (e) {
      print('Erro ao carregar os prompts: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _sendPrompt() async {
    // Se o usuário tem 0 vidas, tenta atualizar o status
    if (lives.value == 0) {
      await _updateUserStatus(); // Tenta atualizar o status antes de continuar
    }

    // Após a tentativa de atualizar o status, verifica novamente as vidas
    if (lives.value == 0) {
      _showLivesAlert(); // Se ainda estiver com 0 vidas, mostra o alerta
      return;
    }

    isTyping.value = true;

    final newPrompt = {
      'prompt': newMessage.value.isNotEmpty ? newMessage.value : '',
      'response': '',
      'timestamp': DateTime.now().toString(),
      'promptId': DateTime.now().millisecondsSinceEpoch.toString(),
      'liked_interaction': false,
      'disliked_interaction': false,
    };

    // Adiciona o novo prompt à lista
    prompts.value = [...prompts.value, newPrompt];
    _controller.clear();
    newMessage.value = '';
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-prompt/'),
        body: jsonEncode({
          'user_id': userId,
          'conversation_id': conversationId,
          'prompt': newPrompt['prompt'],
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));

        // Processa a resposta normal
        await _loadConversationPrompts(conversationId);
        await _updateUserStatus(); // Atualiza novamente o status após o envio bem-sucedido
        _scrollToBottom();
      } else if (response.statusCode == 405) {
        // Exibe a notificação usando o ScaffoldMessenger para erro "405 Method Not Allowed"
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Desculpe, só posso responder perguntas relacionadas ao levantamento de requisitos de software ou testes de software."),
            backgroundColor: Colors.red,
          ),
        );

        // Remove o prompt que acabou de ser adicionado
        prompts.value = prompts.value
            .where((prompt) => prompt['promptId'] != newPrompt['promptId'])
            .toList();
      } else {
        print('Falha ao enviar o prompt: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar o prompt. Tente novamente mais tarde.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Erro ao processar a resposta da API: $e');
    } finally {
      isTyping.value = false;
    }
  }

  void _showLivesAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Sem Vidas Restantes"),
          content: Text(
              "Você está sem vidas. Aguarde para recuperar vidas antes de continuar."),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showThemeSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Selecione o tema da conversa"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButton<String>(
                value: selectedTheme.isNotEmpty ? selectedTheme : null,
                items: themes.keys.map((String theme) {
                  return DropdownMenuItem<String>(
                    value: theme,
                    child: Text(theme),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedTheme = newValue!;
                  });
                },
                hint: Text("Escolha um tema"),
              );
            },
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createNewConversation();
              },
              child: Text("Confirmar"),
            ),
          ],
        );
      },
    );
  }
}
