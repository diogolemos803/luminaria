# Luminária Circadiana NFC

App iOS (Swift/SwiftUI) que vincula o iPhone a uma luminária física via NFC. Uma única
tela com um botão redondo central arma/desarma o "modo noite" (Living mode / Zleepy
mode). Quando a luminária é reconhecida via NFC com o modo noite armado, o app dispara
um Atalho de Foco ("Dormir sem celular") e um despertador nativo próprio, usando a
rotina de sono marcada como ativa.

Desenvolvido inteiramente num PC Windows, sem Mac disponível — todo compile/teste real
depende de CI num runner macOS na nuvem (GitHub Actions) e de sideload via AltStore.

## Arquitetura

- `Luminaria/LuminariaApp.swift` — entry point do SwiftUI App lifecycle, com um
  `AppDelegate` mínimo (`@UIApplicationDelegateAdaptor`) cuja única função é registrar
  `AlarmManager.shared` como delegate de `UNUserNotificationCenter` já no lançamento —
  necessário pro caso do processo ser relançado do zero pelo toque na notificação do
  despertador (o `.onAppear` da SwiftUI roda tarde demais pra esse caso).
- `Luminaria/ContentView.swift` — tela única: botão redondo central que arma/desarma o
  modo noite (fundo claro/chumbo, ícone acordado/dormindo, texto "Living mode"/"Zleepy
  mode"). Menu no canto superior direito (`SettingsView`) concentra: vincular/desvincular
  NFC, gerenciar rotinas de sono (`SleepRoutinesView`), e um botão único "Ajuda"
  (`HelpView`) com as instruções de configuração. Também define `AlarmRingingView` (tela
  cheia mostrada quando o despertador está tocando).
- `Luminaria/NFCManager.swift` — leitura NDEF via `CoreNFC` (`NFCNDEFReaderSession`).
  Salva o UID da primeira tag lida (vínculo) e reconhece a mesma tag depois. Sessão só
  fica ativa quando chamada explicitamente (`beginScanning()`), nunca em segundo plano.
- `Luminaria/ShortcutManager.swift` — dispara o Atalho via
  `shortcuts://x-callback-url/run-shortcut` (com `x-success`/`x-error` apontando pro
  esquema custom `luminaria://`, registrado no `Info.plist`), evitando abrir o app
  Atalhos por completo. Só cuida de Foco + Modo Noturno — o despertador NÃO passa mais
  por aqui (ver `AlarmManager.swift`).
- `Luminaria/AlarmManager.swift` — despertador **nativo do próprio app**, sem depender do
  Atalhos nem do app Relógio. Singleton (`AlarmManager.shared`) que conforma
  `UNUserNotificationCenterDelegate`: reage imediatamente à entrega/toque da notificação
  de alarme (em vez de depender só de um `Timer` de 15s, que exige o processo vivo).
  Persiste o estado armado (hora, minuto, som escolhido) em `UserDefaults`, restaurado no
  `init()` — cobre o caso do iOS matar e relançar o processo pelo toque na notificação.
  Toca um áudio quase inaudível em loop contínuo enquanto armado (mantém o app vivo em
  segundo plano via `UIBackgroundModes: audio`); ao bater o horário, troca pelo som
  escolhido na rotina ativa, em loop, até a pessoa abrir o app e tocar "Parar". A
  notificação local de reforço usa esse MESMO som customizado (antes usava o som padrão
  do sistema) — é ela quem garante o alarme mesmo com o processo suspenso, já que quem a
  dispara e toca o som é o próprio iOS.
- `Luminaria/SleepRoutineStore.swift` — `AlarmSoundOption` (enum com os 4 sons
  disponíveis), `SleepRoutine` (nome + horário do despertador + horário de desligar Modo
  Noturno + som escolhido) e `SleepRoutineStore` (`ObservableObject`, lista dinâmica de
  rotinas persistida como JSON no `UserDefaults`, com `activeRoutineID` marcando qual
  está em uso). Migra automaticamente, na primeira execução após essa mudança, os
  valores antigos soltos em `@AppStorage` (`alarmHour` etc.) pra uma rotina "Minha
  rotina", preservando o que o usuário já tinha configurado.
- `Luminaria/SleepRoutinesView.swift` — `SleepRoutinesView` (lista de rotinas: ativar,
  excluir, criar) e `RoutineEditView` (nome, horários, escolha de som com botão
  "Testar" pra ouvir a prévia sem precisar armar nada).
- `Luminaria/HelpView.swift` — instruções de configuração do Atalho "Dormir sem celular"
  (antes era `ShortcutSetupView`, embutida em `ContentView.swift`) + o passo a passo de
  "desligar Modo Noturno de manhã" + um checklist novo pra quando o despertador não
  aparece na tela bloqueada (Ajustes → Notificações e Ajustes → Foco do iPhone).
- `Luminaria/AppTheme.swift` — `ModeTheme` (paleta por modo: cream/branco no Living mode,
  chumbo no Zleepy mode, acento âmbar de luminária acesa vs. periwinkle de luar) e os
  componentes reutilizáveis (`ThemedCard`, `ThemedRow`, `IconBadge`, `ActiveDot`,
  `FullPillButton`, `GhostDangerButton`) usados por `SettingsView`, `SleepRoutinesView` e
  `HelpView` pra parecerem parte do mesmo app do botão redondo, não o Ajustes do iPhone.
  Também define a `EnvironmentKey` `isNightModeArmed`, que propaga se o modo noite está
  armado pras telas secundárias sem precisar passar o bool por parâmetro em cada `init`
  — setada uma vez no `.sheet`/`.environment` de `ContentView`. **O botão redondo e o
  texto "Living mode"/"Zleepy mode" da tela principal não usam nada disso** — ficam
  exatamente como estavam antes, por pedido explícito do usuário (é a identidade da
  marca, não deve mudar).
- `Luminaria/LockedView.swift` (só no `main`) — tela mostrada por `ContentView` no
  lugar do botão redondo enquanto `!nfcManager.isLinked`. Pedido explícito do usuário:
  o app não deve fazer nada de útil (armar modo noite, bloquear apps) sem uma
  luminária física de verdade vinculada. Não mexe no `NavigationStack`/toolbar — o
  menu ☰ continua abrindo `SettingsView` normalmente, que é onde o vínculo também
  pode ser feito/desfeito (um único caminho de código pra vincular, não dois).
- `Luminaria/ScreenTimeManager.swift` (só no `main`) — bloqueia apps/categorias/sites
  escolhidos pelo usuário enquanto o modo noite estiver ativo, usando a Screen Time
  API da Apple (`FamilyControls`/`ManagedSettings`) — a mesma base que apps como
  Brick/Opal usam. Singleton (`ScreenTimeManager.shared`) no mesmo estilo do
  `AlarmManager`: `@Published var selection: FamilyActivitySelection` (persistida
  como JSON — o tipo já é `Codable` nativamente) e `@Published private(set) var
  isShieldActive` **persistido e restaurado no `init()`**, exatamente como o estado
  armado do `AlarmManager` — sem isso, se o processo morresse com o bloqueio ativo (o
  `ManagedSettingsStore` continua valendo mesmo com o app fechado), o app reabriria
  mostrando "Living mode" com os apps ainda travados e nenhum caminho de código pra
  desarmar. `applyShield()`/`removeShield()` chamados no mesmo instante em que o
  Atalho e o despertador já disparam/desarmam (`onRecognizedTap` e o ramo de desarmar
  de `toggleNightMode()`), reaproveitando o ciclo de vida existente em vez de inventar
  um padrão de interação novo. Por privacidade, o app NUNCA sabe quais apps foram
  escolhidos — só tokens opacos (dá pra saber quantos, não quais).
- `Luminaria/AppBlockingView.swift` (só no `main`) — apresenta o `FamilyActivityPicker`
  do sistema (via `.familyActivityPicker(isPresented:selection:)`), chip de status de
  autorização (mesmo padrão do status de notificação em `HelpView`), acessível via
  `NavigationLink` de dentro de `SettingsView` (mesmo padrão de `SleepRoutinesView` —
  não `.sheet`, pra não reintroduzir a classe de bug que o `fullScreenCover` do
  despertador já teve com apresentações modais concorrentes).
- `Luminaria/SleepReportStore.swift` / `SleepReportView.swift` (só no `main`) — mesmo
  padrão de `SleepRoutineStore`: histórico de sessões de bloqueio (`SleepReportEntry`:
  data, quantidade de apps, duração), persistido como JSON no `UserDefaults`, gravado
  por `ScreenTimeManager.removeShield()` ao desarmar. **Não guarda contagem de
  notificações/ligações bloqueadas** — isso não é tecnicamente possível (ver Decisões
  abaixo) — só o que dá pra medir de verdade: quantos apps ficaram bloqueados e por
  quanto tempo.
- `Luminaria/silence_loop.wav` / `Luminaria/alarm_tone.wav` — sons originais (sirene
  clássica), gerados programaticamente. `Luminaria/alarm_alvorada.wav` — tom puro
  (arpejo pentatônico ascendente), mantido. `Luminaria/alarm_ondas.wav` /
  `alarm_chuva.wav` / `alarm_passaros.wav` — sons de natureza (ondas do mar, chuva,
  passarinhos ao amanhecer), sintetizados a partir de **ruído branco filtrado** (não
  tons puros) pra soar mais parecido com gravação de verdade — a mesma técnica que
  concorrentes de despertador confortável (Sleep Cycle, Pillow etc.) usam de verdade
  pra esse tipo de som — e normalizados bem mais alto (~85-92% do pico) que os tons
  calmos anteriores, pra funcionar de verdade como despertador. Substituíram
  `alarm_carrilhao.wav`/`alarm_respiracao.wav` (removidos), que eram tons puros demais
  e não convenciam como "som de acordar". Todos 16-bit PCM mono 44.1kHz, gerados por
  `scripts/generate_alarm_sounds.ps1` (PowerShell + .NET — ver decisão abaixo sobre por
  que não é mais um script Python, e sobre por que não são gravações baixadas).
- `Luminaria/Assets.xcassets` — `LogoAcordado`/`LogoSono`, PNGs com transparência real,
  recolorido (cinza escuro/cinza claro em vez de preto/branco puro) e recortado rente ao
  desenho. Os originais brutos ficam em `Assets/` na raiz (fora do git, só staging local).
  `AppIcon` (só no `main`) — ícone da App Store, 1024×1024 sem canal alfa (exigência da
  Apple), gerado por `scripts/generate_app_icon.ps1`: `LogoAcordado` centralizado num
  círculo branco sobre fundo cream, imitando o botão principal em miniatura. É
  provisório — feito só pra não travar o primeiro build no Codemagic/TestFlight,
  substituir por um ícone de verdade quando houver um definido.
- `design/luminaria_prototipo.html` — protótipo HTML aprovado do botão, referência visual
  do checkpoint (`v1`). Não é o app de verdade, é só pra revisar visual sem precisar de
  Mac — publicado também como Artifact no claude.ai durante o desenvolvimento.
- `.github/workflows/build.yml` — roda em todo push **pra `main`** (e PRs pra `main`),
  compila pra device real sem assinatura (`-sdk iphoneos -destination
  'generic/platform=iOS'`, mesma receita do `sideload-ipa.yml`). Não dispara sozinho na
  branch `teste-gratis-sem-nfc` — precisa rodar manualmente ("Run workflow") quando for
  validar uma mudança feita só nela. **Trocado de Simulador pra device em 2026-08-05**:
  `FamilyControls`/`ManagedSettings` só funcionam de verdade em device físico — a
  compilação em si (ver Decisões abaixo) acabou quebrando por outro motivo (import
  faltando), mas o destino ficou em device de qualquer forma por refletir melhor a
  plataforma real de uso.
- `.github/workflows/release.yml` — disparo manual, archive + upload TestFlight. Só
  funciona depois de configurar secrets (certificado, provisioning profile, API key da
  App Store Connect) e trocar o Team ID em `ExportOptions.plist`. Ainda não usado — exige
  conta paga que o usuário decidiu adiar.
- `codemagic.yaml` (só no `main`) — caminho alternativo ao `release.yml` pra publicar no
  TestFlight, usando Codemagic.io em vez de GitHub Actions. Diferente do `release.yml`
  (certificado/profile manuais via secrets), o Codemagic gera e renova sozinho o
  certificado e o provisioning profile a partir de uma App Store Connect API Key
  cadastrada na conta do Codemagic — não precisa de Mac nem de Keychain em momento
  nenhum. Builds são só manuais (sem gatilho automático em push) de propósito: com
  pushes frequentes na `main`, disparar builds a cada push gastaria minutos do
  Codemagic à toa e mandaria uma build nova pros testadores toda hora.
  **2026-08-05**: App ID `com.luminaria.app` registrado em developer.apple.com (NFC Tag
  Reading habilitado) e app "Zleepy Lamp" criado no App Store Connect (Apple ID numérico
  `6798370889`, já preenchido em `APP_STORE_APPLE_ID`), com grupo de teste interno do
  TestFlight chamado `Interno` (nome real usado no `beta_groups`, não o "Testadores
  Internos" genérico do exemplo original). Falta só: pedir o acesso à capability `Family
  Controls` (Capability Requests do App ID, aprovação manual sem prazo fixo) e cadastrar
  a chave `LuminariaAppStoreKey` na conta do Codemagic (Team settings → Integrations →
  App Store Connect) pra rodar o primeiro build de verdade.

## As duas branches

### `main`
Versão completa, com a entitlement de NFC (`com.apple.developer.nfc.readersession.formats`)
declarada em `Luminaria.entitlements`. Desde que o usuário conseguiu a conta Apple
Developer paga (2026-08-04), **todo desenvolvimento novo acontece só aqui** — bloqueio
de apps, o gate de "inútil sem luminária" e o relatório de sono só fazem sentido com
a entitlement paga mesmo.

### `teste-gratis-sem-nfc` (congelada)
Branch paralela, criada porque o usuário não queria pagar a Apple Developer Program
(~US$99/ano, ~R$550) antes de validar se o conceito valia a pena, e também não tinha
acesso a Mac. **Foi aqui que o app foi testado pela primeira vez num iPhone físico**,
via AltStore/sideload. Agora que o usuário tem a conta paga, essa branch **não recebe
mais cherry-pick** — fica como estava, congelada nas features testadas até
2026-08-04, caso sirva de referência ou demo pra alguém sem conta paga no futuro.

Diferenças em relação ao `main`:
- `Luminaria.entitlements` fica **vazio** — a capability de NFC só é liberada com conta
  paga; um Apple ID grátis (Personal Team, ou o certificado que o AltServer gera) não
  consegue assiná-la.
- `SettingsView` tem uma seção extra **"Teste sem NFC"** com três botões: "Testar disparo
  do Atalho" (chama `ShortcutManager.shared.runSleepShortcut()` direto), "Testar tela do
  despertador" (chama `alarmManager.triggerTestAlarm(soundFileName:)` direto, toca a tela
  na hora) e "Armar despertador de teste" (chama `alarmManager.armAlarm(...)` com os
  dados da rotina ativa, exercitando o pipeline real de agendamento/notificação sem
  precisar de NFC funcional) — todos sem depender do NFC, pra validar cada parte
  isoladamente sem precisar de tag nem luminária física.
- `.github/workflows/sideload-ipa.yml` — só existe nesta branch. Compila pra dispositivo
  real (`-sdk iphoneos`, `-destination 'generic/platform=iOS'`) **sem assinatura**
  (`CODE_SIGNING_ALLOWED=NO`) e empacota num `.ipa` (zip com `Payload/Luminaria.app`),
  disponível como artifact do Actions (aba Actions → run mais recente → "Artifacts").
  Este workflow dispara automaticamente em todo push pra esta branch.

Sempre que um recurso é adicionado/corrigido em uma branch e faz sentido pras duas,
replicar via `git cherry-pick` (o padrão usado durante todo o desenvolvimento). Conflitos
são esperados especificamente na seção "Teste sem NFC" do `ContentView.swift` (só existe
na branch de teste) — resolver mantendo as duas partes ou removendo o lado que não se
aplica, dependendo de qual branch está recebendo o cherry-pick.

## Instalar no iPhone sem Mac (AltStore/AltServer)

Fluxo usado pra testar de verdade, todo do Windows:
1. Baixar o `.ipa` do artifact do `sideload-ipa.yml` (requer estar logado no GitHub —
   artifacts de Actions não são baixáveis sem autenticação, nem em repositório público).
2. Instalar **AltServer** no Windows (altstore.io) + **AltStore** no iPhone via AltServer
   (pede Apple ID grátis — o AltServer usa isso localmente pra gerar certificado, sem
   nenhuma ferramenta nossa participando dessa etapa). O **iTunes oficial da Apple**
   (não o da Microsoft Store) também precisa estar instalado — não pra usar, mas porque
   ele traz o Bonjour Service e o Apple Mobile Device Support de que o AltServer depende.
3. Ativar o **Modo de Desenvolvedor** no iPhone (Ajustes → Privacidade e Segurança) —
   exigido pelo iOS 16+ pra rodar qualquer app assinado fora da App Store.
4. Transferir o `.ipa` pro iPhone (iCloud Drive é o caminho mais simples) e instalar via
   AltStore → "My Apps" → "+".
5. **Certificado grátis expira a cada 7 dias** — precisa reabrir o AltServer com o iPhone
   na mesma rede e dar "Refresh All" no AltStore periodicamente.

### Problemas reais já resolvidos nesse processo (pra não repetir o diagnóstico)
- **"A conexão com o AltServer foi perdida" / instalação falha na transferência**: geralmente
  só tentar de novo resolve — falha pontual de rede Wi-Fi, não indica configuração errada.
- **"Could not connect to AltServer" / não encontra o dispositivo**: checar, nessa ordem —
  (a) AltServer realmente aberto na bandeja do Windows; (b) rede Ethernet do PC marcada
  como **"Privada"**, não "Pública" (Configurações → Rede e Internet) — rede Pública ativa
  o Firewall do Windows contra descoberta local; (c) **"Bonjour Service"** rodando
  (`services.msc` — instalado junto com o iTunes); (d) **"Wi-Fi Sync"** habilitado no
  iTunes com o iPhone conectado por cabo pelo menos uma vez (tela de resumo do
  dispositivo → "Sincronizar via Wi-Fi").
- **"AltServer could not be found"**: mesma checklist acima. Se tudo isso já estava
  certo e do nada parou de funcionar, o motivo mais provável é banal — **cabo USB mal
  conectado** (aconteceu exatamente isso numa sessão de teste). Confirmar a conexão física
  antes de investigar rede/serviços.
- **"The data couldn't be read because it isn't in the correct format"**: o arquivo
  selecionado ainda era o `.zip` que o GitHub embrulha em volta do artifact (baixar sempre
  extrai um `.zip` contendo o `.ipa` — selecionar o `.ipa` de dentro, não o `.zip`).
- **Ícone do AltServer sumindo da bandeja**: fica na área de ícones ocultos (seta "^"),
  não abre uma janela própria — comportamento normal no Windows, não é bug.

## Decisões não óbvias (o "porquê")

- **`Luminaria.xcodeproj/project.pbxproj` foi escrito à mão**, linha por linha — não existe
  Xcode/macOS neste ambiente de desenvolvimento (Windows). IDs de objeto seguem o padrão
  `AAAAAAAAAAAAAAAAAAAAAA` + 2 dígitos hex incrementais (maior em uso: `46`); qualquer
  novo arquivo precisa de entradas em `PBXBuildFile`, `PBXFileReference`, no grupo, e na
  build phase certa (`Sources` pra `.swift`, `Resources` pra assets/sons). Sempre
  verificar balanço de chaves/parênteses e contagem de referências de cada ID novo
  depois de editar.
- **O botão redondo é o "arme/desarme" do modo noite**, não um disparo direto. Regra
  pedida pelo usuário: encostar a luminária (NFC) só dispara o Atalho e o despertador
  **se o modo noite estiver armado no app** — sem isso, encostar não faz nada. O botão
  sozinho só arma e começa a escuta NFC; o disparo de verdade só acontece quando a tag é
  reconhecida (`NFCManager.onRecognizedTap`, gated por `isNightModeArmed`), usando os
  dados da rotina marcada como ativa em `SleepRoutineStore`.
- **Vincular já funciona com qualquer tag NFC, não uma específica** — confirmado
  revisando `NFCManager.handleDetectedTag`: o identificador da PRIMEIRA tag lida (ramo
  `else` quando `!isLinked`) é o que vira "a" luminária vinculada; não há tag
  hardcoded. Único requisito real: a tag precisa ser NDEF-capaz (praticamente
  qualquer adesivo NFC barato tipo NTAG213/215 serve; cartões de pagamento/transporte
  por aproximação podem não servir). Nenhuma mudança de código foi necessária pra
  isso — só confirmar o comportamento já existente.
- **Bloqueio de apps exige uma entitlement separada, que não vem só da conta
  Developer paga** — `com.apple.developer.family-controls` (Screen Time API) é uma
  entitlement privilegiada: a Apple exige um pedido escrito à parte (bundle ID +
  justificativa), aprovado manualmente, sem prazo fixo (dias a semanas). Diferente da
  entitlement de NFC (que só depende de ter a conta paga), essa depende de aprovação
  humana da Apple. `ScreenTimeManager.swift`/`AppBlockingView.swift` compilam
  normalmente sem a entitlement (as APIs não exigem isso pra compilar); só não
  funcionam de verdade num device até ela ser aprovada E adicionada em
  `Luminaria.entitlements` — adicionar antes da aprovação quebraria a assinatura no
  device (perfil de provisionamento não suporta a capability ainda).
- **Não existe API pública pra contar notificações ou ligações bloqueadas** — é
  deliberadamente não exposto pela Apple por privacidade. Bloqueio de ligação,
  inclusive, é uma API totalmente separada (`CallKit`), sem relação nenhuma com
  bloqueio de apps. O que dá pra medir de verdade sem nenhuma *extension* nova:
  quantos apps/categorias/sites foram escolhidos (`FamilyActivitySelection`), e por
  quanto tempo o bloqueio ficou ativo (timestamps próprios de quando o app
  arma/desarma o shield). Contagem de "tentativas de abrir um app bloqueado" só dá
  com uma **`ShieldActionExtension`** — um target novo no Xcode (ver pendência
  abaixo), não implementado ainda.
- **`ShieldActionExtension` fica adiada pra uma sessão real no Xcode, não escrita às
  cegas** — confirmado olhando o `pbxproj` atual: existe hoje um único
  `PBXNativeTarget`; um target de extension novo precisa de bem mais que o padrão de
  "2 IDs, 4 pontos de registro" já usado ~10 vezes neste projeto pra arquivos comuns
  — entra `PBXNativeTarget`, `PBXContainerItemProxy`, `PBXTargetDependency`,
  entitlements próprio (com App Group compartilhado com o app principal), Info.plist
  com dicionário `NSExtension`, e uma build phase "Embed App Extensions" no target
  principal. Isso nunca foi tentado à mão neste projeto e não deve ser — só quando
  houver acesso a um Xcode interativo de verdade (o usuário conseguiu isso via um
  contato desenvolvedor). Detalhe real de API: essa extension só pode responder
  `.none`/`.defer`/`.close` — não existe jeito suportado dela abrir o app principal
  de volta, só contar/registrar e fechar.
- **Bug real já corrigido: `ScreenTimeManager.swift` só importava `FamilyControls`/
  `ManagedSettings`, sem `Foundation`/`Combine`** — quebrou o primeiro push real depois
  de adicionar esses frameworks, com erros de compilação em cadeia (`cannot find type
  'ObservableObject' in scope`, `unknown attribute 'Published'`, `cannot find type
  'Date' in scope`), só visíveis no log completo do Actions (a API pública só mostra
  "exit code 65" genérico — pedi pro usuário colar o log manualmente, já que baixar/ver
  logs completos exige estar logado no GitHub). A suspeita inicial (`FamilyControls`/
  `ManagedSettings` não compilariam pro Simulador) **era errada** — o log mostrou o
  build de device chegando normalmente até a etapa de compilação Swift antes de falhar
  por esse import faltando, ou seja, a causa nunca foi a plataforma. Fix: adicionar
  `import Combine` e `import Foundation` no topo do arquivo. **Lição**: não confiar em
  suposição sobre disponibilidade de framework/SDK sem o log real — pedir o log ao
  usuário antes de tentar um segundo fix às cegas.
- **`build.yml` trocado de Simulador pra device mesmo assim** — não por causa do bug
  acima (que era só um import faltando, teria quebrado em qualquer destino), mas porque
  `FamilyControls`/`ManagedSettings` só funcionam de verdade em device físico; compilar
  contra o SDK `iphoneos` (mesma receita sem assinatura do `sideload-ipa.yml`) reflete
  melhor a plataforma real de uso do que o Simulador, onde essas APIs nunca vão rodar de
  qualquer forma.
- **`TARGETED_DEVICE_FAMILY` trocado de `"1,2"` (iPhone + iPad) pra `1` (só iPhone)**
  (2026-08-05, achado no primeiro envio real pro TestFlight via Codemagic) — o app
  compilava e assinava normalmente, mas o envio ao App Store Connect era rejeitado:
  "Invalid bundle. The UIInterfaceOrientationPortrait orientations were provided...
  but you need to include all of the ...orientations to support iPad multitasking."
  A Apple exige que qualquer app universal (iPhone+iPad) declare as 4 orientações no
  Info.plist, por causa do multitasking do iPad (Split View/Slide Over) — mas o
  `Info.plist` só declara Portrait, de propósito (é uma tela única com botão redondo,
  sem layout pensado pra iPad ou paisagem). Em vez de forçar orientações que não fazem
  sentido pro design só pra passar na validação, a correção certa é não anunciar suporte
  a iPad, já que o app nunca foi pensado pra rodar lá. `TARGETED_DEVICE_FAMILY = 1`
  atualizado nas 4 seções de build settings do `project.pbxproj` (Debug/Release ×
  nível de projeto/target).
- **Certificado e provisioning profile de distribuição precisam ser criados
  manualmente na primeira vez, mesmo com API key "Admin" configurada no Codemagic** —
  descoberto testando o primeiro envio de verdade: mesmo depois de conectar a
  integração `LuminariaAppStoreKey` (App Store Connect API key com acesso Admin), o
  build falhava com "No matching profiles found for bundle identifier com.luminaria.app
  and distribution type app_store". A integração da API key só dá *acesso* — não gera
  sozinha o certificado de distribuição nem o provisioning profile na primeira vez.
  Precisou: (1) gerar um certificado "Apple Distribution" em Codemagic → Settings →
  Code signing identities → iOS certificates → "Generate certificate"; (2) como não
  existe botão de "gerar" profile no Codemagic, criar o provisioning profile manualmente
  em developer.apple.com → Profiles → tipo "App Store", usando o App ID
  `com.luminaria.app` e o certificado recém-criado, baixar o `.mobileprovision` e subir
  em Codemagic → Code signing identities → iOS provisioning profiles. Depois de criados
  uma vez, o Codemagic deve reutilizá-los sozinho nos próximos builds/renovações.
- **Bug real já corrigido: `NDEF is disallowed` rejeitava o envio no processamento do
  App Store Connect** (erro clássico da Apple, ITMS-90778) — `Luminaria.entitlements`
  tinha `com.apple.developer.nfc.readersession.formats` com o valor `NDEF`, um padrão
  que versões antigas do Xcode inseriam automaticamente ao ativar a capability de NFC,
  mas que a Apple descontinuou (só `TAG` é aceito nessa entitlement hoje). A boa notícia:
  `NFCNDEFReaderSession` (a API usada em `NFCManager.swift`) **não precisa dessa
  entitlement pra funcionar** — ela só é exigida pra leitura de baixo nível via
  `NFCTagReaderSession`, que não é o caso daqui. Basta o `NFCReaderUsageDescription` no
  `Info.plist` (que já existia). Fix: `Luminaria.entitlements` esvaziado (`<dict/>`),
  igual ao que a branch `teste-gratis-sem-nfc` já fazia sem conta paga — a leitura NFC
  continua funcionando normalmente, só o processamento no App Store Connect que exigia
  isso.
- **A partir de agora, desenvolvimento só no `main`** — decisão do usuário depois de
  conseguir a conta Apple Developer paga: bloqueio de apps e o gate de "inútil sem
  luminária" só fazem sentido com a entitlement paga mesmo, então a
  `teste-gratis-sem-nfc` fica congelada como estava (não recebe mais cherry-pick).
- **Notificação como fonte da verdade do despertador, não só o `Timer` interno** (fix do
  primeiro round de testes físicos, 2026-08-01): antes, só um `Timer` de 15 segundos
  comparava a hora atual com o horário agendado — se o processo estivesse suspenso, a
  tela de "Parar" só aparecia bem depois de reaberto o app, mesmo com o som já tocando.
  Agora `AlarmManager` é `UNUserNotificationCenterDelegate` e reage imediatamente à
  entrega/toque da notificação (que o próprio iOS garante disparar na hora, processo
  suspenso ou não). O `Timer` de 15s continua existindo como rede de segurança pro caso
  de notificações estarem desativadas. Também foi preciso persistir o estado armado
  (hora/minuto/som) em `UserDefaults`, porque se o iOS mata e relança o processo pelo
  toque na notificação, as variáveis em memória se perdem.
- **Bug real já corrigido: a checagem do despertador comparava hora/minuto exatos, não
  "já passou desse horário?"** — mesmo com o delegate de notificação implementado, a
  tela de "Parar" continuava aparecendo atrasada. Causa: `checkAlarmTime()` só disparava
  se `now.hour == hour && now.minute == minute` — reabrir o app um pouco depois do
  minuto certo (o caso mais comum) fazia a checagem falhar pra sempre naquele dia, já
  que o minuto exato tinha passado. Trocado por um `nextFireDate` (`Date` de verdade,
  não hora/minuto soltos) comparado com `>=`, calculado via `Calendar.nextOccurrence`
  pra não cair no bug de virada de meia-noite (armar às 22h pra um alarme às 7h não pode
  disparar na hora — tem que ser o 7h do dia seguinte). Também chama a checagem no
  `.onAppear` do `ContentView`, já que `.onChange(of: scenePhase)` não reage à transição
  inicial num cold launch.
- **Bug real já corrigido: o despertador não conseguia aparecer com o menu de
  Configurações aberto** — o `fullScreenCover` do despertador e o `.sheet` do menu
  estavam os dois no `ContentView`; o SwiftUI só permite uma apresentação modal ativa
  por view, então com o menu já aberto o `fullScreenCover` não conseguia furar. Corrigido
  movendo o `fullScreenCover` pro `LuminariaApp`, um nível acima do `ContentView` — dali
  ele cobre qualquer sheet aberta por uma view descendente.
- **Nenhum app de terceiros consegue desenhar tela nenhuma por cima da tela de
  bloqueio** — confirmado testando no device físico (o som toca normalmente com a tela
  bloqueada, só a tela "Parar" que não aparece até desbloquear). Isso é um limite real
  da plataforma, não um bug: só o app Relógio tem esse privilégio. Adicionado um botão
  "Parar" direto na notificação (`UNNotificationAction`/`UNNotificationCategory`, toque
  longo ou deslizar a notificação) — funciona com a tela bloqueada, sem exigir
  desbloquear nem abrir o app, e é o mais perto que dá de "parar o despertador da tela
  de bloqueio" sem a permissão especial de alertas críticos da Apple.
- **Bug real já corrigido: `interruptionLevel = .timeSensitive` na notificação não tinha
  efeito nenhum** — achado testando no device: o Atalho ativa o Foco "Não Perturbe", que
  filtrava o despertador mesmo marcado como sensível ao tempo no código. Causa: marcar
  o *conteúdo* da notificação como `.timeSensitive` não basta — o app também precisa ter
  pedido a *permissão* `.timeSensitive` em `requestAuthorization`, senão o iOS trata a
  notificação como normal (sujeita a qualquer Foco ativo) independente do que o código
  define. `requestNotificationPermission()` pedia só `[.alert, .sound]`; corrigido pra
  `[.alert, .sound, .timeSensitive]`. Ressalva: quem já tinha o app instalado com a
  permissão antiga precisa ativar manualmente "Notificações Sensíveis ao Tempo" em
  Ajustes → Notificações → Luminária (ou apagar e reinstalar o app), já que o iOS não
  reexibe o prompt de permissão sozinho só porque o código pediu uma opção nova — e
  mesmo com a opção concedida, o Foco específico ativado pelo Atalho (ex.: Não Perturbe)
  precisa ter o Luminária na lista de apps sempre permitidos pra garantia total (ver
  checklist na `HelpView`).
- **O som da notificação de backup era o som padrão do sistema, não o som do
  despertador** — trocado pra `UNNotificationSound(named:)` carregando o mesmo `.wav`
  escolhido na rotina ativa, assim mesmo com o app suspenso o som que toca (via
  notificação do próprio iOS) é o correto, não um bipe genérico.
- **Limite real de plataforma, documentado e não perseguido**: não existe API pública
  pra um app terceiro criar um alarme de sistema de verdade (que apareceria no app
  Relógio) nem pra forçar uma tela sobre o bloqueio como o Relógio faz. `.critical`
  (interrupção que ignora até o modo silencioso) exige um entitlement especial da Apple,
  inviável sem conta de desenvolvedor paga — por isso o despertador aqui depende de
  notificações normais, e por isso a tela Ajuda (`HelpView`) orienta o usuário a conferir
  as permissões de notificação e a configuração do Foco no próprio iPhone quando o
  despertador não aparecer na tela bloqueada (pode ser o Foco ativado pelo Atalho
  suprimindo a notificação, não um bug do app).
- **Rotinas de sono são uma lista dinâmica**, não um número fixo de slots — decisão
  explícita do usuário (criar/renomear/excluir livremente, sem limite). Isso trocou os
  campos soltos em `@AppStorage` (`alarmHour`/`alarmMinute`/`nightShiftOffHour`/
  `nightShiftOffMinute`) por `SleepRoutineStore`, com migração automática pra não perder
  a configuração que já existia num device físico real em teste.
- **Identidade visual própria nas telas secundárias, em vez de List/Form padrão do
  iOS** — feedback do usuário: Configurações, Rotinas e Ajuda tinham "cara de Ajustes do
  iPhone". Resolvido reaproveitando a paleta e a forma do botão principal (cream/chumbo,
  cantos bem redondos, sombra suave) em cartões e badges circulares (`AppTheme.swift`),
  em vez de inventar uma identidade nova. Processo idêntico ao já usado pro botão
  principal: protótipo em `design/luminaria_settings_prototipo.html` → Artifact no
  claude.ai → aprovação do usuário → implementação em SwiftUI. **Ressalva explícita do
  usuário**: o botão redondo e a seleção Living/Zleepy mode da tela principal NÃO fazem
  parte dessa mudança — são a identidade da marca, ficam intocados.
- **Sons novos gerados por síntese, não baixados** — pedido explícito do usuário pra não
  soar como sirene ("alarme anti bombas"). São ondas senoidais puras com envelope suave
  de ataque/liberação, frequências mais baixas e ritmo mais lento que o som original
  (bipe triplo em 1000Hz).
- **Sons de natureza também são sintetizados, não gravações baixadas** — o usuário pediu
  sons "de verdade" tipo praia/natureza, inspirados em concorrentes de despertador
  confortável (Sleep Cycle, Pillow etc.). Decisão explícita de **não baixar** essas
  gravações de bancos de som (freesound.org e afins): licenciamento de áudio "grátis"
  varia arquivo a arquivo e precisaria ser conferido um por um antes de publicar na App
  Store — risco desnecessário pra um app hobby. Resolvido sintetizando com **ruído
  branco filtrado** (`Apply-LowPass`, filtro IIR de um polo) em vez de tons puros: ondas
  do mar = ruído bem filtrado com envelope de 3 "ondas"; chuva = ruído menos filtrado
  (mais "chiado") + estalos curtos aleatórios simulando gotas; passarinhos = ruído bem
  filtrado bem baixo (ambiente) + glissandos curtos agudos (~2-4kHz) espalhados
  aleatoriamente. Normalizados bem mais alto (pico ~85-92%) que os tons calmos antigos
  (que ficavam em ~30-60%) — pedido do usuário ("sons maiores"), pra funcionar de
  verdade como despertador em vez de só ambiente relaxante.
- **Bug potencial evitado: mudar os casos do enum `AlarmSoundOption` quebraria rotinas
  já salvas** — remover `gentleChime`/`breathing` do enum faria o `JSONDecoder` falhar
  ao decodificar qualquer rotina já persistida que apontasse pra esses sons (o decode
  sintetizado do Swift rejeita valores brutos desconhecidos), resetando as rotinas do
  usuário sem aviso — ele já estava testando o app de verdade com rotinas criadas. Fix:
  `Codable` implementado à mão em `AlarmSoundOption` (em vez do sintetizado), mapeando
  os dois valores antigos pros equivalentes novos mais parecidos (`gentleChime` →
  `oceanWaves`, `breathing` → `birds`) durante o decode, e persistindo esses valores
  novos na próxima gravação — migração transparente, sem perder nada.
- **Processamento de áudio sem Python**: a intenção original era reusar a mesma técnica
  de antes (Python stdlib `wave`/`struct`/`math`), mas esta máquina não tem Python
  instalado (só o stub da Microsoft Store). Resolvido do mesmo jeito que as imagens
  foram resolvidas antes: `scripts/generate_alarm_sounds.ps1` com PowerShell +
  `System.IO`/`Math` do .NET (já vem no Windows, nada pra instalar), escrevendo o WAV
  byte a byte com `BinaryWriter`. Diferente da vez anterior (só os `.wav` foram
  commitados, sem o gerador), desta vez o script fica no repo pra poder reajustar os
  sons no futuro.
- **Não existe API pública da Apple pra criar um Atalho com a ação "Definir Foco" ou
  "Definir Modo Noturno" programaticamente**, nem pra ativar Focus Mode ou Night Shift
  direto por um app terceiro. Por isso `HelpView` só guia o usuário a criar o Atalho
  manualmente uma vez; o app só executa (`shortcuts://x-callback-url/run-shortcut`) o
  que já existe.
- **Também não existe API pública pra criar um alarme de sistema** (que apareceria no app
  Relógio) — nem Shortcuts consegue fazer isso de fora do próprio ecossistema Apple pra
  apps de terceiros de forma equivalente à ação "Adicionar Alarme" (que é exclusiva do
  Atalhos). Por isso o despertador é uma implementação nativa própria, não um alarme de
  sistema de verdade. Ressalva real e permanente: se a pessoa fechar o app manualmente
  (arrastar pra cima no seletor de apps) ou reiniciar o iPhone, o processo morre e o
  alarme não toca — mesma limitação de qualquer app de despertador de terceiros (Alarmy,
  Sleep Cycle etc.).
- **Nome real da ação de alarme no Atalhos é "Adicionar Alarme"**, não "Definir
  Despertador" — de qualquer forma essa ação não é mais usada, já que o despertador virou
  nativo.
- **Sem Mac/conta Apple Developer neste momento** — o pipeline de CI (`build.yml`) existe
  justamente pra validar compilação num runner macOS na nuvem sem precisar comprar nada.
  `release.yml` e o NFC de verdade só entram em jogo quando o usuário tiver a conta paga
  (decisão explícita de adiar por causa do custo, ver seção de pendências).
- **Bug real já corrigido**: `NFCNDEFTag` é um *protocolo*, não um enum — não dá pra fazer
  `switch` com casos `.miFare`/`.iso15693`/etc (esses casos existem no tipo `NFCTag`, de uma
  API NFC diferente, a `NFCTagReaderSession`). O fix usa `as?` pra downcast pras classes
  concretas (`NFCMiFareTag`, `NFCISO15693Tag`, `NFCISO7816Tag`, `NFCFeliCaTag`).
- **Bug real já corrigido (achado testando no device físico)**: o ícone do menu usava
  `.foregroundStyle(.primary)`, que o iOS ajusta pelo modo claro/escuro **do sistema**, não
  pelo `isNightModeArmed` do app. Com o iPhone em modo escuro do sistema, `.primary` virava
  branco e sumia no fundo claro do Living mode. Fix: cores fixas (`menuIconAwake`/
  `menuIconSleep`), sempre com contraste correto nos dois fundos do app, independente do
  tema do iOS.
- **`shortcuts://run-shortcut` abre o app Atalhos por completo** (achado testando no
  device) — visualmente incômodo, o usuário não queria isso. Trocado por
  `shortcuts://x-callback-url/run-shortcut` com `x-success`/`x-error` apontando pro esquema
  custom `luminaria://` (registrado via `CFBundleURLTypes` no `Info.plist`, tratado num
  `.onOpenURL` vazio no `ContentView`). A Apple documenta esse modo como uma execução com
  só um aviso rápido (HUD), que volta sozinha pro app de origem. Não dá pra deixar 100%
  silencioso (Apple exige algum indicativo visual de que o Foco está sendo alterado).
- **Desligar o Modo Noturno de manhã não pode ser dinâmico/automático via Atalho** — um
  Atalho roda uma única vez, na hora em que é chamado; não existe mecanismo pra ele
  "esperar até de manhã" dentro da mesma execução. A solução é uma automação por horário
  separada, criada manualmente pelo usuário na aba Automação do Atalhos (mesma limitação
  de "sem API pública pra automações de terceiros"). O app guarda e mostra o horário
  escolhido (por rotina, em `SleepRoutineStore`) só como referência — não consegue
  programar essa automação sozinho.
- **Processamento de imagem sem instalar nada**: sem Pillow/ImageMagick disponíveis (e o
  usuário pediu explicitamente pra não instalar pacotes), o recorte/recolorização dos
  ícones foi feito com o que já vem no Windows — PowerShell + `System.Drawing` (.NET).
- **Bug real já corrigido: `Bitmap` com `Format32bppRgb` ainda salva PNG com canal
  alfa** — gerando o `AppIcon-1024.png`, `Format32bppRgb` (sem "A" no nome, teoricamente
  sem alfa) ainda produzia um PNG RGBA de verdade (alfa sempre opaco, mas o canal
  continuava existindo no arquivo) — o encoder de PNG do GDI+ não elimina o canal só por
  causa do pixel format do `Bitmap` em memória. A Apple rejeita qualquer ícone de App
  Store com canal alfa presente, mesmo 100% opaco. Fix: `Format24bppRgb` (24 bits,
  literalmente sem espaço pra canal alfa) em vez de `Format32bppRgb`.
- **Sem `gh` CLI instalado** — o push pro GitHub usa `git` puro por HTTPS; o Git Credential
  Manager do Windows já cuida da autenticação (abre navegador se precisar). Downloads de
  artifacts de Actions, porém, **exigem autenticação e não dão pra baixar via curl sem
  login** — isso o usuário precisa fazer manualmente pelo navegador.

## ⚠️ Pendência arquitetural importante (não esquecer)

O reconhecimento de NFC hoje (`NFCManager.beginScanning()`, disparado quando a tag é
reconhecida durante uma sessão em primeiro plano) é uma **sessão com o app aberto, que
expira sozinha em ~60s**. Isso foi uma escolha deliberada pro estágio atual (sem custo,
sem infraestrutura, testável assim que houver um device), **mas o usuário foi explícito:
essa NÃO é a versão final** — pro produto de verdade funcionar, a leitura NFC precisa
acontecer **em segundo plano, sempre, com o app em modo noite**, independente de o app ter
sido aberto recentemente ("se não a proposta quebra", palavras do usuário em 2026-07-14).

**Por que o limite de ~60s existe**: não é ajustável, não é bug nosso. `NFCNDEFReaderSession`
foi projetada pela Apple pra interações curtas e deliberadas (tipo escanear um pôster), não
pra escuta contínua — por isso o iOS invalida a sessão sozinho após um período de
inatividade, e não existe API pública pra estender ou desligar esse timeout.

A versão final exige migrar pra Universal Links / Associated Domains (tag NFC com uma URL
`https://` de um domínio do usuário, `apple-app-site-association` hospedado, entitlement
`applinks:`, e tratar o deep link via `onOpenURL`) — é um mecanismo de sistema totalmente
diferente do CoreNFC reader-session, sem limite de tempo e que funciona com o app fechado.
`isNightModeArmed` continua sendo um `@State` transiente hoje — se essa migração avançar,
também vai precisar virar persistente (`UserDefaults`), já que o disparo por Universal Link
pode acontecer com o app frio.

Confirmado de novo com o usuário em 2026-07-14: **ainda fica pra depois**, exige domínio
próprio com hospedagem que ele ainda não tem. Levantar esse assunto de novo quando o
usuário tiver testado o MVP num device físico e/ou tiver um domínio disponível.

Uma variante mais simples foi discutida (reiniciar a sessão NFC automaticamente enquanto
o modo noite estiver armado, sem precisar de domínio) mas tem dois problemas próprios: a
folha de sistema do NFC ficaria visível quase o tempo todo, e o iOS suspende a escuta
assim que a tela trava (justamente quando a pessoa realmente vai dormir) — não foi
implementada, mas fica registrada como ideia intermediária caso valha revisitar.

## ⚠️ Pendências do bloqueio de apps (não esquecer)

1. **Pedido da entitlement `Family Controls`** — precisa ser feito pelo usuário em
   developer.apple.com (bundle ID `com.luminaria.app`), aprovação manual da Apple, sem
   prazo fixo. Sem isso, `ScreenTimeManager`/`AppBlockingView` compilam mas não
   funcionam de verdade em nenhum device. Verificar status antes de cada tentativa de
   teste real no device.
2. **`Luminaria.entitlements` só recebe `com.apple.developer.family-controls` depois**
   da aprovação acima — adicionar antes quebra a assinatura no device.
3. **`ShieldActionExtension`** (contar tentativas de abrir app bloqueado) fica pra
   quando houver sessão real no Xcode — código Swift ainda não escrito, só planejado
   (ver Decisões acima). Quando for feita: criar o target via assistente do Xcode
   (Shield Action Extension), configurar App Group compartilhado com o app principal,
   pedir a entitlement dessa extension separadamente (bundle ID próprio) em
   developer.apple.com.

## Ideia futura, ainda não iniciada: controle Bluetooth da luminária física

O usuário perguntou sobre viabilidade de controlar a luminária de verdade via Bluetooth
(trocar cor, brilho, e rotinas automáticas tipo "nascer do sol" gradual das 7:00 às
7:15). Pontos levantados na discussão, caso isso avance:
- **Pré-requisito que ainda falta**: a "luminária" hoje é só uma tag NFC passiva colada em
  algo — não existe nenhum hardware controlável ainda. Precisa decidir entre comprar uma
  lâmpada/fita LED BLE comercial já pronta (mais rápido, protocolo já documentado por
  terceiros pra chips comuns tipo os usados em bulbos genéricos "Magic Home"/Govee/Yeelight)
  ou montar hardware próprio do zero (ESP32 + LED + firmware — projeto bem maior).
- **Controle sob demanda via Bluetooth**: viável com `CoreBluetooth`, e diferente do NFC,
  **não exige conta Apple Developer paga** pra testar — funciona com Apple ID grátis.
- **Rotinas agendadas (tipo o nascer do sol gradual)**: mais robusto se o **hardware da
  luminária** guardar o agendamento internamente (recebe o comando uma vez, executa
  sozinho) em vez do app iOS tentar "ficar acordado" mandando comando por comando durante
  os 15 minutos — apps em segundo plano no iOS não têm garantia de rodar num horário exato.

## Status atual (2026-08-03)

- Primeiro round de testes reais no iPhone físico (via AltStore, `teste-gratis-sem-nfc`,
  2026-08-01) trouxe 5 pontos, todos endereçados naquela rodada: despertador não
  aparecia na tela bloqueada quando disparava; som chegava na hora mas a tela demorava;
  sem opção de som (e o som soava como sirene); faltava suporte a várias rotinas de
  sono; menu de Configurações misturava instruções com campos de verdade. Ver Decisões
  acima (`AlarmManager` virou `UNUserNotificationCenterDelegate`, `SleepRoutineStore`,
  3 sons novos, `HelpView`).
- Segundo round de testes (2026-08-03) trouxe mais 4 pontos, todos endereçados:
  1. A tela de "Parar" ainda aparecia atrasada mesmo com o fix anterior — causa raiz
     era comparação de hora/minuto exatos em vez de "já passou desse horário?"
     (`checkAlarmTime` → `nextFireDate` com `>=`, ver Decisões acima).
  2. O despertador não conseguia aparecer com o menu de Configurações aberto —
     `fullScreenCover` e `.sheet` competindo pela mesma apresentação modal no
     `ContentView`; movido pro `LuminariaApp`.
  3. Confirmado que o despertador não aparece (nem pode) com a tela bloqueada — limite
     real da plataforma, não bug; o som toca normalmente nessa hora. Adicionado botão
     "Parar" direto na notificação (`UNNotificationAction`), funciona com a tela
     bloqueada sem abrir o app.
  4. "Cara de Ajustes do iPhone" nas telas secundárias — identidade visual própria
     (`AppTheme.swift`), reaproveitando a paleta do botão principal em cartões e badges
     circulares. Botão redondo e seleção Living/Zleepy mode continuam intocados (pedido
     explícito do usuário).
- `main` foi trazido pra paridade de funcionalidades com `teste-gratis-sem-nfc` via
  cherry-pick (checagem `>=` do despertador, identidade visual, fix do `fullScreenCover`,
  botão "Parar" na notificação, permissão `.timeSensitive`) — importante porque o `main`
  é a branch usada pra testar NFC de verdade, e estava 6 commits atrasada.
- Build compila com sucesso no CI em ambas as branches (checar `build.yml` e
  `sideload-ipa.yml` depois de qualquer mudança nova).
- UI do botão principal aprovada pelo usuário (checkpoint marcado com a tag `v1` no
  `main`, protótipo aprovado em `design/luminaria_prototipo.html`). Identidade das
  telas secundárias aprovada em `design/luminaria_settings_prototipo.html`.
- O Atalho "Dormir sem celular" já foi criado pelo usuário no app Atalhos e testado com
  sucesso (ações: Definir Foco, Definir Modo Noturno).
- Pipeline do Codemagic (`codemagic.yaml`) e os ajustes que ele exige (ícone de App
  Store, `ITSAppUsesNonExemptEncryption`) já estão prontos no `main`, preparando o
  terreno pra publicar no TestFlight assim que a conta Apple Developer paga existir.
- Ainda faltam: o usuário testar esta rodada de mudanças no device físico; conseguir
  acesso a conta Apple Developer paga (usuário ia decidir isso numa reunião com uma
  desenvolvedora de apps em 2026-08-03) pra testar o NFC de verdade, configurar os
  secrets do `release.yml` ou a chave do Codemagic, e trocar o ícone provisório por um
  de verdade; criar manualmente a automação por horário de "desligar Modo Noturno de
  manhã" no Atalhos.
- **2026-08-05**: conta Apple Developer paga adquirida. Implementado, só no `main`
  (decisão explícita do usuário — `teste-gratis-sem-nfc` congelada dali pra frente):
  gate "app inútil sem luminária vinculada" (`LockedView`, mostrado no lugar do botão
  redondo enquanto `!nfcManager.isLinked`); bloqueio de apps específicos durante o modo
  noite via Screen Time API (`ScreenTimeManager` + `AppBlockingView`, `FamilyControls`/
  `ManagedSettings`); relatório de sono (`SleepReportStore` + `SleepReportView`,
  registra apps bloqueados e duração — não notificações/ligações, ver Decisões acima).
  Confirmado que vincular já funciona com qualquer tag NFC (não precisou de mudança).
  `project.pbxproj` atualizado com os 5 arquivos novos + frameworks `FamilyControls`/
  `ManagedSettings` (maior ID em uso agora: `46`). Pendente: pedido da entitlement
  `Family Controls` em developer.apple.com (ação do usuário, aprovação manual sem
  prazo fixo — ver pendência acima) antes de testar de verdade num device; até lá o
  código compila mas o bloqueio não funciona de fato.

## Como retomar em outro computador

```
git clone https://github.com/diogolemos803/luminaria.git
cd luminaria
git checkout teste-gratis-sem-nfc   # ou main, se for mexer na versão com NFC completo
claude
```

O Claude Code lê este arquivo automaticamente ao abrir a pasta. O AltServer (Windows) e o
Bonjour precisam ser reinstalados na máquina nova se for continuar testando via sideload
— não "viajam" com o repositório.

## Convenções

- Textos e mensagens de commit em português, combinando com o usuário.
- Commits: sempre criar novo commit, nunca `--amend`.
- Mudanças que fazem sentido nas duas branches: implementar numa, `git cherry-pick` pra
  outra, resolvendo conflitos na seção "Teste sem NFC" quando aparecerem.
- Sempre confirmar CI verde (`gh`/API do GitHub Actions) depois de cada push antes de
  considerar uma mudança concluída.
