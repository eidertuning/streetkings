(() => {
  'use strict';

  const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'ce_skadmin';
  const ICE_CONFIG = {
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
      { urls: 'stun:stun2.l.google.com:19302' },
      { urls: 'stun:stun3.l.google.com:19302' },
      { urls: 'stun:stun4.l.google.com:19302' }
    ],
    iceCandidatePoolSize: 6
  };

  let sessionId = null;
  let pc = null;
  let canvas = document.getElementById('gameCanvas');
  let gl = null;
  let raf = null;
  let stream = null;
  let gameView = null;
  let started = false;
  let lastSize = { width: 1280, height: 720 };
  let lastFps = 24;

  function nui(event, data) {
    return fetch(`https://${RESOURCE}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {})
    }).then(r => r.json()).catch(() => ({ ok: false }));
  }

  function send(signal) {
    if (!sessionId) return Promise.resolve({ ok: false });
    return nui('skAdminHiddenLiveSignal', { sessionId, signal: signal || {} });
  }

  function makeShader(gl, type, source) {
    const shader = gl.createShader(type);
    if (!shader) throw new Error('shader_create_failed');
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    const info = gl.getShaderInfoLog(shader);
    if (info) console.warn('[ce_skadmin live shader]', info);
    return shader;
  }

  function createGameTexture(gl) {
    const tex = gl.createTexture();
    if (!tex) throw new Error('texture_create_failed');
    const texPixels = new Uint8Array([0, 0, 0, 255]);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, texPixels);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);

    // FiveM game-view hook: this WRAP_T sequence binds the current game frame as external_texture.
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return tex;
  }

  function createGameView(width, height) {
    canvas.width = Number(width || 1280);
    canvas.height = Number(height || 720);
    canvas.style.width = canvas.width + 'px';
    canvas.style.height = canvas.height + 'px';
    lastSize = { width: canvas.width, height: canvas.height };

    const vertex = `
      attribute vec2 a_position;
      attribute vec2 a_texcoord;
      varying vec2 textureCoordinate;
      void main() {
        gl_Position = vec4(a_position, 0.0, 1.0);
        textureCoordinate = a_texcoord;
      }
    `;
    const fragment = `
      varying highp vec2 textureCoordinate;
      uniform sampler2D external_texture;
      void main() {
        gl_FragColor = texture2D(external_texture, textureCoordinate);
      }
    `;

    gl = canvas.getContext('webgl', {
      antialias: false,
      depth: false,
      stencil: false,
      alpha: false,
      desynchronized: true,
      preserveDrawingBuffer: false,
      failIfMajorPerformanceCaveat: false
    });
    if (!gl) throw new Error('webgl_not_available');

    const program = gl.createProgram();
    if (!program) throw new Error('program_create_failed');
    gl.attachShader(program, makeShader(gl, gl.VERTEX_SHADER, vertex));
    gl.attachShader(program, makeShader(gl, gl.FRAGMENT_SHADER, fragment));
    gl.linkProgram(program);
    gl.useProgram(program);

    const tex = createGameTexture(gl);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.uniform1i(gl.getUniformLocation(program, 'external_texture'), 0);

    const vertexBuff = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuff);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const posLoc = gl.getAttribLocation(program, 'a_position');
    gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(posLoc);

    const texBuff = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, texBuff);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);
    const texLoc = gl.getAttribLocation(program, 'a_texcoord');
    gl.vertexAttribPointer(texLoc, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(texLoc);

    gl.viewport(0, 0, canvas.width, canvas.height);

    let disposed = false;
    const render = () => {
      if (disposed) return;
      try {
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
        gl.finish();
      } catch (_) {}
      raf = requestAnimationFrame(render);
    };
    render();

    return {
      dispose() {
        disposed = true;
        if (raf) cancelAnimationFrame(raf);
        raf = null;
        try { gl.getExtension('WEBGL_lose_context')?.loseContext(); } catch (_) {}
      }
    };
  }

  function cleanup(reason) {
    started = false;
    if (raf) cancelAnimationFrame(raf);
    raf = null;
    try { if (pc) pc.close(); } catch (_) {}
    pc = null;
    if (stream) {
      try { stream.getTracks().forEach(t => t.stop()); } catch (_) {}
    }
    stream = null;
    try { if (gameView) gameView.dispose(); } catch (_) {}
    gameView = null;
    gl = null;
    if (sessionId) send({ type: 'broadcaster_closed', reason: reason || 'closed' });
    sessionId = null;
  }

  async function ensureBroadcaster(width, height, fps) {
    if (started && pc && stream) return;
    lastFps = Math.max(8, Math.min(Number(fps || 24), 30));
    gameView = createGameView(width, height);
    await new Promise(resolve => setTimeout(resolve, 450));
    if (!canvas.captureStream) throw new Error('captureStream_not_available');
    stream = canvas.captureStream(lastFps);
    if (!stream || !stream.getVideoTracks || stream.getVideoTracks().length === 0) {
      throw new Error('empty_canvas_stream');
    }

    pc = new RTCPeerConnection(ICE_CONFIG);
    for (const track of stream.getTracks()) pc.addTrack(track, stream);
    pc.onicecandidate = ev => {
      if (ev.candidate) send({ candidate: ev.candidate });
    };
    pc.onconnectionstatechange = () => {
      const st = pc && pc.connectionState;
      if (['closed', 'failed', 'disconnected'].includes(st)) cleanup(st);
    };
    started = true;
  }

  async function handleSignal(signal) {
    if (!sessionId || !signal) return;
    try {
      if (signal.sdp && signal.sdp.type === 'offer') {
        await ensureBroadcaster(lastSize.width, lastSize.height, lastFps);
        await pc.setRemoteDescription(new RTCSessionDescription(signal.sdp));
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await send({ sdp: pc.localDescription });
      } else if (signal.candidate && pc) {
        await pc.addIceCandidate(new RTCIceCandidate(signal.candidate));
      } else if (signal.type === 'stop') {
        cleanup('stop');
      }
    } catch (err) {
      await send({ type: 'broadcaster_error', error: String((err && err.message) || err) });
      cleanup('error');
    }
  }

  window.addEventListener('message', ev => {
    const msg = ev.data || {};
    if (msg.type === 'ceSkAdminLiveStart') {
      cleanup('restart');
      sessionId = String(msg.sessionId || '');
      lastSize = { width: Number(msg.width || 1280), height: Number(msg.height || 720) };
      lastFps = Number(msg.fps || 24);
      if (sessionId) send({ type: 'broadcaster_ready' });
    }
    if (msg.type === 'ceSkAdminLiveSignal') handleSignal(msg.signal);
    if (msg.type === 'ceSkAdminLiveStop') cleanup(msg.reason || 'stop');
  });

  window.addEventListener('beforeunload', () => cleanup('unload'));
})();
