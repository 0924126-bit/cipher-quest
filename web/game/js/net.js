/* net.js - WebSocket client for /ws/game.
 * Emits events via simple callbacks; auto-reconnects while waiting. */
'use strict';

const Net = (() => {
  let ws = null;
  let name = '';
  let closedByUser = false;
  const handlers = {};   // type -> fn

  function on(type, fn) { handlers[type] = fn; }

  function emit(type, data) {
    if (handlers[type]) handlers[type](data);
  }

  function url() {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    return `${proto}://${location.host}/ws/game`;
  }

  function connect(playerName) {
    name = playerName;
    closedByUser = false;
    ws = new WebSocket(url());

    ws.onopen = () => {
      ws.send(JSON.stringify({ type: 'join', name }));
      emit('open');
    };

    ws.onmessage = (ev) => {
      let d;
      try { d = JSON.parse(ev.data); } catch { return; }
      emit(d.type, d);
    };

    ws.onclose = () => {
      emit('close');
      if (!closedByUser) {
        setTimeout(() => connect(name), 2000);
      }
    };

    ws.onerror = () => { try { ws.close(); } catch (_) {} };
  }

  function send(obj) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(obj));
    }
  }

  // input throttle: send at most 15/s, only when changed
  let lastInput = { x: 0, z: 0, decode: false };
  let lastSent = 0;
  function sendInput(x, z, decode) {
    const now = performance.now();
    const changed = x !== lastInput.x || z !== lastInput.z || decode !== lastInput.decode;
    if (!changed && now - lastSent < 400) return;   // heartbeat resend
    if (changed || now - lastSent >= 66) {
      lastInput = { x, z, decode };
      lastSent = now;
      send({ type: 'input', x, z, decode });
    }
  }

  function disconnect() {
    closedByUser = true;
    if (ws) { try { ws.close(); } catch (_) {} }
  }

  return { connect, disconnect, send, sendInput, on };
})();
