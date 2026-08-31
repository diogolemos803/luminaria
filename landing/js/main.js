/* ==========================================================================
   zleepy lamp — landing page
   ========================================================================== */

(function () {
  "use strict";

  /* ------------------------------------------------------------------
     configuração de integrações (preencher antes de publicar)
     ------------------------------------------------------------------ */
  var CONFIG = {
    // endpoint da nossa própria vercel function que fala com a appmax
    // (ver landing/api/preorder.js). as credenciais da appmax NUNCA
    // ficam aqui no front-end — só nas env vars da function.
    preorderApiEndpoint: "/api/preorder",

    metaPixelId: "", // ex: "1234567890123456"
    ga4MeasurementId: "", // ex: "G-XXXXXXXXXX"

    // dados de escassez da pré-venda. trocar por dado real (vindo do
    // backend) quando o checkout estiver integrado.
    unitsTotal: 50,
    unitsReserved: 31
  };

  /* ------------------------------------------------------------------
     0. barra fixa — muda de aparência ao rolar
     ------------------------------------------------------------------ */
  var topbar = document.getElementById("topbar");
  function updateTopbar() {
    topbar.classList.toggle("scrolled", window.scrollY > 12);
  }
  updateTopbar();
  window.addEventListener("scroll", updateTopbar, { passive: true });

  /* ------------------------------------------------------------------
     1. hero — transição por scroll entre duas imagens (scroll-scrubbing)
     ------------------------------------------------------------------

     mecanismo: a seção #hero tem ~375vh de altura, com um palco
     `position: sticky` de 100vh preso à viewport enquanto ela rola.
     o progresso de rolagem DENTRO dessa seção (0 a 1) é usado como
     posição direta de duas imagens — como arrastar a barra de
     progresso de um vídeo pausado, nunca uma animação disparada uma
     vez. as duas imagens preenchem 100% do palco (object-fit: cover)
     e ficam coladas lado a lado, como um rolo de filme de 200% de
     largura que desliza 100%:
       - a imagem inicial (heroImgStart) começa preenchendo o palco
         (translateX 0%) e desliza pra fora à esquerda conforme
         progress → 1 (translateX -100%)
       - a imagem final (heroImgEnd) começa colada logo à direita,
         fora da tela (translateX 100%) e desliza até preencher o
         palco (translateX 0%)
     como as duas têm exatamente o mesmo tamanho e ficam encostadas
     (a borda direita de uma = borda esquerda da outra), não existe
     vão entre elas em nenhum ponto da rolagem — uma sai exatamente
     enquanto a outra entra. rolar pra baixo avança a transição,
     rolar pra cima volta — 1:1 com a posição do scroll.

     imagens em landing/img/lamp-start.png e landing/img/lamp-end.png
     (fotos reais do produto).
     ------------------------------------------------------------------ */

  var heroSection = document.getElementById("hero");
  var heroImgStart = document.getElementById("heroImgStart");
  var heroImgEnd = document.getElementById("heroImgEnd");
  var heroCard = document.getElementById("heroCard");

  var SLIDE_DISTANCE = 100; // % do palco — as imagens são full-bleed, então 100% já as tira/traz por completo

  // depois que a transição termina (progress chega a 1), ainda sobra
  // esse tanto de scroll com a segunda imagem parada e cheia na tela,
  // antes do palco sticky soltar pra próxima seção. tem que bater com
  // a diferença entre a altura de #hero e as vh's de transição no css
  // (425vh de altura - 375vh de transição = 50vh de hold).
  var HOLD_VH = 50;

  function updateHeroImages(progress) {
    var startX = progress * -SLIDE_DISTANCE;
    var endX = (1 - progress) * SLIDE_DISTANCE;
    heroImgStart.style.transform = "translateX(" + startX + "%)";
    heroImgEnd.style.transform = "translateX(" + endX + "%)";
  }

  /* -------- cards de vidro: trocam de lado e conteúdo por faixa -------- */

  var CARD_CONTENT = [
    {
      side: "right",
      kicker: "o objeto",
      title: "madeira maciça",
      text: "torneada à mão, sem plástico, sem tela, sem brilho de notificação. um objeto, não um gadget."
    },
    {
      side: "left",
      kicker: "a luz",
      title: "âmbar e vermelho",
      text: "zero azul no espectro. a luz que avisa o corpo: já pode desacelerar."
    },
    {
      side: "right",
      kicker: "o ritual",
      title: "o nfc dispara o não perturbe",
      text: "encoste o celular no dock. o modo noite ativa sozinho, sem abrir nenhum app."
    }
  ];

  var currentBracket = -1;

  function bracketForProgress(p) {
    if (p < 0.33) return 0;
    if (p < 0.66) return 1;
    return 2;
  }

  function updateHeroCard(progress) {
    var bracket = bracketForProgress(progress);
    if (bracket === currentBracket) return;
    currentBracket = bracket;

    var content = CARD_CONTENT[bracket];
    heroCard.classList.add("fade");

    window.setTimeout(function () {
      heroCard.classList.remove("pos-left", "pos-right");
      heroCard.classList.add(content.side === "left" ? "pos-left" : "pos-right");
      heroCard.querySelector(".hero-card-kicker").textContent = content.kicker;
      heroCard.querySelector(".hero-card-title").textContent = content.title;
      heroCard.querySelector(".hero-card-text").textContent = content.text;
      heroCard.classList.remove("fade");
    }, 260);
  }

  heroCard.classList.add("pos-right");

  /* -------- loop de scroll (throttled via requestAnimationFrame) -------- */

  var ticking = false;

  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      handleScroll();
      ticking = false;
    });
  }

  function handleScroll() {
    var rect = heroSection.getBoundingClientRect();
    var holdHeight = (HOLD_VH / 100) * window.innerHeight;
    var scrollableHeight = heroSection.offsetHeight - window.innerHeight;
    var transitionHeight = scrollableHeight - holdHeight;
    var scrolledIntoSection = -rect.top;

    var progress = transitionHeight > 0 ? scrolledIntoSection / transitionHeight : 0;
    progress = Math.max(0, Math.min(1, progress));

    // progresso à parte pro card: divide o scroll TOTAL da seção (transição
    // + hold) em terços iguais, pra cada um dos 3 cards ficar visível pelo
    // mesmo tempo — diferente do progress acima, que trava em 1 durante o
    // hold (senão o último card ficaria em tela muito mais tempo que os
    // outros dois).
    var cardProgress = scrollableHeight > 0 ? scrolledIntoSection / scrollableHeight : 0;
    cardProgress = Math.max(0, Math.min(1, cardProgress));

    updateHeroImages(progress);
    updateHeroCard(cardProgress);

    updateVillainSection();
  }

  window.addEventListener("scroll", onScroll, { passive: true });
  updateHeroImages(0);

  /* ------------------------------------------------------------------
     2. ato 1 — "o falso vilão": azul esfriando → esquentando na rolagem
     ------------------------------------------------------------------ */

  var villainSection = document.getElementById("falso-vilao");
  var villainBg = document.getElementById("villainBg");
  var COOL_BLUE = [216, 230, 245]; // #D8E6F5
  var WARM_NEUTRAL = [241, 239, 234]; // #F1EFEA

  function lerp(a, b, t) { return a + (b - a) * t; }

  function updateVillainSection() {
    var rect = villainSection.getBoundingClientRect();
    var vh = window.innerHeight;
    // progresso local: 0 quando a seção entra pela base da viewport,
    // 1 quando termina de sair por cima.
    var total = rect.height + vh;
    var traveled = vh - rect.top;
    var t = total > 0 ? traveled / total : 0;
    t = Math.max(0, Math.min(1, t));

    var r = Math.round(lerp(COOL_BLUE[0], WARM_NEUTRAL[0], t));
    var g = Math.round(lerp(COOL_BLUE[1], WARM_NEUTRAL[1], t));
    var b = Math.round(lerp(COOL_BLUE[2], WARM_NEUTRAL[2], t));
    villainBg.style.background = "rgb(" + r + "," + g + "," + b + ")";
  }

  updateVillainSection();

  /* ------------------------------------------------------------------
     3. contadores (count-up lento) — ato "o custo"
     ------------------------------------------------------------------ */

  var statNumbers = document.querySelectorAll(".stat-number");

  function animateCountUp(el) {
    var target = parseFloat(el.dataset.target);
    var suffix = el.dataset.suffix || "";
    var duration = 2200;
    var start = null;

    function step(ts) {
      if (start === null) start = ts;
      var elapsed = ts - start;
      var t = Math.min(1, elapsed / duration);
      // ease-out longo, sem bounce
      var eased = 1 - Math.pow(1 - t, 3);
      var value = Math.round(target * eased);
      el.textContent = value + suffix;
      if (t < 1) window.requestAnimationFrame(step);
    }
    window.requestAnimationFrame(step);
  }

  var statsObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        animateCountUp(entry.target);
        statsObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.6 });

  statNumbers.forEach(function (el) { statsObserver.observe(el); });

  /* ------------------------------------------------------------------
     4. escassez — barra de unidades reservadas
     ------------------------------------------------------------------ */

  var scarcityFill = document.getElementById("scarcityFill");
  var scarcityCount = document.getElementById("scarcityCount");
  var scarcityPct = Math.round((CONFIG.unitsReserved / CONFIG.unitsTotal) * 100);

  var scarcityObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        scarcityFill.style.width = scarcityPct + "%";
        animateSimpleCount(scarcityCount, CONFIG.unitsReserved, 1400);
        scarcityObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });

  if (scarcityFill) scarcityObserver.observe(scarcityFill);

  function animateSimpleCount(el, target, duration) {
    var start = null;
    function step(ts) {
      if (start === null) start = ts;
      var t = Math.min(1, (ts - start) / duration);
      var eased = 1 - Math.pow(1 - t, 3);
      el.textContent = Math.round(target * eased);
      if (t < 1) window.requestAnimationFrame(step);
    }
    window.requestAnimationFrame(step);
  }

  /* ------------------------------------------------------------------
     5. reveal genérico ao entrar na viewport (cards de ato)
     ------------------------------------------------------------------ */

  var revealTargets = document.querySelectorAll(".act .glass, .absolution-line, .absolution-body");
  revealTargets.forEach(function (el) { el.classList.add("reveal"); });

  var revealObserver = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add("in-view");
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.2 });

  revealTargets.forEach(function (el) { revealObserver.observe(el); });

  /* ------------------------------------------------------------------
     6. pré-venda — formulário + integração appmax (pix/boleto/cartão)
     ------------------------------------------------------------------

     fluxo: o navegador nunca guarda credencial nenhuma da appmax — só
     manda os dados do formulário pra nossa própria vercel function em
     `landing/api/preorder.js`, que fala com a api da appmax por trás
     (é ela que guarda client_id/client_secret como variável de ambiente
     na vercel). ver comentários em api/preorder.js pro que falta
     confirmar (endpoint exato de autenticação) antes disso funcionar
     de ponta a ponta.

     cartão de crédito é um caso à parte: o número/cvv do cartão têm
     que ser tokenizados AQUI no navegador pelo script "appmax js" —
     eles nunca devem chegar no nosso backend em texto puro. enquanto
     não temos a url exata desse script (falta confirmar com a appmax),
     `tokenizeCard()` abaixo é só um placeholder que avisa educadamente
     e sugere pix/boleto no lugar.
     ------------------------------------------------------------------ */

  var preorderForm = document.getElementById("preorderForm");
  var preorderStatus = document.getElementById("preorderStatus");
  var preorderResult = document.getElementById("preorderResult");
  var preorderSubmit = document.getElementById("preorderSubmit");
  var cardFields = document.getElementById("cardFields");

  preorderForm.querySelectorAll('input[name="payment"]').forEach(function (radio) {
    radio.addEventListener("change", function () {
      cardFields.hidden = radio.value !== "cartao" || !radio.checked;
      // só reflete a seleção atual (não a do radio que disparou o evento
      // quando ele está sendo desmarcado)
      var checked = preorderForm.querySelector('input[name="payment"]:checked').value;
      cardFields.hidden = checked !== "cartao";
    });
  });

  /**
   * TODO: substituir pelo mecanismo real assim que o parceiro confirmar
   * a url do script "appmax js" e o nome da função de tokenização.
   * Deve devolver uma Promise que resolve com o token do cartão (string)
   * sem que o número/cvv jamais sejam lidos pelo nosso próprio código.
   */
  function tokenizeCard() {
    if (window.AppmaxCheckout && typeof window.AppmaxCheckout.tokenize === "function") {
      return window.AppmaxCheckout.tokenize(cardFields);
    }
    return Promise.reject(new Error("appmax-js-not-loaded"));
  }

  function formatCurrency(cents) {
    return (cents / 100).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
  }

  function showResult(html) {
    preorderResult.innerHTML = html;
    preorderResult.hidden = false;
  }

  function resetSubmitButton() {
    preorderSubmit.disabled = false;
    preorderSubmit.textContent = "reservar minha zleepy lamp";
  }

  preorderForm.addEventListener("submit", function (event) {
    event.preventDefault();

    var name = document.getElementById("preorderName").value.trim();
    var email = document.getElementById("preorderEmail").value.trim();
    var phone = document.getElementById("preorderPhone").value.trim();
    var cpf = document.getElementById("preorderCpf").value.replace(/\D/g, "");
    var payment = preorderForm.querySelector('input[name="payment"]:checked').value;

    preorderStatus.textContent = "";
    preorderResult.hidden = true;

    function invalid(message, fieldId) {
      preorderStatus.textContent = message;
      var field = document.getElementById(fieldId);
      if (field) field.focus();
    }

    if (!name) { invalid("digite seu nome completo.", "preorderName"); return; }
    if (!email || !email.includes("@")) { invalid("digite um e-mail válido.", "preorderEmail"); return; }
    if (!phone) { invalid("digite seu telefone com ddd.", "preorderPhone"); return; }
    if (cpf.length !== 11) { invalid("digite um cpf válido.", "preorderCpf"); return; }

    if (!CONFIG.preorderApiEndpoint) {
      console.warn(
        "[zleepy] integração com a appmax ainda não está configurada. " +
        "defina CONFIG.preorderApiEndpoint em landing/js/main.js para ativar."
      );
      preorderStatus.textContent = "checkout em configuração. anotamos seus dados e avisamos assim que abrir.";
      return;
    }

    var payload = { name: name, email: email, phone: phone, document_number: cpf, payment: payment };

    function sendToBackend() {
      preorderSubmit.disabled = true;
      preorderSubmit.textContent = "processando…";

      fetch(CONFIG.preorderApiEndpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      })
        .then(function (res) { return res.json().then(function (data) { return { ok: res.ok, data: data }; }); })
        .then(function (result) {
          resetSubmitButton();
          var data = result.data;

          if (!result.ok || !data || data.ok === false) {
            var msg = (data && data.message) ||
              "não conseguimos processar agora, tente novamente em instantes.";
            preorderStatus.textContent = msg;
            if (data && data.notConfigured) {
              console.warn("[zleepy] checkout appmax ainda não configurado:", data);
            } else {
              console.error("[zleepy] erro no checkout appmax:", data);
            }
            return;
          }

          console.info("[zleepy] resposta da appmax:", data);

          if (data.payment_method === "pix" && data.pix) {
            showResult(
              '<p><strong>pague com pix pra confirmar a reserva:</strong></p>' +
              (data.pix.qr_code_image ? '<img src="' + data.pix.qr_code_image + '" alt="qr code pix">' : '') +
              (data.pix.qr_code_text ? '<p style="word-break:break-all;font-size:0.75rem;">' + data.pix.qr_code_text + '</p>' : '') +
              '<p>o código também foi enviado pro seu e-mail.</p>'
            );
          } else if (data.payment_method === "boleto" && data.boleto) {
            showResult(
              '<p><strong>seu boleto foi gerado:</strong></p>' +
              (data.boleto.digitable_line ? '<p style="word-break:break-all;font-size:0.8rem;">' + data.boleto.digitable_line + '</p>' : '') +
              (data.boleto.url ? '<a class="btn-amber" href="' + data.boleto.url + '" target="_blank" rel="noopener">baixar boleto</a>' : '')
            );
          } else {
            preorderStatus.textContent = "reserva recebida! confira seu e-mail pra confirmar.";
          }
        })
        .catch(function () {
          resetSubmitButton();
          preorderStatus.textContent = "não conseguimos conectar agora, tente novamente em instantes.";
        });
    }

    if (payment === "cartao") {
      preorderSubmit.disabled = true;
      preorderSubmit.textContent = "validando cartão…";
      tokenizeCard()
        .then(function (token) {
          payload.card_token = token;
          payload.installments = Number(document.getElementById("cardInstallments").value);
          sendToBackend();
        })
        .catch(function () {
          resetSubmitButton();
          preorderStatus.textContent =
            "pagamento por cartão ainda em configuração. tenta pix ou boleto por enquanto?";
        });
      return;
    }

    sendToBackend();
  });

  /* ------------------------------------------------------------------
     7. lgpd — consentimento de cookies (recusa não essenciais por padrão)
     ------------------------------------------------------------------ */

  var CONSENT_KEY = "zleepy_consent";
  var consentBanner = document.getElementById("consentBanner");
  var consentAccept = document.getElementById("consentAccept");
  var consentReject = document.getElementById("consentReject");
  var footerCookiePrefs = document.getElementById("footerCookiePrefs");

  function getConsent() {
    try { return window.localStorage.getItem(CONSENT_KEY); } catch (e) { return null; }
  }
  function setConsent(value) {
    try { window.localStorage.setItem(CONSENT_KEY, value); } catch (e) { /* noop */ }
  }

  function applyConsent(value) {
    if (value === "accepted") loadAnalytics();
  }

  var existingConsent = getConsent();
  if (existingConsent) {
    applyConsent(existingConsent);
  } else {
    consentBanner.hidden = false;
  }

  consentAccept.addEventListener("click", function () {
    setConsent("accepted");
    consentBanner.hidden = true;
    applyConsent("accepted");
  });

  consentReject.addEventListener("click", function () {
    setConsent("rejected");
    consentBanner.hidden = true;
  });

  if (footerCookiePrefs) {
    footerCookiePrefs.addEventListener("click", function (event) {
      event.preventDefault();
      consentBanner.hidden = false;
    });
  }

  /**
   * carrega meta pixel + ga4 somente após consentimento explícito, e
   * somente se os ids tiverem sido configurados no topo deste arquivo.
   * enquanto CONFIG.metaPixelId / ga4MeasurementId estiverem vazios,
   * nada é carregado — evita disparar requisições com ids placeholder.
   */
  function loadAnalytics() {
    if (CONFIG.metaPixelId) {
      /* eslint-disable */
      (function (f, b, e, v, n, t, s) {
        if (f.fbq) return; n = f.fbq = function () { n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments); };
        if (!f._fbq) f._fbq = n; n.push = n; n.loaded = true; n.version = "2.0"; n.queue = [];
        t = b.createElement(e); t.async = true; t.src = v;
        s = b.getElementsByTagName(e)[0]; s.parentNode.insertBefore(t, s);
      })(window, document, "script", "https://connect.facebook.net/en_US/fbevents.js");
      window.fbq("init", CONFIG.metaPixelId);
      window.fbq("track", "PageView");
      /* eslint-enable */
    }

    if (CONFIG.ga4MeasurementId) {
      var s = document.createElement("script");
      s.async = true;
      s.src = "https://www.googletagmanager.com/gtag/js?id=" + CONFIG.ga4MeasurementId;
      document.head.appendChild(s);
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { window.dataLayer.push(arguments); };
      window.gtag("js", new Date());
      window.gtag("config", CONFIG.ga4MeasurementId);
    }
  }
})();
