/* ==========================================================================
   vercel function — pré-venda via appmax
   ==========================================================================

   fala com a api da appmax por trás da landing page, pra que
   client_id/client_secret nunca fiquem expostos no navegador.

   configurar como variáveis de ambiente no painel da vercel (project
   settings → environment variables) — NUNCA commitar credencial aqui:
     APPMAX_ENV             "sandbox" ou "production" (default: sandbox)
     APPMAX_CLIENT_ID       fornecido pela appmax / parceiro de pagamento
     APPMAX_CLIENT_SECRET   fornecido pela appmax / parceiro de pagamento

   TODO (bloqueante — confirmar com o parceiro/appmax antes de produção):
     1. endpoint e formato EXATOS de autenticação. `getAccessToken()`
        abaixo é uma tentativa razoável baseada no que a doc pública
        menciona (client_credentials em /oauth2/token, tokens curtos,
        sem refresh token) — mas não foi confirmada nem testada contra
        o sandbox de verdade ainda.
     2. nomes exatos dos campos na resposta de pix/boleto (qr code,
        linha digitável). abaixo tentamos vários nomes prováveis como
        fallback, mas isso só se confirma testando contra o sandbox.
     3. payload exato de /v1/payments/credit-card — a doc lista os
        campos mas não deixa 100% claro o aninhamento; seguimos o mesmo
        padrão do pix/boleto (payment_data.credit_card.*).
   ========================================================================== */

var APPMAX_ENV = process.env.APPMAX_ENV || "sandbox";
var IS_SANDBOX = APPMAX_ENV !== "production";

var AUTH_BASE = IS_SANDBOX ? "https://auth.sandboxappmax.com.br" : "https://auth.appmax.com.br";
var API_BASE = IS_SANDBOX ? "https://api.sandboxappmax.com.br" : "https://api.appmax.com.br";

var PRODUCT = {
  sku: "zleepy-lamp-01",
  name: "zleepy lamp",
  unit_value: 49900 // r$499,00 em centavos
};

var cachedToken = null; // { value, expiresAt } — evita gerar token novo a cada request

function splitName(fullName) {
  var parts = fullName.trim().split(/\s+/);
  var first = parts.shift() || fullName;
  var last = parts.join(" ") || first;
  return { first_name: first, last_name: last };
}

function getClientIp(req) {
  var fwd = req.headers["x-forwarded-for"];
  if (fwd) return String(fwd).split(",")[0].trim();
  return (req.socket && req.socket.remoteAddress) || "0.0.0.0";
}

async function getAccessToken() {
  var clientId = process.env.APPMAX_CLIENT_ID;
  var clientSecret = process.env.APPMAX_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    var notConfiguredErr = new Error("appmax_not_configured");
    notConfiguredErr.notConfigured = true;
    throw notConfiguredErr;
  }

  if (cachedToken && cachedToken.expiresAt > Date.now() + 5000) {
    return cachedToken.value;
  }

  // TODO: confirmar com a appmax o grant_type e os nomes de campo exatos.
  var res = await fetch(AUTH_BASE + "/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret
    })
  });

  if (!res.ok) {
    var errBody = await res.text();
    throw new Error("appmax_auth_failed: " + res.status + " " + errBody);
  }

  var data = await res.json();
  var token = data.access_token || data.token || (data.data && data.data.access_token);
  var expiresIn = data.expires_in || 3300; // segundos — default conservador (~55min)

  if (!token) throw new Error("appmax_auth_failed: token ausente na resposta");

  cachedToken = { value: token, expiresAt: Date.now() + expiresIn * 1000 };
  return token;
}

