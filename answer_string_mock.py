answer_mock = """
### Casos de Uso:

#### Caso de Uso 1: Realizar Busca por Livros
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário encontre livros na biblioteca usando diferentes critérios.
- **Fluxo Principal:**
  1. O usuário acessa o sistema de gerenciamento da biblioteca.
  2. O usuário seleciona a opção de busca.
  3. O sistema solicita os critérios de busca (título, autor, gênero, etc.).
  4. O usuário insere os critérios de busca e confirma.
  5. O sistema exibe a lista de livros que correspondem aos critérios inseridos.
- **Extensões:**
  - 3a. O usuário pode optar por realizar uma busca avançada, adicionando mais critérios.
  - 5a. Se nenhum livro for encontrado, o sistema exibe uma mensagem informando que não há livros que correspondam aos critérios de busca.

#### Caso de Uso 2: Visualizar Detalhes dos Livros
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário veja informações detalhadas sobre um livro específico.
- **Fluxo Principal:**
  1. O usuário encontra um livro na lista de resultados de busca.
  2. O usuário seleciona o livro para ver mais detalhes.
  3. O sistema exibe as informações detalhadas do livro, incluindo sinopse, disponibilidade e localização.
- **Extensões:**
  - Nenhuma.

#### Caso de Uso 3: Reservar Livro
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário reserve um livro que está atualmente emprestado.
- **Fluxo Principal:**
  1. O usuário acessa a página de detalhes do livro.
  2. O usuário seleciona a opção de reservar o livro.
  3. O sistema registra a reserva e confirma ao usuário.
  4. O sistema envia uma notificação ao usuário quando o livro estiver disponível.
- **Extensões:**
  - 3a. Se o livro já estiver reservado pelo próprio usuário, o sistema informa que a reserva já está ativa.
  - 3b. Se o número máximo de reservas foi atingido, o sistema informa ao usuário.

#### Caso de Uso 4: Emprestar Livro
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário realize o empréstimo de um livro disponível.
- **Fluxo Principal:**
  1. O usuário acessa a página de detalhes do livro.
  2. O usuário seleciona a opção de emprestar o livro.
  3. O sistema confirma a disponibilidade do livro.
  4. O sistema processa o empréstimo e atualiza a disponibilidade do livro.
  5. O sistema confirma o empréstimo ao usuário.
- **Extensões:**
  - 3a. Se o livro já estiver emprestado, o sistema informa que o empréstimo não pode ser realizado.
  - 4a. Se o usuário já emprestou o número máximo de livros permitido, o sistema informa que o empréstimo não pode ser realizado.

#### Caso de Uso 5: Renovar Empréstimo de Livro
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário renove o prazo de empréstimo de um livro.
- **Fluxo Principal:**
  1. O usuário acessa a sua página de empréstimos.
  2. O usuário seleciona o livro que deseja renovar.
  3. O sistema verifica se não há reservas para o livro.
  4. O sistema estende o prazo de empréstimo.
  5. O sistema confirma a renovação ao usuário.
- **Extensões:**
  - 3a. Se o livro tiver reservas, o sistema informa que a renovação não é permitida.

#### Caso de Uso 6: Cancelar Reserva ou Empréstimo
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário cancele uma reserva ou empréstimo.
- **Fluxo Principal:**
  1. O usuário acessa a página de reservas ou de empréstimos.
  2. O usuário seleciona a reserva ou empréstimo que deseja cancelar.
  3. O sistema processa o cancelamento e atualiza o status do livro.
  4. O sistema confirma o cancelamento ao usuário.
- **Extensões:**
  - Nenhuma.

#### Caso de Uso 7: Visualizar Histórico de Empréstimos e Reservas
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário veja o histórico de todas as suas transações na biblioteca.
- **Fluxo Principal:**
  1. O usuário acessa a sua página de histórico.
  2. O sistema exibe a lista de todos os empréstimos e reservas passados e presentes.
- **Extensões:**
  - Nenhuma.

#### Caso de Uso 8: Alterar Informações de Contato
- **Ator:** Usuário
- **Objetivo:** Permitir que o usuário atualize suas informações de contato.
- **Fluxo Principal:**
  1. O usuário acessa a sua página de perfil.
  2. O usuário seleciona a opção de editar informações de contato.
  3. O usuário insere as novas informações e confirma.
  4. O sistema atualiza as informações de contato.
  5. O sistema confirma a alteração ao usuário.
- **Extensões:**
  - 3a. Se os dados inseridos forem inválidos, o sistema exibe uma mensagem de erro e solicita a correção.

Esses casos de uso foram elaborados para cobrir os principais processos envolvidos no sistema de gerenciamento de uma biblioteca, garantindo uma experiência completa e eficiente para os usuários e funcionários seguidores.
"""