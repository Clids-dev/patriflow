# PatriFlow Mobile

Aplicativo Flutter do PatriFlow com login na API, sessão persistida em armazenamento seguro e menus adaptados ao perfil autenticado.

## Executar

```bash
flutter pub get
flutter run
```

## Endereço do servidor

Informe somente a origem, sem `/api/v1`, por exemplo `http://192.168.0.10:8000`.

- Emulador Android: `http://10.0.2.2:8000` para acessar a API no computador anfitrião.
- Celular físico: o IP local da máquina que executa o Uvicorn, como `http://192.168.0.10:8000`.

As chamadas usam `{endereco}/api/v1/...` por meio de `ServerConfigStorage.apiV1Url`.

## Autenticação e sessão

- O login envia `username` e `senha` para `POST /api/v1/auth/login`; em seguida, consulta `GET /api/v1/auth/me` para obter nome, perfil e setor.
- O token é guardado com `flutter_secure_storage` (Android Keystore e iOS Keychain). `SharedPreferences` guarda somente o endereço do servidor.
- As chamadas autenticadas passam pelo `ApiClient`, que inclui `Authorization: Bearer <token>`. Na inicialização, o app valida a sessão consultando `/auth/me` antes de abrir a tela inicial.
- Uma resposta HTTP 401 apaga somente o token, avisa que a sessão expirou e encaminha para o login. Essa operação não limpa nem altera a fila local de sincronização.
- Os menus disponíveis são montados a partir do campo `perfil` retornado pela API. Ocultar botões é uma conveniência de interface; a autorização de cada operação é sempre validada pela API.

## Menus por perfil

- `agente_campo`: Leitura, Conferência, Movimentação, Inventário e Sincronização.
- `responsavel_setor`: Transferências Pendentes e Acervo sob sua guarda.
- `setor_patrimonio`: Consulta e Histórico.

## Área do setor de patrimônio

O perfil `setor_patrimonio` abre o painel administrativo mobile, com visão geral, pesquisa e filtro de bens, cadastro/edição/baixa/reativação, detalhes e histórico, manutenção de categorias e responsáveis, gestão de setores e da hierarquia prédio/andar/sala, transferências e exportação de relatórios PDF ou Excel pelo menu de compartilhamento do aparelho. As ações usam os endpoints autenticados da API.
