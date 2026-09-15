# PatriFlow Mobile

Base Flutter do PatriFlow. Ela funciona sem a API: guarda no aparelho a URL base do servidor e deixa a navegação preparada para login e perfis.

## Executar

```bash
flutter pub get
flutter run
```

## Endereço do servidor

Informe somente a origem, sem `/api/v1`, por exemplo `http://192.168.0.10:8000`.

- Emulador Android: `http://10.0.2.2:8000` para acessar a API no computador anfitrião.
- Celular físico: o IP local da máquina que executa o Uvicorn, como `http://192.168.0.10:8000`.

As futuras chamadas usarão `{endereco}/api/v1/...` por meio de `ServerConfigStorage.apiV1Url`.
