# Luminária Circadiana NFC

App iOS (Swift/SwiftUI) que vincula o iPhone a uma luminária física via NFC. Uma única
tela com um botão redondo central arma/desarma o "modo noite" (Living mode / Zleepy
mode). Quando a luminária é reconhecida via NFC com o modo noite armado, o app dispara
um Atalho de Foco ("Dormir sem celular") e um despertador nativo próprio.

Desenvolvido inteiramente num PC Windows, sem Mac disponível — todo compile/teste real
depende de CI num runner macOS na nuvem (GitHub Actions) e de sideload via AltStore.

## Arquitetura

- `Luminaria/LuminariaApp.swift` — entry point padrão do SwiftUI App lifecycle.
- `Luminaria/ContentView.swift` — tela única: botão redondo central que arma/desarma o
  modo noite (fundo claro/chumbo, ícone acordado/dormindo, texto "Living mode"/"Zleepy
  mode"). Menu no canto superior direito (`SettingsView`) concentra: vincular/desvincular
  NFC, configurar o Atalho (`ShortcutSetupView`), e os dois horários da rotina de sono
  (despertador e desligar Modo Noturno). Também define `AlarmRingingView` (tela cheia
  mostrada quando o despertador está tocando).
- `Luminaria/NFCManager.swift` — leitura NDEF via `CoreNFC` (`NFCNDEFReaderSession`).
  Salva o UID da primeira tag lida (vínculo) e reconhece a mesma tag depois. Sessão só
  fica ativa quando chamada explicitamente (`beginScanning()`), nunca em segundo plano.
- `Luminaria/ShortcutManager.swift` — dispara o Atalho via
  `shortcuts://x-callback-url/run-shortcut` (com `x-success`/`x-error` apontando pro
  esquema custom `luminaria://`, registrado no `Info.plist`), evitando abrir o app
  Atalhos por completo. Só cuida de Foco + Modo Noturno — o despertador NÃO passa mais
  por aqui (ver `AlarmManager.swift`).
- `Luminaria/AlarmManager.swift` — despertador **nativo do próprio app**, sem depender do
  Atalhos nem do app Relógio (não existe API pública da Apple pra um app terceiro criar
  um alarme de sistema). Toca um áudio quase inaudível em loop contínuo enquanto armado
  (mantém o app vivo em segundo plano via `UIBackgroundModes: audio`); ao bater o horário
  configurado, troca pelo som de alarme de verdade, em loop, até a pessoa abrir o app e
  tocar "Parar". Uma notificação local (`.timeSensitive`) serve de reforço.
- `Luminaria/silence_loop.wav` / `Luminaria/alarm_tone.wav` — sons gerados
  programaticamente (sem baixar nada de fora) via script Python usando só a biblioteca
  padrão (`wave`/`struct`/`math`), evitando depender de instalar pacotes.
- `Luminaria/Assets.xcassets` — `LogoAcordado`/`LogoSono`, PNGs com transparência real,
  recolorido (cinza escuro/cinza claro em vez de preto/branco puro) e recortado rente ao
  desenho. Os originais brutos ficam em `Assets/` na raiz (fora do git, só staging local).
- `design/luminaria_prototipo.html` — protótipo HTML aprovado do botão, referência visual
  do checkpoint (`v1`). Não é o app de verdade, é só pra revisar visual sem precisar de
  Mac — publicado também como Artifact no claude.ai durante o desenvolvimento.
- `.github/workflows/build.yml` — roda em todo push, compila pra Simulador sem assinatura
  (valida que o projeto compila, sem precisar de conta Apple Developer).
- `.github/workflows/release.yml` — disparo manual, archive + upload TestFlight. Só
  funciona depois de configurar secrets (certificado, provisioning profile, API key da
  App Store Connect) e trocar o Team ID em `ExportOptions.plist`. Ainda não usado — exige
  conta paga que o usuário decidiu adiar.

## As duas branches

### `main`
Versão completa, com a entitlement de NFC (`com.apple.developer.nfc.readersession.formats`)
declarada em `Luminaria.entitlements`. Só pode ser assinada/instalada com conta Apple
Developer Program paga — ainda não testada num device real por esse motivo.

### `teste-gratis-sem-nfc`
Branch paralela, criada porque o usuário não quer pagar a Apple Developer Program
(~US$99/ano, ~R$550) antes de validar se o conceito vale a pena, e também não tem
acesso a Mac. **É aqui que o app foi de fato testado num iPhone físico.**

Diferenças em relação ao `main`:
- `Luminaria.entitlements` fica **vazio** — a capability de NFC só é liberada com conta
  paga; um Apple ID grátis (Personal Team, ou o certificado que o AltServer gera) não
  consegue assiná-la.
- `SettingsView` tem uma seção extra **"Teste sem NFC"** com dois botões: "Testar disparo
  do Atalho" (chama `ShortcutManager.shared.runSleepShortcut()` direto) e "Testar tela do
  despertador" (chama `alarmManager.triggerTestAlarm()` direto) — ambos sem depender do
  NFC, pra validar cada parte isoladamente sem precisar de tag nem luminária física.
- `.github/workflows/sideload-ipa.yml` — só existe nesta branch. Compila pra dispositivo
  real (`-sdk iphoneos`, `-destination 'generic/platform=iOS'`) **sem assinatura**
  (`CODE_SIGNING_ALLOWED=NO`) e empacota num `.ipa` (zip com `Payload/Luminaria.app`),
  disponível como artifact do Actions (aba Actions → run mais recente → "Artifacts").

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
   nenhuma ferramenta nossa participando dessa etapa).
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
  `AAAAAAAAAAAAAAAAAAAAAA` + 2 dígitos hex incrementais; qualquer novo arquivo precisa de
  entradas em `PBXBuildFile`, `PBXFileReference`, no grupo, e na build phase certa
  (`Sources` pra `.swift`, `Resources` pra assets/sons). Sempre verificar balanço de
  chaves/parênteses e contagem de referências de cada ID novo depois de editar.
