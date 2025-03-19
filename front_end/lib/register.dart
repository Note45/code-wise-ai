import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _enrollmentController = TextEditingController();

  String selectedExpertiseLevel =
      ''; // Armazena o nível de experiência selecionado
  bool isLoading = false;

  // Base URL do backend
  String baseUrl = 'http://localhost:8000'; // Substitua pelo seu backend
  //String baseUrl = 'https://sistema-engsoft-65e29175f699.herokuapp.com';

  // Função para realizar o cadastro do usuário
  Future<void> _registerUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String enrollment = _enrollmentController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        enrollment.isEmpty ||
        selectedExpertiseLevel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Faz a requisição POST para cadastrar o usuário
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'enrollment': enrollment,
          'expertise_level': selectedExpertiseLevel,
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        // Sucesso no cadastro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuário registrado com sucesso')),
        );
        Navigator.pop(context); // Volta para a tela de login
      } else {
        // Exibe o erro retornado pelo backend
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${responseData['detail']}')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao registrar usuário. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cadastro de Usuário'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Campo de Email
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 10),
                  // Campo de Senha
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                  ),
                  SizedBox(height: 10),
                  // Campo de Matrícula
                  TextField(
                    controller: _enrollmentController,
                    decoration: InputDecoration(labelText: 'Matrícula'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 10),
                  // Dropdown para escolher o nível de experiência
                  DropdownButtonFormField<String>(
                    decoration:
                        InputDecoration(labelText: 'Nível de Experiência'),
                    value: selectedExpertiseLevel.isNotEmpty
                        ? selectedExpertiseLevel
                        : null,
                    items: [
                      DropdownMenuItem(
                        child: Text("APENAS_ESTUDANTE"),
                        value: "APENAS_ESTUDANTE",
                      ),
                      DropdownMenuItem(
                        child: Text("ESTAGIÁRIO"),
                        value: "ESTAGIÁRIO",
                      ),
                      DropdownMenuItem(
                        child: Text("PROFISSIONAL"),
                        value: "PROFISSIONAL",
                      ),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedExpertiseLevel = newValue!;
                      });
                    },
                    hint: Text("Selecione o nível de experiência"),
                  ),
                  SizedBox(height: 20),
                  // Botão de cadastro
                  ElevatedButton(
                    onPressed: _registerUser,
                    child: Text('Cadastrar'),
                  ),
                ],
              ),
      ),
    );
  }
}
