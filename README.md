# Mamba Fast Tracker

App Flutter para controle de jejum intermitente e calorias, com autenticação, persistência local e notificações.

## Screenshot(s)
<img width="1536" height="1024" alt="ChatGPT Image 11 de fev  de 2026, 11_34_00" src="https://github.com/user-attachments/assets/a32b109e-cc71-47b2-be1b-6b1a661217b5" />


## Features implementadas
### MVP
- Login com Firebase Auth (email/senha)
- Protocolos de jejum (seleção + persistência)
- Timer de jejum baseado em timestamps (sem contagem em memória)
- Notificações locais (início/fim) e FCM configurado
- CRUD de refeições com calorias (local)
- Dashboard “Hoje” (calorias + jejum)
- Histórico de dias com detalhe
- Gráfico semanal (fl_chart)

### Polimentos
- UI refinada e consistente (Material 3)
- Dark mode (segue sistema + toggle no app)
- Componentização de widgets
- Feedback via UiMessage (SnackBar)
- Tema centralizado (AppTheme)

## Arquitetura utilizada
Arquitetura por **feature** com separação clara entre `presentation`, `domain` e `data`, além de um `core` para serviços compartilhados.

Motivos:
- Facilita manutenção e crescimento por módulos
- Isola regras de negócio (controllers/domain)
- UI fica “burra” e mais simples de testar

## Estrutura de pastas por feature
```
lib/
  core/
    notifications/
    router/
    storage/
    theme/
    time/
    ui/
  features/
    auth/
      data/
      domain/
      presentation/
    fasting/
      data/
      domain/
      presentation/
    meals/
      data/
      domain/
      presentation/
    dashboard/
      domain/
      presentation/
    history/
      data/
      domain/
      presentation/
```

## Stack escolhida
- Flutter (Material 3)
- Firebase (Auth + Messaging)
- Hive (persistência local)
- Riverpod (state management)
- GoRouter (navegação)
- fl_chart (gráficos)

## Bibliotecas utilizadas
- `firebase_core`, `firebase_auth`, `firebase_messaging`
- `hive_ce`, `hive_ce_flutter`
- `flutter_riverpod`
- `go_router`
- `flutter_local_notifications`, `timezone`
- `fl_chart`
- `google_fonts`
- `equatable`, `uuid`, `intl`

## Como rodar o projeto
### Requisitos
- Flutter SDK >= 3.10
- Firebase configurado (via FlutterFire)
- Xcode / Android Studio configurados

### Comandos
```bash
flutter pub get
flutterfire configure
flutter run
```

## Configuração Android / iOS
### Android
Em `android/app/src/main/AndroidManifest.xml`:
- `POST_NOTIFICATIONS` (Android 13+)
- `SCHEDULE_EXACT_ALARM` (Android 12+)

O app solicita permissão de notificação no runtime via `flutter_local_notifications`.

### iOS
- `iOS Deployment Target >= 15.0`
- Permissões locais configuradas via `DarwinInitializationSettings`
- Push notifications via FCM (Firebase Messaging)

## Funcionalidades do desafio e como foram atendidas
- **Login (Firebase Auth)**: login/cadastro com validação no controller.
- **Protocolos de jejum**: seleção persistida em Hive.
- **Timer persistido**: timestamps salvos e recalculados a cada tick.
- **Notificações locais + FCM**: início/fim de jejum + suporte FCM.
- **Refeições CRUD**: criar/editar/excluir refeições locais por userId.
- **Cálculo diário**: total de calorias e tempo de jejum do dia.
- **Histórico**: lista de últimos dias + detalhe com refeições.
- **Gráfico semanal**: barras com `fl_chart` (calorias).

## Persistência de dados (Hive)
- `fasting_sessions`: sessões (inclui encerradas)
- `fasting_protocols`: protocolos padrão
- `meals`: refeições por userId
- `settings`: preferências (theme, sessão ativa, token FCM)

## UI/UX refinado
- **Dark Mode** com `ThemeMode.system` + toggle
- UI “burra”: sem lógica de regras em widgets
- Componentização (`widgets/` por feature)
- Feedback via `UiMessage` e listener global

## Testes
- Unit tests em `test/`:
  - `fasting_session_test.dart` (elapsed/remaining)
  - `calories_aggregator_test.dart` (totais por dia)
  - `weekly_chart_service_test.dart` (7 pontos)

Rodar:
```bash
flutter test
```

## CI/CD
GitHub Actions configurado em `.github/workflows/flutter.yml`:
- `flutter pub get`
- `flutter analyze`
- `flutter test`

Rodar localmente:
```bash
flutter analyze
flutter test
```

## Build Android
```bash
flutter clean && flutter pub get
flutter build apk --release
```
Saída:
```
build/app/outputs/flutter-apk/app-release.apk
```

Para AAB:
```bash
flutter build appbundle --release
```

## Decisões técnicas
- Timestamps como fonte de verdade do jejum (confiável com app fechado).
- Persistência local via Hive para simplicidade e performance offline.
- UI “burra” com regras no controller/domain.
- Arquitetura por feature para facilitar evolução modular.

## Trade-offs considerados
- Gráfico semanal focado em calorias (mais direto para o MVP).
- Persistência local sem sync remoto.
- Sem analytics/crashlytics.

## O que melhoraria com mais tempo
- Mais testes automatizados (widgets + integração)
- Feature flags e experimentos
- Analytics + Crashlytics
- Fluxo de distribuição no Play Console (internal test)

## Tempo gasto no desafio
- **16 horas**

## Possíveis melhorias futuras
- Metas configuráveis pelo usuário
- Exportação de dados
- Cloud sync opcional
- Widgets/Shortcuts
