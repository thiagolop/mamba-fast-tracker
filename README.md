# Mamba Fast Tracker

App Flutter focado em controle de jejum intermitente e calorias, com autenticação, persistência local e notificações.

## Como rodar o projeto
1. Instale o Flutter (SDK >= 3.10) e configure o ambiente.
2. Configure o Firebase:
   - Rode `flutterfire configure` para gerar `lib/firebase_options.dart`.
3. Instale as dependências:
   - `flutter pub get`
4. Execute:
   - `flutter run`

Notas:
- iOS: garanta `iOS Deployment Target >= 15.0` e rode `cd ios && pod install` após configurar o Firebase.

## Stack escolhida
- Flutter (Material 3)
- Firebase Auth (email/senha)
- Hive CE (persistência local)
- Riverpod (Notifier/Provider)
- GoRouter (navegação)
- flutter_local_notifications + timezone
- fl_chart (gráficos)
- Google Fonts (tipografia)

## Dark mode
- Segue o sistema (`ThemeMode.system`) com tema claro/escuro (Material 3).

## Arquitetura utilizada
Estrutura por feature + core compartilhado:
- `lib/core/`: storage, router, theme, time, notifications, ui messages
- `lib/features/auth/`: autenticação
- `lib/features/fasting/`: jejum (domínio + engine + controller)
- `lib/features/meals/`: refeições (CRUD local)
- `lib/features/dashboard/`: resumo diário + gráfico semanal
- `lib/features/history/`: histórico por dia

Princípios:
- UI “burra” (apenas renderiza estado e dispara ações)
- Controllers concentram regras e formatos prontos para a UI
- Persistência isolada em repositories

## Decisões técnicas
- Jejum baseado em timestamps persistidos (sem contagem em memória).
- Persistência local com Hive, key por `userId` para separar dados.
- Cálculo de métricas (calorias, jejum diário, progresso) centralizado nos controllers.
- Mensageria de UI unificada via `UiMessage` e listener global.
- Fallbacks de leitura em adapters para evitar quebra em dados antigos.

## Bibliotecas utilizadas
Principais dependências do projeto:
- `firebase_core`, `firebase_auth`, `firebase_messaging`
- `hive_ce`, `hive_ce_flutter`
- `flutter_local_notifications`, `timezone`
- `flutter_riverpod`
- `go_router`
- `fl_chart`
- `google_fonts`
- `equatable`, `uuid`, `intl`

## Trade-offs considerados
- Gráfico semanal usa calorias (mais direto) ao invés de tempo de jejum.
- Cálculo de jejum diário considera a interseção da sessão com o dia; sem histórico remoto.
- Persistência local (sem sync cloud) para simplificar o MVP.
- UI simplificada, priorizando clareza e legibilidade.
- Exact alarms no Android 12+ podem depender da permissão do sistema.

## O que melhoraria com mais tempo
- Testes de unidade e integração (controllers, repositories, router).
- Sync opcional com backend (cloud).
- Metas configuráveis pelo usuário (calorias/jejum).
- Melhorias de acessibilidade e estados offline.
- Analytics/telemetria para insights de uso.

## Tempo gasto no desafio
- `16 horas`

## Como rodar testes
- `flutter test`

## CI: GitHub Actions
- Pipeline simples com `flutter analyze` e `flutter test` em push/PR.

## Como gerar APK
1. `flutter clean && flutter pub get`
2. `flutter build apk --release`
3. Saída: `build/app/outputs/flutter-apk/app-release.apk`

## Notas Android (permissões)
- `POST_NOTIFICATIONS` (Android 13+)
- `SCHEDULE_EXACT_ALARM` (Android 12+)
- O app solicita permissão de notificações no runtime via plugin.

## Link para executar o projeto
- https://docs.flutter.dev/get-started/install
- https://docs.flutter.dev/cookbook/installation/run
