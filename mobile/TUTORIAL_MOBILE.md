# Guia do Desenvolvedor: Aplicativo Mobile (Flutter)

O **Flutter** é o framework da Google para desenvolvimento de aplicativos multiplataforma (Android, iOS, Web, Desktop) usando a linguagem **Dart**. Em Flutter, **quase tudo é um Widget** (componentes visuais ou estruturais, como botões, textos e layouts).

---

## 📁 Estrutura da Pasta `mobile/`

```text
mobile/
├── pubspec.yaml              # Configuração de dependências, pacotes e assets
├── lib/                      # Onde fica todo o código-fonte (em Dart)
│   ├── main.dart             # Ponto de entrada (executa runApp)
│   ├── app.dart              # Configuração global (Rotas, MaterialApp, Tema)
│   ├── core/                 # Núcleo compartilhado
│   │   ├── services/         # Comunicação com API (ApiClient)
│   │   ├── storage/          # Armazenamento local (SharedPreferences)
│   │   ├── theme/            # Cores e tema visual (AppTheme / AppColors)
│   │   └── widgets/          # Estados reutilizáveis (Loading, Error, Empty)
│   └── features/             # Módulos / Telas da aplicação
│       ├── auth/             # Tela de Login
│       ├── home/             # Tela principal com abas (Bens, Setores, etc.)
│       ├── server_config/    # Configuração do IP do servidor backend
│       └── splash/           # Tela inicial de abertura
├── android/                  # Código nativo Android (Gradle, Manifest)
├── ios/                      # Código iOS (Xcode, Info.plist)
└── test/                     # Testes automatizados
```

---

## 🔍 Detalhes de cada parte:

1. **`pubspec.yaml`**
   - É o "coração" das dependências do Flutter. É aqui que você declara pacotes externos (como `http` para requisições e `shared_preferences` para salvar dados no celular), fontes e imagens.

2. **`lib/main.dart`**
   - O arquivo que o Flutter executa primeiro quando você abre o app. Ele inicializa os bindings e chama o widget raiz.

3. **`lib/app.dart`**
   - Define o `MaterialApp`. É aqui que configuramos o título do app, o tema global (`AppTheme`), a rota inicial e o mapa de rotas (`routes`) para navegar entre as telas.

4. **`lib/core/` (O Núcleo)**
   - **`services/api_client.dart`**: Responsável por fazer as requisições HTTP (`GET`, `POST`, etc.) para o backend FastAPI e converter o JSON do banco de dados para objetos Dart.
   - **`storage/server_config_storage.dart`**: Salva e lê a URL do servidor backend no armazenamento interno do celular usando `SharedPreferences`.
   - **`theme/app_theme.dart`**: Define a identidade visual (cores como o roxo `#820AD1`, fontes, botões e cartões).
   - **`widgets/app_states.dart`**: Componentes padronizados para estados como "Carregando...", "Erro de Conexão" ou "Lista Vazia".

5. **`lib/features/` (As Funcionalidades / Telas)**
   - Cada pasta aqui representa uma funcionalidade independente:
     - **`splash/`**: Verifica ao abrir se há uma URL de servidor salva e direciona para o login ou configuração.
     - **`auth/`**: Tela onde o usuário insere as credenciais para entrar.
     - **`server_config/`**: Tela para digitar o IP do computador (ex: `http://10.0.0.22:8000`) e testar a conexão com o backend.
     - **`home/`**: A tela principal pós-login, contendo as abas de listagem (Bens, Categorias, Setores, Responsáveis, Movimentações) conectadas diretamente ao banco de dados via API.

6. **Pastas Nativas (`android/` e `ios/`)**
   - Contêm as configurações específicas de cada sistema operacional (permissões de internet, ícones, splash screen nativa e arquivos de build do Gradle/Xcode).