- **O botão redondo é o "arme/desarme" do modo noite**, não um disparo direto. Regra
  pedida pelo usuário: encostar a luminária (NFC) só dispara o Atalho e o despertador
  **se o modo noite estiver armado no app** — sem isso, encostar não faz nada. O botão
  sozinho só arma e começa a escuta NFC; o disparo de verdade só acontece quando a tag é
  reconhecida (`NFCManager.onRecognizedTap`, gated por `isNightModeArmed`).
- **Não existe API pública da Apple pra criar um Atalho com a ação "Definir Foco" ou
  "Definir Modo Noturno" programaticamente**, nem pra ativar Focus Mode ou Night Shift
  direto por um app terceiro. Por isso `ShortcutSetupView` só guia o usuário a criar o
  Atalho manualmente uma vez; o app só executa (`shortcuts://x-callback-url/run-shortcut`)
  o que já existe.
- **Também não existe API pública pra criar um alarme de sistema** (que apareceria no app
  Relógio) — nem Shortcuts consegue fazer isso de fora do próprio ecossistema Apple pra
  apps de terceiros de forma equivalente à ação "Adicionar Alarme" (que é exclusiva do
  Atalhos). Por isso o despertador é uma implementação nativa própria (áudio silencioso em
  loop + troca de som no horário — ver `AlarmManager.swift`), não um alarme de sistema de
  verdade. Ressalva real e permanente: se a pessoa fechar o app manualmente (arrastar pra
  cima no seletor de apps) ou reiniciar o iPhone, o processo morre e o alarme não toca —
  mesma limitação de qualquer app de despertador de terceiros (Alarmy, Sleep Cycle etc.).
- **Nome real da ação de alarme no Atalhos é "Adicionar Alarme"**, não "Definir
  Despertador" (erro inicial já corrigido nas instruções — confirmado pelo usuário direto
  na busca de ações do app Atalhos). De qualquer forma essa ação não é mais usada, já que
  o despertador virou nativo.
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
  escolhido (`nightShiftOffHour`/`Minute` em Configurações) só como referência — não
  consegue programar essa automação sozinho.
- **Processamento de imagem e áudio sem instalar nada**: sem Pillow/ImageMagick/ffmpeg
  disponíveis (e o usuário pediu explicitamente pra não instalar pacotes), tanto o
  recorte/recolorização dos ícones quanto a geração dos sons do despertador foram feitos
  com o que já vem no Windows/Python — PowerShell + `System.Drawing` (.NET) pras imagens,
  módulo `wave` da biblioteca padrão do Python pros sons.
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
Também exige persistir `isNightModeArmed` em `UserDefaults`, já que hoje é um `@State`
transiente que se perde ao fechar o app (e o disparo por Universal Link pode acontecer com
o app frio).

Confirmado de novo com o usuário em 2026-07-14: **ainda fica pra depois**, exige domínio
próprio com hospedagem que ele ainda não tem. Levantar esse assunto de novo quando o
usuário tiver testado o MVP num device físico e/ou tiver um domínio disponível.

Uma variante mais simples foi discutida (reiniciar a sessão NFC automaticamente enquanto
o modo noite estiver armado, sem precisar de domínio) mas tem dois problemas próprios: a
folha de sistema do NFC ficaria visível quase o tempo todo, e o iOS suspende a escuta
assim que a tela trava (justamente quando a pessoa realmente vai dormir) — não foi
implementada, mas fica registrada como ideia intermediária caso valha revisitar.

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

## Status atual (2026-07-28)

- Build compila com sucesso no CI em ambas as branches.
- UI do botão principal aprovada pelo usuário (checkpoint marcado com a tag `v1` no
  `main`, protótipo aprovado em `design/luminaria_prototipo.html`).
- **App testado com sucesso num iPhone físico de verdade**, via sideload AltStore/AltServer
  na branch `teste-gratis-sem-nfc` — sem Mac, sem conta Apple Developer paga. Fluxo
  completo validado: botão arma → NFC reconhece (testado via botões de debug, já que essa
  branch não tem a entitlement de NFC) → Atalho dispara Foco + Modo Noturno → despertador
  nativo arma e toca.
- O Atalho "Dormir sem celular" já foi criado pelo usuário no app Atalhos e testado com
  sucesso (ações: Definir Foco, Definir Modo Noturno).
- Despertador nativo (`AlarmManager`) implementado, testado via botão de debug "Testar
  tela do despertador". Arma no reconhecimento NFC (junto com o Atalho), não no toque do
  botão isolado.
- Ainda faltam: conseguir acesso a conta Apple Developer paga (usuário decidiu adiar por
  causa do custo — R$550/ano é caro pra validar algo antes de ter a luminária física de
  verdade) pra testar o NFC de verdade e configurar os secrets do `release.yml`; criar
  manualmente a automação por horário de "desligar Modo Noturno de manhã" no Atalhos.

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