async function appmaxFetch(path, token, body) {
  var res = await fetch(API_BASE + path, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: "Bearer " + token
    },
    body: JSON.stringify(body)
  });
  var data = await res.json().catch(function () { return {}; });
  if (!res.ok) {
    var err = new Error("appmax_request_failed: " + path);
    err.status = res.status;
    err.data = data;
    throw err;
  }
  return data;
}

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.status(405).json({ ok: false, message: "método não permitido" });
    return;
  }

  var body = req.body || {};
  var name = body.name;
  var email = body.email;
  var phone = body.phone;
  var documentNumber = body.document_number;
  var payment = body.payment;
  var cardToken = body.card_token;
  var installments = body.installments;

  if (!name || !email || !phone || !documentNumber || !payment) {
    res.status(400).json({ ok: false, message: "dados incompletos." });
    return;
  }

  try {
    var token = await getAccessToken();
    var splitted = splitName(name);

    var customerRes = await appmaxFetch("/v1/customers", token, {
      first_name: splitted.first_name,
      last_name: splitted.last_name,
      email: email,
      phone: phone,
      document_number: documentNumber,
      ip: getClientIp(req)
    });
    var customerId = customerRes && customerRes.data && customerRes.data.customer && customerRes.data.customer.id;
    if (!customerId) throw new Error("appmax_customer_id_ausente");

    var orderRes = await appmaxFetch("/v1/orders", token, {
      customer_id: customerId,
      products_value: PRODUCT.unit_value,
      discount_value: 0,
      shipping_value: 0,
      products: [
        { sku: PRODUCT.sku, name: PRODUCT.name, quantity: 1, unit_value: PRODUCT.unit_value, type: "physical" }
      ]
    });
    var orderId = orderRes && orderRes.data && orderRes.data.order && orderRes.data.order.id;
    if (!orderId) throw new Error("appmax_order_id_ausente");

    if (payment === "pix") {
      var pixRes = await appmaxFetch("/v1/payments/pix", token, {
        order_id: orderId,
        payment_data: { pix: { document_number: documentNumber } }
      });
      var p = (pixRes && pixRes.data && pixRes.data.payment) || pixRes.data || pixRes;
      res.status(200).json({
        ok: true,
        payment_method: "pix",
        pix: {
          qr_code_image: p.qr_code_image || p.qrcode_image || p.qr_code_base64 || null,
          qr_code_text: p.qr_code || p.emv || p.pix_copy_paste || p.copy_paste || null
        },
        raw: pixRes
      });
      return;
    }

    if (payment === "boleto") {
      var boletoRes = await appmaxFetch("/v1/payments/boleto", token, {
        order_id: orderId,
        payment_data: { boleto: { document_number: documentNumber } }
      });
      var b = (boletoRes && boletoRes.data && boletoRes.data.payment) || boletoRes.data || boletoRes;
      res.status(200).json({
        ok: true,
        payment_method: "boleto",
        boleto: {
          url: b.url || b.pdf || b.boleto_url || null,
          digitable_line: b.digitable_line || b.linha_digitavel || b.barcode || null
        },
        raw: boletoRes
      });
      return;
    }

    if (payment === "cartao") {
      if (!cardToken) {
        res.status(400).json({ ok: false, message: "cartão não foi validado — tenta pix ou boleto." });
        return;
      }
      var cardRes = await appmaxFetch("/v1/payments/credit-card", token, {
        order_id: orderId,
        customer_id: customerId,
        payment_data: {
          credit_card: {
            token: cardToken,
            installments: installments || 1,
            holder_name: name,
            holder_document_number: documentNumber,
            soft_descriptor: "ZLEEPYLAMP"
          }
        }
      });
      res.status(200).json({ ok: true, payment_method: "cartao", raw: cardRes });
      return;
    }

    res.status(400).json({ ok: false, message: "forma de pagamento inválida." });
  } catch (err) {
    if (err.notConfigured) {
      res.status(200).json({
        ok: false,
        notConfigured: true,
        message: "checkout em configuração — anotamos seus dados e avisamos assim que abrir."
      });
      return;
    }
    console.error("[preorder] erro:", err, err.data || "");
    res.status(500).json({ ok: false, message: "não conseguimos processar agora — tente novamente em instantes." });
  }
};
