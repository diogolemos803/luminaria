# Luminária Circadiana NFC

App iOS (Swift/SwiftUI) que vincula o iPhone a uma luminária física via NFC e usa esse
vínculo para disparar um Atalho de Foco ("Dormir sem celular") na hora de dormir.

## Arquitetura

- `Luminaria/ContentView.swift` — tela única: botão redondo central que arma/desarma o
  "modo noite" (fundo claro/chumbo, ícone acordado/dormindo). Menu no canto superior
  direito (`SettingsView`) concentra vincular NFC, testar leitura, desvincular e
  configurar o Atalho (`ShortcutSetupView`).
- `Luminaria/NFCManager.swift` — leitura NDEF via `CoreNFC`. Salva o UID da primeira tag
  lida (vínculo) e reconhece a mesma tag depois.
- `Luminaria/ShortcutManager.swift` — dispara o Atalho via `shortcuts://x-callback-url/run-shortcut`
  (com `x-success`/`x-error` apontando pro esquema custom `luminaria://`, registrado no
  `Info.plist`), pra evitar abrir o app Atalhos por completo.
- `Luminaria/Assets.xcassets` — `LogoAcordado`/`LogoSono`, PNGs com transparência real,
  recolorido (cinza escuro/cinza claro em vez de preto/branco puro) e recortado rente ao
  desenho. Os originais brutos ficam em `Assets/` na raiz (fora do git, só staging local).
- `design/luminaria_prototipo.html` — protótipo HTML aprovado do botão, referência visual
  do checkpoint. Não é o app de verdade, é só pra revisar visual sem precisar de Mac.
- `.github/workflows/build.yml` — roda em todo push, compila pra Simulador sem assinatura
  (valida que o projeto compila, sem precisar de conta Apple Developer).
- `.github/workflows/release.yml` — disparo manual, archive + upload TestFlight. Só
  funciona depois de configurar secrets (certificado, provisioning profile, API key da
  App Store Connect) e trocar o Team ID em `ExportOptions.plist`.

## Branch `teste-gratis-sem-nfc`

Branch separada do `main`, criada porque o usuário não quer pagar a Apple Developer
Program (~$99/ano, R$550) antes de validar se o conceito vale a pena — e ele também não
tem acesso a Mac. Existe em paralelo ao `main`, sem afetar o que já funciona lá.

Diferenças em relação ao `main`:
- `Luminaria.entitlements` fica **vazio** (sem a capability de NFC), porque essa capability
  só é liberada com conta paga — um Apple ID grátis (Personal Team, ou o certificado que o
  AltServer gera) não consegue assiná-la.
- `SettingsView` tem uma seção extra **"Teste sem NFC"** com o botão "Testar disparo do
  Atalho", que chama `ShortcutManager.shared.runSleepShortcut()` direto, sem depender do
  NFC — serve pra validar só a parte "app → Atalho → Foco" sem precisar de tag NFC nem da
  luminária física.
- `.github/workflows/sideload-ipa.yml` — só existe nesta branch. Compila pra dispositivo
  real (`-sdk iphoneos`, `-destination 'generic/platform=iOS'`) **sem assinatura**
  (`CODE_SIGNING_ALLOWED=NO`) e empacota num `.ipa`, disponível como artifact do Actions.
  Esse `.ipa` é pensado pra ser assinado localmente por **AltServer/AltStore** (com Apple ID
  grátis) e instalado no iPhone **sem precisar de Mac** — só Windows. Rodou com sucesso e
  já foi validado num iPhone físico de verdade (primeira vez que o app rodou fora do CI).

**Já validado no device físico via esse caminho** (2026-07-15): app instala, o botão
redondo funciona, o menu abre, e o disparo do Atalho ativa o Foco de verdade. Dois bugs
reais só apareceram nesse teste (ver "Decisões não óbvias" abaixo) — reforça o valor de
testar em device assim que possível, mesmo sem NFC/conta paga ainda.

## Decisões não óbvias (o "porquê")

- **`Luminaria.xcodeproj/project.pbxproj` foi escrito à mão**, linha por linha — não existe
  Xcode/macOS neste ambiente de desenvolvimento (Windows). Qualquer edição nele exige
  cuidado: os IDs de objeto seguem o padrão `AAAAAAAAAAAAAAAAAAAAAA` + 2 dígitos hex.
- **O botão redondo é o "arme/desarme" do modo noite**, não um disparo direto do Atalho.
  Regra pedida pelo usuário: encostar a luminária (NFC) só dispara o Atalho **se o modo
  noite estiver armado no app** — sem isso, encostar não faz nada. Tocar o botão já arma
  E dispara o Atalho na hora (fallback aceito pelo usuário quando perguntei sobre o
  comportamento ideal).
- **Não existe API pública da Apple pra criar um Atalho com a ação "Definir Foco"
  programaticamente**, nem pra ativar Focus Mode direto por um app terceiro. Por isso
  `ShortcutSetupView` só guia o usuário a criar o Atalho manualmente uma vez; o app só
  executa (`shortcuts://run-shortcut`) o que já existe.
