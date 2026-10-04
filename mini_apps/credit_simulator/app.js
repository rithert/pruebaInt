// Simulador de crédito: mini app de un "tercero" dentro de la super app.
//
// Protocolo del bridge (v1), mensajes JSON { v, id, type, payload }:
//   mini app → app:  ready | get_token | request_credit | close
//   app → mini app:  context | credit_result
// La mini app NUNCA recibe la sesión del cliente: solo un token delegado de
// 5 minutos con permiso "credit:quote". Solicitar el crédito lo hace la app.
'use strict';

const PROTOCOL_VERSION = 1;
const $ = (id) => document.getElementById(id);

let context = null; // { token, apiBaseUrl, firstName, theme }
let lastQuote = null;
let debounce;

const host = window.SuperAppHost; // canal que inyecta la app (JavaScriptChannel)

function send(type, payload = {}) {
  if (!host) return;
  host.postMessage(
    JSON.stringify({ v: PROTOCOL_VERSION, id: String(Date.now()), type, payload }),
  );
}

// La app llama a esta función con cada mensaje.
window.SuperAppBridge = {
  receive(json) {
    let message;
    try {
      message = JSON.parse(json);
    } catch {
      return;
    }
    if (message.v !== PROTOCOL_VERSION) return;
    if (message.type === 'context') onContext(message.payload);
    if (message.type === 'credit_result') onCreditResult(message.payload);
  },
};

function onContext(payload) {
  const firstLoad = context === null;
  context = payload;
  applyTheme(payload.theme ?? {});
  if (firstLoad) {
    $('intro').textContent = `Hola ${payload.firstName ?? ''}, elige monto y plazo.`;
    $('form').hidden = false;
  }
  scheduleQuote(0);
}

function applyTheme(theme) {
  const root = document.documentElement.style;
  for (const [key, value] of Object.entries(theme)) {
    if (/^#[0-9a-f]{6}$/i.test(value)) root.setProperty(`--${key}`, value);
  }
}

// --- Cotización contra el BFF con el token delegado ------------------------

function scheduleQuote(delay = 300) {
  clearTimeout(debounce);
  $('amountLabel').textContent = formatUsd(Number($('amount').value) * 100);
  debounce = setTimeout(quote, delay);
}

async function quote() {
  if (!context) return;
  $('request').disabled = true;
  const body = {
    amountMinor: Number($('amount').value) * 100,
    termMonths: Number($('term').value),
  };
  try {
    const response = await fetch(`${context.apiBaseUrl}/v1/mini-api/credit/quote`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${context.token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (response.status === 401) {
      // El token delegado expiró: se pide uno nuevo a la app anfitriona.
      send('get_token');
      return;
    }
    if (!response.ok) throw new Error(String(response.status));
    lastQuote = await response.json();
    renderQuote(lastQuote);
  } catch {
    showMessage('No pudimos calcular la cuota. Revisa tu conexión e intenta de nuevo.');
  }
}

function renderQuote(q) {
  $('payment').textContent = formatUsd(q.monthlyPaymentMinor);
  $('details').textContent =
    `${q.termMonths} cuotas · tasa ${(q.annualRate * 100).toFixed(1).replace('.', ',')}% anual · ` +
    `intereses ${formatUsd(q.totalInterestMinor)} · total ${formatUsd(q.totalPaymentMinor)}`;
  $('message').hidden = true;
  $('request').disabled = false;
}

// --- Solicitud: la ejecuta la app con confirmación del cliente -------------

function onCreditResult(payload) {
  if (payload.status === 'submitted') {
    showMessage(`¡Listo! Tu solicitud quedó en revisión (ref. ${payload.reference}).`);
  } else if (payload.status === 'cancelled') {
    showMessage('Solicitud cancelada. Puedes ajustar el monto o el plazo.');
  } else {
    showMessage('No pudimos enviar la solicitud. Intenta de nuevo en un momento.');
  }
  $('request').disabled = false;
}

function showMessage(text) {
  $('message').textContent = text;
  $('message').hidden = false;
}

// --- Formato es-EC (igual que la app y el BFF) ----------------------------

function formatUsd(minor) {
  const dollars = Math.trunc(Math.abs(minor) / 100)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  const cents = String(Math.abs(minor) % 100).padStart(2, '0');
  return `${minor < 0 ? '-' : ''}$${dollars},${cents}`;
}

// --- Arranque ---------------------------------------------------------------

$('amount').addEventListener('input', () => scheduleQuote());
$('term').addEventListener('change', () => scheduleQuote(0));
$('request').addEventListener('click', () => {
  if (!lastQuote) return;
  $('request').disabled = true;
  send('request_credit', {
    amountMinor: lastQuote.amountMinor,
    termMonths: lastQuote.termMonths,
    monthlyPaymentMinor: lastQuote.monthlyPaymentMinor,
  });
});
$('close').addEventListener('click', () => send('close'));

if (host) {
  send('ready');
} else {
  $('intro').hidden = true;
  $('standalone').hidden = false;
}