- **Sem Mac/conta Apple Developer neste momento** — o pipeline de CI (`build.yml`) existe
  justamente pra validar compilação num runner macOS na nuvem sem precisar comprar nada.
  `release.yml` só entra em jogo quando o usuário tiver a conta paga.
- **Bug real já corrigido**: `NFCNDEFTag` é um *protocolo*, não um enum — não dá pra fazer
  `switch` com casos `.miFare`/`.iso15693`/etc (esses casos existem no tipo `NFCTag`, de uma
  API NFC diferente, a `NFCTagReaderSession`). O fix usa `as?` pra downcast pras classes
  concretas (`NFCMiFareTag`, `NFCISO15693Tag`, `NFCISO7816Tag`, `NFCFeliCaTag`).
- **Processamento de imagem sem instalar nada**: sem Pillow/ImageMagick disponíveis (e o
  usuário pediu pra não instalar pacotes), o recorte/recolorização dos ícones foi feito via
  PowerShell + `System.Drawing` (.NET, já vem no Windows) — ver histórico de commits se
  precisar reprocessar algum asset.
- **Sem `gh` CLI instalado** — o push pro GitHub usa `git` puro por HTTPS; o Git Credential
  Manager do Windows já cuida da autenticação (abre navegador se precisar).
- **Bug real já corrigido (achado testando no device físico)**: o ícone do menu usava
  `.foregroundStyle(.primary)`, que o iOS ajusta pelo modo claro/escuro **do sistema**, não
  pelo `isNightModeArmed` do app. Com o iPhone em modo escuro do sistema, `.primary` virava
  branco e sumia no fundo claro do Living mode. Fix: cores fixas (`menuIconAwake`/
  `menuIconSleep`), sempre com contraste correto nos dois fundos do app, independente do
  tema do iOS. Corrigido tanto no `main` quanto na `teste-gratis-sem-nfc`.
- **`shortcuts://run-shortcut` abre o app Atalhos por completo** (achado testando no
  device) — visualmente incômodo, o usuário não queria isso. Trocado por
  `shortcuts://x-callback-url/run-shortcut` com `x-success`/`x-error` apontando pro esquema
  custom `luminaria://` (registrado via `CFBundleURLTypes` no `Info.plist`, tratado num
  `.onOpenURL` vazio no `ContentView`). A Apple documenta esse modo como uma execução com
  só um aviso rápido (HUD), que volta sozinha pro app de origem — não abre mais o Atalhos
  por completo. Não dá pra deixar 100% silencioso (Apple exige algum indicativo visual de
  que o Foco está sendo alterado, por transparência/segurança).

## ⚠️ Pendência arquitetural importante (não esquecer)

O reconhecimento de NFC hoje (`NFCManager.beginScanning()`, disparado quando o botão
redondo arma o modo noite) é uma **sessão em primeiro plano, com o app aberto, que expira
sozinha em ~60s**. Isso foi uma escolha deliberada pro estágio atual (sem custo, sem
infraestrutura, testável assim que houver um device), **mas o usuário foi explícito: essa
NÃO é a versão final** — pro produto de verdade funcionar, a leitura NFC precisa acontecer
**em segundo plano, sempre, com o app em modo noite**, independente de o app ter sido
aberto recentemente ("se não a proposta quebra", palavras do usuário em 2026-07-14).

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

## Status atual

- Build compila com sucesso no CI em ambas as branches (`main` e `teste-gratis-sem-nfc`).
- UI do botão principal aprovada pelo usuário (checkpoint em `b76aa35`, cores/ícones
  ajustados em `e5f028c`).
- Corrigido em `7ac5451` (main): o botão redondo disparava o Atalho imediatamente (via
  `shortcuts://`), o que tira o app de primeiro plano e mata a sessão NFC recém-iniciada
  antes dela ter chance de reconhecer o toque físico. Agora o botão só arma o modo noite e
  inicia a escuta; o Atalho só dispara quando a tag é de fato reconhecida.
- **App testado com sucesso num iPhone físico de verdade** (2026-07-15), via sideload
  AltStore/AltServer na branch `teste-gratis-sem-nfc` — sem Mac, sem conta Apple Developer
  paga. Fluxo completo validado: botão → Atalho → Foco ativa de verdade. Dois bugs reais
  encontrados e corrigidos nesse teste (ícone do menu sumindo, Atalhos abrindo por
  completo — ver "Decisões não óbvias").
- Ainda faltam: conseguir acesso a conta Apple Developer paga (usuário decidiu adiar por
  causa do custo) pra testar o NFC de verdade (não dá pra testar com Apple ID grátis, é
  bloqueio da própria Apple) e configurar os secrets do `release.yml`. O Atalho "Dormir sem
  celular" já foi criado pelo usuário e testado com sucesso.

## Convenções

- Textos e mensagens de commit em português, combinando com o usuário.
- Commits: sempre criar novo commit, nunca `--amend`, seguindo o fluxo já estabelecido
  nesta conversa (ver `git log`).
