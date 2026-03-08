(function () {
  var pressTimestamps = [];
  var intervals = [];
  var particles = [];
  var waveData = [];
  var burstBins = new Array(40).fill(0);
  var entropyParticlesMain = [];
  var entropyParticlesMini = [];
  var timers = Object.create(null);

  var count = 0;
  var sessionStart = Date.now();
  var maxBurst = 0;
  var fieldPressCount = 0;
  var wavePhase = 0;
  var entropyVal = 0;
  var burstWindowSec = 30;
  var vizReady = false;
  var currentDockProgress = 0;
  var reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var btn = document.getElementById("pressBtn");
  var countEl = document.getElementById("pressCount");
  var labPanel = document.getElementById("labPanel");
  var pressCol = document.getElementById("pressColumn");
  var flash = document.getElementById("screenFlash");
  var ripples = [document.getElementById("ripple1"), document.getElementById("ripple2"), document.getElementById("ripple3")].filter(Boolean);
  var rippleIdx = 0;
  var statRate = document.getElementById("statRate");
  var statEntropy = document.getElementById("statEntropy");
  var statAvg = document.getElementById("statAvgInterval");
  var statBurst = document.getElementById("statBurst");
  var mdRate = document.getElementById("mdRate");
  var mdEntropy = document.getElementById("mdEntropy");
  var mdAvg = document.getElementById("mdAvg");
  var mdBurst = document.getElementById("mdBurst");

  var waveC = document.getElementById("waveCanvas");
  var intervalC = document.getElementById("intervalCanvas");
  var entropyC = document.getElementById("entropyCanvas");
  var burstC = document.getElementById("burstCanvas");
  var mWaveC = document.getElementById("mWave");
  var mIntervalC = document.getElementById("mInterval");
  var mEntropyC = document.getElementById("mEntropy");
  var mBurstC = document.getElementById("mBurst");
  var waveCtx = waveC && waveC.getContext("2d");
  var intervalCtx = intervalC && intervalC.getContext("2d");
  var entropyCtx = entropyC && entropyC.getContext("2d");
  var burstCtx = burstC && burstC.getContext("2d");
  var mWaveCtx = mWaveC && mWaveC.getContext("2d");
  var mIntervalCtx = mIntervalC && mIntervalC.getContext("2d");
  var mEntropyCtx = mEntropyC && mEntropyC.getContext("2d");
  var mBurstCtx = mBurstC && mBurstC.getContext("2d");

  var pedestal = document.getElementById("pedestalFloat");
  var dome = document.getElementById("domeGroup");
  var pedestalShockwave = document.getElementById("pedestalShockwave");
  var pedestalScrollHint = document.getElementById("pedestalScrollHint");
  var pedestalSvg = pedestal && pedestal.querySelector("svg");
  var sceneWrap = document.getElementById("sceneWrap");
  var sceneStatus = document.getElementById("sceneStatus");
  var fieldCaption = document.getElementById("fieldCaption");
  var miniDash = document.getElementById("miniDash");
  var landingSpot = document.getElementById("landingSpot");
  var person1 = document.getElementById("person1");
  var person2 = document.getElementById("person2");
  var person3 = document.getElementById("person3");
  var person4 = document.getElementById("person4");
  var person4Bubble = document.getElementById("person4Bubble");
  var person4Quote = document.getElementById("person4Quote");

  var ambientC = document.getElementById("ambientCanvas");
  var ambientCtx = ambientC && ambientC.getContext("2d");
  var floaters = [];
  var capturedFloatPos = null;
  var isDocked = false;
  var isUndocking = false;
  var bobPhase = 0;
  var walkPhase = 0;
  var curiosityTimer = null;
  var fieldStatusTimer = null;
  var curiosityHomeX = 560;
  var curiosityTargetX = 512;
  var reggieHomeX = 1035;
  var reggieTargetX = 466;
  var reggieQuotes = [
    "When you feel emotionally ready, gently but decisively interface with the large chromatic circle of destiny in front of you.",
    "Locate the red probability disc, apply finger pressure, and allow the universe to update itself.",
    "Just go ahead and press the big, red existential confirmation button. See what your timeline does."
  ];
  var reggieQuoteIndex = -1;
  var reggieQuoteTimer = null;
  var reggieQuoteHideTimer = null;
  var floatState = {
    baseX: 78,
    baseY: 32,
    x: 0,
    y: 0,
    rot: 0,
    driftPhase1: Math.random() * Math.PI * 2,
    driftPhase2: Math.random() * Math.PI * 2,
    driftPhase3: Math.random() * Math.PI * 2,
    driftPhase4: Math.random() * Math.PI * 2,
    shiftTimer: 0,
    shiftTargetX: 0,
    shiftTargetY: 0,
    shiftCurrentX: 0,
    shiftCurrentY: 0,
    nextShift: 4000 + Math.random() * 7000
  };

  function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
  }

  function smoothstep(value) {
    return value * value * (3 - 2 * value);
  }

  function clearNamedTimer(name) {
    if (!timers[name]) return;
    clearTimeout(timers[name]);
    timers[name] = null;
  }

  function transient(name, el, className, ms, replay) {
    if (!el) return;
    if (replay) {
      el.classList.remove(className);
      void el.offsetWidth;
    }
    el.classList.add(className);
    clearNamedTimer(name);
    timers[name] = setTimeout(function () {
      el.classList.remove(className);
      timers[name] = null;
    }, ms);
  }

  function trimData() {
    if (pressTimestamps.length > 2048) pressTimestamps.splice(0, pressTimestamps.length - 2048);
    if (intervals.length > 1024) intervals.splice(0, intervals.length - 1024);
    if (waveData.length > 160) waveData.splice(0, waveData.length - 160);
  }

  function resizeAmbient() {
    if (!ambientC) return;
    ambientC.width = window.innerWidth;
    ambientC.height = window.innerHeight;
  }

  function initAmbient() {
    if (!ambientCtx) return;
    resizeAmbient();
    for (var i = 0; i < 35; i++) {
      floaters.push({
        x: Math.random() * window.innerWidth,
        y: Math.random() * window.innerHeight,
        r: Math.random() * 2.5 + 0.5,
        vx: (Math.random() - 0.5) * 0.3,
        vy: (Math.random() - 0.5) * 0.3,
        alpha: Math.random() * 0.12 + 0.03
      });
    }
  }

  function drawAmbient() {
    if (!ambientCtx || !ambientC) return;
    ambientCtx.clearRect(0, 0, ambientC.width, ambientC.height);
    for (var i = 0; i < floaters.length; i++) {
      var f = floaters[i];
      f.x += f.vx;
      f.y += f.vy;
      if (f.x < -10) f.x = ambientC.width + 10;
      if (f.x > ambientC.width + 10) f.x = -10;
      if (f.y < -10) f.y = ambientC.height + 10;
      if (f.y > ambientC.height + 10) f.y = -10;
      ambientCtx.beginPath();
      ambientCtx.arc(f.x, f.y, f.r, 0, Math.PI * 2);
      ambientCtx.fillStyle = "rgba(223,44,44," + f.alpha + ")";
      ambientCtx.fill();
    }
    for (var j = particles.length - 1; j >= 0; j--) {
      var p = particles[j];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.04;
      p.life -= 0.015;
      if (p.life <= 0) {
        particles.splice(j, 1);
        continue;
      }
      ambientCtx.beginPath();
      ambientCtx.arc(p.x, p.y, p.r * p.life, 0, Math.PI * 2);
      ambientCtx.fillStyle = "rgba(" + p.color + "," + (p.life * 0.6) + ")";
      ambientCtx.fill();
    }
    requestAnimationFrame(drawAmbient);
  }

  function spawnParticles(x, y, countValue) {
    for (var i = 0; i < countValue; i++) {
      var angle = Math.random() * Math.PI * 2;
      var speed = Math.random() * 4 + 1.5;
      var colors = ["223,44,44", "255,100,70", "255,160,80", "200,30,30"];
      particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed - 2,
        r: Math.random() * 4 + 1.5,
        life: 1,
        color: colors[Math.floor(Math.random() * colors.length)]
      });
    }
  }

  function setupCanvas(canvas) {
    if (!canvas) return;
    var rect = canvas.getBoundingClientRect();
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.round(rect.width * dpr));
    canvas.height = Math.max(1, Math.round(rect.height * dpr));
    canvas._vw = rect.width;
    canvas._vh = rect.height;
    var ctx = canvas.getContext("2d");
    if (ctx && ctx.setTransform) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function resizeCanvases() {
    [waveC, intervalC, entropyC, burstC, mWaveC, mIntervalC, mEntropyC, mBurstC].forEach(setupCanvas);
    vizReady = true;
  }

  function getMetrics(canvas) {
    return {
      width: canvas ? (canvas._vw || canvas.clientWidth || 0) : 0,
      height: canvas ? (canvas._vh || canvas.clientHeight || 0) : 0
    };
  }

  function initEntropy(store, width, height) {
    store.length = 0;
    for (var i = 0; i < 50; i++) {
      store.push({ x: Math.random() * width, y: Math.random() * height, vx: 0, vy: 0, r: Math.random() * 2 + 0.8 });
    }
  }

  function fillRoundedRect(ctx, x, y, width, height, radius) {
    if (ctx.roundRect) {
      ctx.beginPath();
      ctx.roundRect(x, y, width, height, radius);
      ctx.fill();
    } else {
      ctx.fillRect(x, y, width, height);
    }
  }

  function drawWave(ctx, canvas) {
    if (!ctx || !canvas) return;
    var metrics = getMetrics(canvas);
    var width = metrics.width;
    var height = metrics.height;
    if (!width || !height) return;
    ctx.clearRect(0, 0, width, height);
    ctx.strokeStyle = "rgba(255,255,255,0.04)";
    ctx.lineWidth = 1;
    for (var gy = 20; gy < height; gy += 20) {
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(width, gy);
      ctx.stroke();
    }
    ctx.strokeStyle = "rgba(255,255,255,0.08)";
    ctx.beginPath();
    ctx.moveTo(0, height / 2);
    ctx.lineTo(width, height / 2);
    ctx.stroke();
    if (waveData.length < 2) {
      ctx.beginPath();
      ctx.strokeStyle = "rgba(223,44,44,0.2)";
      ctx.lineWidth = 1.5;
      for (var x = 0; x < width; x++) {
        var y = height / 2 + Math.sin(x * 0.03 + wavePhase) * 6;
        if (x === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
      wavePhase += 0.02;
      return;
    }
    ctx.beginPath();
    var gradient = ctx.createLinearGradient(0, 0, width, 0);
    gradient.addColorStop(0, "rgba(223,44,44,0.15)");
    gradient.addColorStop(1, "rgba(223,44,44,0.9)");
    ctx.strokeStyle = gradient;
    ctx.lineWidth = 2;
    var points = waveData.slice(-80);
    for (var i = 0; i < points.length; i++) {
      var px = (i / Math.max(1, 79)) * width;
      var py = height / 2 - points[i] * (height * 0.4);
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.stroke();
  }

  function drawIntervals(ctx, canvas) {
    if (!ctx || !canvas) return;
    var metrics = getMetrics(canvas);
    var width = metrics.width;
    var height = metrics.height;
    if (!width || !height) return;
    ctx.clearRect(0, 0, width, height);
    ctx.strokeStyle = "rgba(255,255,255,0.04)";
    for (var gy = 20; gy < height; gy += 20) {
      ctx.beginPath();
      ctx.moveTo(0, gy);
      ctx.lineTo(width, gy);
      ctx.stroke();
    }
    if (!intervals.length) {
      ctx.fillStyle = "rgba(255,255,255,0.07)";
      ctx.font = "11px 'IBM Plex Mono',monospace";
      ctx.textAlign = "center";
      ctx.fillText("Awaiting data...", width / 2, height / 2);
      return;
    }
    var data = intervals.slice(-25);
    var maxValue = Math.max.apply(null, data) || 1;
    var barWidth = (width - 8) / 25;
    for (var i = 0; i < data.length; i++) {
      var barHeight = (data[i] / maxValue) * (height - 16);
      var x = 4 + i * barWidth;
      var y = height - 8 - barHeight;
      var tone = 1 - (data[i] / maxValue);
      ctx.fillStyle = "rgba(" + (223 + Math.round(tone * 32)) + "," + (44 + Math.round(tone * 56)) + "," + (44 + Math.round(tone * 36)) + ",0.8)";
      fillRoundedRect(ctx, x + 1, y, barWidth - 2, barHeight, 2);
    }
  }

  function drawEntropy(ctx, canvas, store) {
    if (!ctx || !canvas) return;
    var metrics = getMetrics(canvas);
    var width = metrics.width;
    var height = metrics.height;
    if (!width || !height) return;
    if (!store.length || canvas._entropyW !== width || canvas._entropyH !== height) {
      canvas._entropyW = width;
      canvas._entropyH = height;
      initEntropy(store, width, height);
    }
    ctx.clearRect(0, 0, width, height);
    var chaos = Math.min(entropyVal / 3, 1);
    for (var i = 0; i < store.length; i++) {
      var p = store[i];
      p.vx += (Math.random() - 0.5) * chaos * 1.5;
      p.vy += (Math.random() - 0.5) * chaos * 1.5;
      p.vx *= 0.92;
      p.vy *= 0.92;
      p.vx += (width / 2 - p.x) * 0.001;
      p.vy += (height / 2 - p.y) * 0.001;
      p.x += p.vx;
      p.y += p.vy;
      for (var j = i + 1; j < store.length; j++) {
        var q = store[j];
        var dx = q.x - p.x;
        var dy = q.y - p.y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        var maxDist = 45 + chaos * 25;
        if (dist < maxDist) {
          ctx.strokeStyle = "rgba(223,44,44," + ((1 - dist / maxDist) * 0.2) + ")";
          ctx.lineWidth = 0.5;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(q.x, q.y);
          ctx.stroke();
        }
      }
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r + chaos * 1.5, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(223,80,60," + (0.3 + chaos * 0.5) + ")";
      ctx.fill();
    }
  }

  function drawBurst(ctx, canvas) {
    if (!ctx || !canvas) return;
    var metrics = getMetrics(canvas);
    var width = metrics.width;
    var height = metrics.height;
    if (!width || !height) return;
    ctx.clearRect(0, 0, width, height);
    var binWidth = width / burstBins.length;
    var maxValue = Math.max.apply(null, burstBins) || 1;
    for (var i = 0; i < burstBins.length; i++) {
      var tone = burstBins[i] / maxValue;
      ctx.fillStyle = "rgb(" + (30 + Math.round(tone * 200)) + "," + (18 + Math.round(tone * 30)) + "," + (24 + Math.round(tone * 20)) + ")";
      ctx.fillRect(i * binWidth, 0, binWidth, height);
    }
  }

  function drawAllViz() {
    if (vizReady) {
      drawWave(waveCtx, waveC);
      drawIntervals(intervalCtx, intervalC);
      drawEntropy(entropyCtx, entropyC, entropyParticlesMain);
      drawBurst(burstCtx, burstC);
      drawWave(mWaveCtx, mWaveC);
      drawIntervals(mIntervalCtx, mIntervalC);
      drawEntropy(mEntropyCtx, mEntropyC, entropyParticlesMini);
      drawBurst(mBurstCtx, mBurstC);
    }
    requestAnimationFrame(drawAllViz);
  }

  function computeEntropy(values) {
    if (values.length < 3) return 0;
    var bins = {};
    var recent = values.slice(-20);
    for (var i = 0; i < recent.length; i++) {
      var bucket = Math.round(recent[i] / 200) * 200;
      bins[bucket] = (bins[bucket] || 0) + 1;
    }
    var entropy = 0;
    var total = recent.length;
    var keys = Object.keys(bins);
    for (var j = 0; j < keys.length; j++) {
      var p = bins[keys[j]] / total;
      if (p > 0) entropy -= p * Math.log2(p);
    }
    return entropy;
  }

  function computeBurst() {
    if (pressTimestamps.length < 2) return 0;
    var burst = 1;
    var best = 1;
    for (var i = 1; i < pressTimestamps.length; i++) {
      if (pressTimestamps[i] - pressTimestamps[i - 1] < 600) {
        burst++;
        if (burst > best) best = burst;
      } else {
        burst = 1;
      }
    }
    return best;
  }

  function updateStats() {
    var now = Date.now();
    var recent = 0;
    for (var i = pressTimestamps.length - 1; i >= 0; i--) {
      if (now - pressTimestamps[i] > 60000) break;
      recent++;
    }
    entropyVal = computeEntropy(intervals);
    var avg = "\u2014";
    if (intervals.length) {
      var sample = intervals.slice(-10);
      var sum = 0;
      for (var j = 0; j < sample.length; j++) sum += sample[j];
      avg = Math.round(sum / sample.length);
    }
    var burst = computeBurst();
    if (burst > maxBurst) maxBurst = burst;
    var rateValue = recent.toFixed(1);
    var entropyValue = entropyVal > 0 ? entropyVal.toFixed(2) : "\u2014";
    if (statRate) statRate.textContent = rateValue;
    if (statEntropy) statEntropy.textContent = entropyValue;
    if (statAvg) statAvg.textContent = avg;
    if (statBurst) statBurst.textContent = maxBurst;
    if (mdRate) mdRate.textContent = rateValue;
    if (mdEntropy) mdEntropy.textContent = entropyValue;
    if (mdAvg) mdAvg.textContent = avg;
    if (mdBurst) mdBurst.textContent = maxBurst;
  }

  function updateFloatAnchor() {
    if (window.innerWidth <= 650) {
      floatState.baseX = 76;
      floatState.baseY = 72;
    } else if (window.innerWidth <= 980) {
      floatState.baseX = 80;
      floatState.baseY = 56;
    } else {
      floatState.baseX = 78;
      floatState.baseY = 32;
    }
  }

  function ensureFloatingHost() {
    if (!pedestal || pedestal.parentElement === document.body) return;
    document.body.appendChild(pedestal);
  }

  function placePedestalFixed(x, y, rot, width, height) {
    if (!pedestal) return;
    ensureFloatingHost();
    pedestal.classList.remove("docked");
    pedestal.style.position = "fixed";
    pedestal.style.left = "0";
    pedestal.style.top = "0";
    pedestal.style.width = (width || 140) + "px";
    pedestal.style.height = (height || 320) + "px";
    pedestal.style.transform = "translate(" + x + "px, " + y + "px) rotate(" + rot + "deg)";
    floatState.x = x;
    floatState.y = y;
    floatState.rot = rot;
  }

  function tickFloatState() {
    updateFloatAnchor();
    var vw = window.innerWidth;
    var vh = window.innerHeight;
    var maxX = Math.max(8, vw - 148);
    var maxY = Math.max(8, vh - 328);
    if (reducedMotion) {
      floatState.x = clamp((floatState.baseX / 100) * vw, 8, maxX);
      floatState.y = clamp((floatState.baseY / 100) * vh, 8, maxY);
      floatState.rot = 0;
      return;
    }
    floatState.driftPhase1 += 0.008;
    floatState.driftPhase2 += 0.011;
    floatState.driftPhase3 += 0.006;
    floatState.driftPhase4 += 0.0035;
    var driftX = Math.sin(floatState.driftPhase1) * 18 + Math.sin(floatState.driftPhase2 * 0.7) * 10;
    var driftY = Math.cos(floatState.driftPhase3) * 14 + Math.sin(floatState.driftPhase4 * 1.3) * 8;
    floatState.rot = Math.sin(floatState.driftPhase1 * 0.6) * 4 + Math.sin(floatState.driftPhase2 * 0.4) * 2.5;
    floatState.shiftTimer += 16;
    if (floatState.shiftTimer > floatState.nextShift) {
      floatState.shiftTimer = 0;
      floatState.nextShift = 4000 + Math.random() * 7000;
      floatState.shiftTargetX = (Math.random() - 0.5) * 120;
      floatState.shiftTargetY = (Math.random() - 0.5) * 80;
    }
    floatState.shiftCurrentX += (floatState.shiftTargetX - floatState.shiftCurrentX) * 0.008;
    floatState.shiftCurrentY += (floatState.shiftTargetY - floatState.shiftCurrentY) * 0.008;
    floatState.x = clamp((floatState.baseX / 100) * vw + driftX + floatState.shiftCurrentX, 8, maxX);
    floatState.y = clamp((floatState.baseY / 100) * vh + driftY + floatState.shiftCurrentY, 8, maxY);
  }

  function getSceneMapping() {
    if (!sceneWrap) return null;
    var rect = sceneWrap.getBoundingClientRect();
    var sx = rect.width / 960;
    var sy = rect.height / 420;
    var scale = Math.max(sx, sy);
    return {
      rect: rect,
      scale: scale,
      offX: (rect.width - 960 * scale) / 2,
      offY: (rect.height - 420 * scale) / 2
    };
  }

  function getDockScreenPos() {
    var map = getSceneMapping();
    if (!map) return null;
    var height = 34 * map.scale;
    var width = height * (140 / 320);
    return {
      x: map.rect.left + map.offX + 500 * map.scale - width / 2,
      y: map.rect.top + map.offY + 362 * map.scale - height,
      width: width,
      height: height
    };
  }

  function getDockAbsolutePos() {
    var map = getSceneMapping();
    if (!map) return null;
    var height = 34 * map.scale;
    var width = height * (140 / 320);
    return {
      left: map.offX + 500 * map.scale - width / 2,
      top: map.offY + 362 * map.scale - height,
      width: width,
      height: height
    };
  }

  function getScrollProgress() {
    if (!sceneWrap) return 0;
    var rect = sceneWrap.getBoundingClientRect();
    var vh = window.innerHeight;
    if (reducedMotion) {
      return rect.top < vh * 0.6 && rect.bottom > vh * 0.2 ? 1 : 0;
    }
    return clamp((vh * 0.9 - rect.top) / (vh * 0.9 - vh * 0.3), 0, 1);
  }

  function resetSceneStatus() {
    if (!sceneStatus) return;
    if (isDocked) {
      sceneStatus.textContent = "FIELD UNIT ACTIVE - AWAITING PRESSES";
      sceneStatus.classList.add("show");
    } else if (currentDockProgress > 0.2 && !isUndocking) {
      sceneStatus.textContent = "FIELD UNIT DEPLOYING... " + Math.round(currentDockProgress * 100) + "%";
      sceneStatus.classList.add("show");
    } else {
      sceneStatus.classList.remove("show");
    }
  }

  function queueSceneStatusReset(ms) {
    if (fieldStatusTimer) clearTimeout(fieldStatusTimer);
    fieldStatusTimer = setTimeout(function () {
      fieldStatusTimer = null;
      resetSceneStatus();
    }, ms);
  }

  function applyDockProgress(progress) {
    if (!pedestal || !sceneWrap || isDocked || isUndocking) return;
    currentDockProgress = progress;
    if (progress > 0 && progress < 1 && !capturedFloatPos) {
      capturedFloatPos = { x: floatState.x, y: floatState.y, rot: floatState.rot };
    }
    if (progress === 0) capturedFloatPos = null;
    if (miniDash) miniDash.classList.toggle("visible", progress > 0.6);
    if (progress <= 0) {
      if (landingSpot) {
        landingSpot.setAttribute("stroke", "rgba(223,44,44,0)");
        landingSpot.setAttribute("fill", "rgba(223,44,44,0)");
      }
      if (!fieldStatusTimer) resetSceneStatus();
      pedestal.style.filter = "";
      placePedestalFixed(floatState.x, floatState.y, floatState.rot, 140, 320);
      return;
    }
    ensureFloatingHost();
    pedestal.classList.remove("docked");
    pedestal.style.position = "fixed";
    pedestal.style.left = "0";
    pedestal.style.top = "0";
    var dock = getDockScreenPos();
    if (!dock) return;
    var t = smoothstep(progress);
    var src = capturedFloatPos || { x: floatState.x, y: floatState.y, rot: floatState.rot };
    pedestal.style.width = (140 + (dock.width - 140) * t) + "px";
    pedestal.style.height = (320 + (dock.height - 320) * t) + "px";
    pedestal.style.transform = "translate(" + (src.x + (dock.x - src.x) * t) + "px, " + (src.y + (dock.y - src.y) * t) + "px) rotate(" + (src.rot * (1 - t)) + "deg)";
    pedestal.style.filter = "drop-shadow(0 " + (20 * (1 - t) + 3 * t) + "px " + (40 * (1 - t) + 6 * t) + "px rgba(22,28,38,.25))";
    if (landingSpot) {
      var alpha = Math.max(0, (t - 0.3) / 0.7);
      landingSpot.setAttribute("stroke", "rgba(223,44,44," + (alpha * 0.6) + ")");
      landingSpot.setAttribute("fill", "rgba(223,44,44," + (alpha * 0.1) + ")");
    }
    if (!fieldStatusTimer && sceneStatus && progress > 0.2) {
      sceneStatus.textContent = "FIELD UNIT DEPLOYING... " + Math.round(t * 100) + "%";
      sceneStatus.classList.add("show");
    }
    if (progress >= 1) finalizeDock();
  }

  function finalizeDock() {
    if (!pedestal || !sceneWrap || isDocked) return;
    var absolute = getDockAbsolutePos();
    if (!absolute) return;
    isDocked = true;
    isUndocking = false;
    capturedFloatPos = null;
    sceneWrap.appendChild(pedestal);
    pedestal.classList.remove("undocking");
    pedestal.classList.add("docked");
    pedestal.style.position = "absolute";
    pedestal.style.left = absolute.left + "px";
    pedestal.style.top = absolute.top + "px";
    pedestal.style.width = absolute.width + "px";
    pedestal.style.height = absolute.height + "px";
    pedestal.style.transform = "rotate(0deg)";
    pedestal.style.filter = "";
    if (miniDash) miniDash.classList.add("visible");
    if (fieldCaption) fieldCaption.textContent = "Button deployed. Press it and watch telemetry below.";
    if (fieldStatusTimer) {
      clearTimeout(fieldStatusTimer);
      fieldStatusTimer = null;
    }
    resetSceneStatus();
    animateCuriosity();
  }

  function undockFromScene() {
    if (!pedestal || !isDocked || isUndocking) return;
    isUndocking = true;
    isDocked = false;
    currentDockProgress = 0;
    if (miniDash) miniDash.classList.remove("visible");
    if (landingSpot) {
      landingSpot.setAttribute("stroke", "rgba(223,44,44,0)");
      landingSpot.setAttribute("fill", "rgba(223,44,44,0)");
    }
    if (fieldStatusTimer) {
      clearTimeout(fieldStatusTimer);
      fieldStatusTimer = null;
    }
    if (sceneStatus) {
      sceneStatus.textContent = "FIELD UNIT RETRACTING...";
      sceneStatus.classList.add("show");
    }
    var rect = pedestal.getBoundingClientRect();
    ensureFloatingHost();
    pedestal.classList.remove("docked");
    pedestal.style.position = "fixed";
    pedestal.style.left = "0";
    pedestal.style.top = "0";
    pedestal.style.transform = "translate(" + rect.left + "px, " + rect.top + "px) rotate(0deg)";
    pedestal.style.width = rect.width + "px";
    pedestal.style.height = rect.height + "px";
    if (reducedMotion) {
      pedestal.classList.remove("undocking");
      pedestal.style.filter = "";
      placePedestalFixed(floatState.x, floatState.y, floatState.rot, 140, 320);
      isUndocking = false;
      capturedFloatPos = null;
      if (fieldCaption) fieldCaption.textContent = "Scroll this section into view to deploy the field unit.";
      if (sceneStatus) sceneStatus.classList.remove("show");
      resetPeople();
      return;
    }
    pedestal.classList.add("undocking");
    void pedestal.offsetWidth;
    pedestal.style.width = "140px";
    pedestal.style.height = "320px";
    pedestal.style.filter = "";
    pedestal.style.transform = "translate(" + floatState.x + "px, " + floatState.y + "px) rotate(" + floatState.rot + "deg)";
    setTimeout(function () {
      pedestal.classList.remove("undocking");
      isUndocking = false;
      capturedFloatPos = null;
      if (fieldCaption) fieldCaption.textContent = "Scroll this section into view to deploy the field unit.";
      if (sceneStatus) sceneStatus.classList.remove("show");
      resetPeople();
    }, 1250);
  }

  function animateCuriosity() {
    if (!person2 && !person4) return;
    if (curiosityTimer) clearTimeout(curiosityTimer);
    curiosityTimer = setTimeout(function () {
      if (!isDocked) return;
      startReggieQuotes();
      var startedAt = performance.now();
      function step(now) {
        if (!isDocked) return;
        var curiosityEased = smoothstep(clamp((now - startedAt) / 2200, 0, 1));
        var reggieEased = smoothstep(clamp((now - startedAt - 420) / 2400, 0, 1));
        if (person2) person2.setAttribute("transform", "translate(" + (curiosityHomeX + (curiosityTargetX - curiosityHomeX) * curiosityEased) + ",332)");
        if (person4) person4.setAttribute("transform", "translate(" + (reggieHomeX + (reggieTargetX - reggieHomeX) * reggieEased) + ",332)");
        if (curiosityEased < 1 || reggieEased < 1) requestAnimationFrame(step);
      }
      requestAnimationFrame(step);
    }, 600);
  }

  function resetPeople() {
    if (!person2 && !person4) return;
    if (curiosityTimer) {
      clearTimeout(curiosityTimer);
      curiosityTimer = null;
    }
    stopReggieQuotes();
    var current2 = person2 && person2.getAttribute("transform");
    var match2 = current2 && current2.match(/translate\(([\d.]+)/);
    var person2StartX = match2 ? parseFloat(match2[1]) : curiosityHomeX;
    var current4 = person4 && person4.getAttribute("transform");
    var match4 = current4 && current4.match(/translate\(([\d.]+)/);
    var person4StartX = match4 ? parseFloat(match4[1]) : reggieHomeX;
    var startedAt = performance.now();
    function step(now) {
      var eased = smoothstep(clamp((now - startedAt) / 800, 0, 1));
      if (person2) person2.setAttribute("transform", "translate(" + (person2StartX + (curiosityHomeX - person2StartX) * eased) + ",332)");
      if (person4) person4.setAttribute("transform", "translate(" + (person4StartX + (reggieHomeX - person4StartX) * eased) + ",332)");
      if (eased < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function getPersonX(person, fallback) {
    if (!person) return fallback;
    var current = person.getAttribute("transform");
    var match = current && current.match(/translate\(([\d.]+)/);
    return match ? parseFloat(match[1]) : fallback;
  }

  function isReggieNearButton() {
    return getPersonX(person4, reggieHomeX) <= reggieTargetX + 28;
  }

  function setReggieBubbleVisible(visible) {
    if (!person4Bubble) return;
    person4Bubble.setAttribute("display", visible ? "inline" : "none");
    person4Bubble.setAttribute("opacity", visible ? "1" : "0");
  }

  function renderReggieQuote(text) {
    if (!person4Quote) return;
    while (person4Quote.firstChild) person4Quote.removeChild(person4Quote.firstChild);
    var words = String(text || "").split(/\s+/);
    var lines = [];
    var currentLine = "";
    var maxChars = 28;
    for (var i = 0; i < words.length; i++) {
      var candidate = currentLine ? currentLine + " " + words[i] : words[i];
      if (currentLine && candidate.length > maxChars) {
        lines.push(currentLine);
        currentLine = words[i];
      } else {
        currentLine = candidate;
      }
    }
    if (currentLine) lines.push(currentLine);
    while (lines.length > 4) {
      lines[lines.length - 2] += " " + lines[lines.length - 1];
      lines.pop();
    }
    for (var j = 0; j < lines.length; j++) {
      var tspan = document.createElementNS("http://www.w3.org/2000/svg", "tspan");
      tspan.setAttribute("x", "36");
      tspan.setAttribute("dy", j === 0 ? "0" : "11");
      tspan.textContent = lines[j];
      person4Quote.appendChild(tspan);
    }
  }

  function setReggieQuote() {
    if (!person4Quote || !reggieQuotes.length) return;
    var nextIndex = Math.floor(Math.random() * reggieQuotes.length);
    if (reggieQuotes.length > 1 && nextIndex === reggieQuoteIndex) nextIndex = (nextIndex + 1) % reggieQuotes.length;
    reggieQuoteIndex = nextIndex;
    renderReggieQuote(reggieQuotes[nextIndex]);
  }

  function startReggieQuotes() {
    if (!person4Quote || !reggieQuotes.length) return;
    stopReggieQuotes();
    queueReggieQuote(600);
  }

  function stopReggieQuotes() {
    if (reggieQuoteTimer) {
      clearTimeout(reggieQuoteTimer);
      reggieQuoteTimer = null;
    }
    if (reggieQuoteHideTimer) {
      clearTimeout(reggieQuoteHideTimer);
      reggieQuoteHideTimer = null;
    }
    setReggieBubbleVisible(false);
  }

  function queueReggieQuote(delay) {
    if (!person4Quote || !reggieQuotes.length) return;
    if (reggieQuoteTimer) clearTimeout(reggieQuoteTimer);
    reggieQuoteTimer = setTimeout(function () {
      reggieQuoteTimer = null;
      if (!isDocked) return;
      if (!isReggieNearButton()) {
        queueReggieQuote(240);
        return;
      }
      setReggieQuote();
      setReggieBubbleVisible(true);
      if (reggieQuoteHideTimer) clearTimeout(reggieQuoteHideTimer);
      reggieQuoteHideTimer = setTimeout(function () {
        reggieQuoteHideTimer = null;
        setReggieBubbleVisible(false);
        queueReggieQuote(2600 + Math.random() * 2600);
      }, 3200 + Math.random() * 1400);
    }, delay);
  }

  function interruptReggieQuote() {
    if (!isDocked) return;
    if (reggieQuoteTimer) {
      clearTimeout(reggieQuoteTimer);
      reggieQuoteTimer = null;
    }
    if (reggieQuoteHideTimer) {
      clearTimeout(reggieQuoteHideTimer);
      reggieQuoteHideTimer = null;
    }
    setReggieBubbleVisible(false);
    queueReggieQuote(2400 + Math.random() * 2200);
  }

  function walkPeople() {
    walkPhase += 0.3;
    if (person1) person1.setAttribute("transform", "translate(" + ((((walkPhase * 0.8) % 1060) - 50)) + ",332)");
    if (person3) person3.setAttribute("transform", "translate(" + (1010 - ((walkPhase * 0.5) % 1060)) + ",332)");
    if (person2 && !isDocked) person2.setAttribute("transform", "translate(" + curiosityHomeX + ",332)");
    if (person4 && !isDocked) person4.setAttribute("transform", "translate(" + reggieHomeX + ",332)");
    requestAnimationFrame(walkPeople);
  }

  function renderPedestalLoop() {
    tickFloatState();
    currentDockProgress = getScrollProgress();
    if (isDocked) {
      if (currentDockProgress < 0.5) {
        undockFromScene();
      } else if (pedestal) {
        var absolute = getDockAbsolutePos();
        if (absolute) {
          bobPhase += reducedMotion ? 0 : 0.025;
          pedestal.style.left = absolute.left + "px";
          pedestal.style.top = (absolute.top + (reducedMotion ? 0 : Math.sin(bobPhase) * 1.2)) + "px";
          pedestal.style.width = absolute.width + "px";
          pedestal.style.height = absolute.height + "px";
        }
      }
    } else if (!isUndocking) {
      applyDockProgress(currentDockProgress);
      if (currentDockProgress <= 0 && pedestal) placePedestalFixed(floatState.x, floatState.y, floatState.rot, 140, 320);
    }
    requestAnimationFrame(renderPedestalLoop);
  }

  function getPedestalCenter() {
    if (!pedestal) return { x: window.innerWidth / 2, y: Math.max(70, window.innerHeight * 0.25) };
    var rect = pedestal.getBoundingClientRect();
    return { x: rect.left + rect.width * 0.5, y: rect.top + rect.height * 0.22 };
  }

  function spawnPedestalSparkles(cx, cy, countValue) {
    for (var i = 0; i < countValue; i++) {
      var sparkle = document.createElement("div");
      sparkle.className = "sparkle";
      var angle = (Math.PI * 2 / countValue) * i + (Math.random() - 0.5) * 0.5;
      var dist = 20 + Math.random() * 50;
      sparkle.style.left = cx + "px";
      sparkle.style.top = cy + "px";
      sparkle.style.setProperty("--sx", Math.cos(angle) * dist + "px");
      sparkle.style.setProperty("--sy", Math.sin(angle) * dist - 14 + "px");
      sparkle.style.width = (2 + Math.random() * 4) + "px";
      sparkle.style.height = sparkle.style.width;
      sparkle.style.background = ["#ff4444", "#ff7744", "#ffaa44", "#df2c2c"][Math.floor(Math.random() * 4)];
      document.body.appendChild(sparkle);
      void sparkle.offsetWidth;
      sparkle.classList.add("go");
      (function (node) { setTimeout(function () { node.remove(); }, 800); })(sparkle);
    }
  }

  function nudgeEntropy(store) {
    for (var i = 0; i < store.length; i++) {
      store[i].vx += (Math.random() - 0.5) * 6;
      store[i].vy += (Math.random() - 0.5) * 6;
    }
  }

  function addBurstSample(now) {
    var elapsed = (now - sessionStart) / 1000;
    var index = clamp(Math.floor(((elapsed % burstWindowSec) / burstWindowSec) * burstBins.length), 0, burstBins.length - 1);
    burstBins[index] += 1;
  }

  function injectWaveFromHold(holdMs) {
    var clamped = clamp(holdMs, 40, 1600);
    var norm = (clamped - 40) / 1560;
    var peak = 0.85 + norm * 1.15;
    var tailCount = 5 + Math.round(norm * 7);
    var freq = 1.05 + norm * 0.5;
    var decayBase = 0.34 - norm * 0.08;
    waveData.push(peak);
    setTimeout(function () {
      for (var i = 0; i < tailCount; i++) {
        var step = i + 1;
        waveData.push(Math.sin(step * freq) * Math.exp(-step * decayBase) * peak * 0.72);
      }
      trimData();
    }, 30);
  }

  function runPedestalEffects() {
    if (!pedestal) return;
    var center = getPedestalCenter();
    transient("pedGlow", pedestal, "pressed-glow", 420, false);
    if (pedestalShockwave) {
      pedestalShockwave.style.left = center.x + "px";
      pedestalShockwave.style.top = center.y + "px";
      pedestalShockwave.classList.remove("go");
      void pedestalShockwave.offsetWidth;
      pedestalShockwave.classList.add("go");
    }
    spawnPedestalSparkles(center.x, center.y, isDocked ? 8 : 14);
    spawnParticles(center.x, center.y, 10);
    if (pedestalScrollHint) {
      var label = pedestalScrollHint.querySelector("span");
      if (label) label.textContent = isDocked ? "field logged" : "telemetry live";
      pedestalScrollHint.style.left = (center.x - 36) + "px";
      pedestalScrollHint.style.top = (center.y + 48) + "px";
      transient("pedHint", pedestalScrollHint, "show", 520, false);
    }
  }

  function getButtonCenter() {
    if (!btn) return { x: window.innerWidth / 2, y: Math.max(70, window.innerHeight * 0.25) };
    var rect = btn.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  }

  function handlePress(holdMs, source) {
    var now = Date.now();
    count++;
    pressTimestamps.push(now);
    if (pressTimestamps.length > 1) intervals.push(now - pressTimestamps[pressTimestamps.length - 2]);
    trimData();
    if (countEl) {
      countEl.textContent = count;
      transient("count", countEl, "bump", 200, true);
    }
    if (ripples.length) {
      var ring = ripples[rippleIdx % ripples.length];
      ring.classList.remove("animate");
      void ring.offsetWidth;
      ring.classList.add("animate");
      rippleIdx++;
    }
    transient("pressGlow", pressCol, "glow", 400, false);
    transient("labPulse", labPanel, "pulse", 500, false);
    transient("flash", flash, "flash", 120, true);
    var origin = source === "pedestal" ? getPedestalCenter() : getButtonCenter();
    spawnParticles(origin.x, origin.y, source === "pedestal" ? 10 : 14);
    injectWaveFromHold(holdMs);
    addBurstSample(now);
    nudgeEntropy(entropyParticlesMain);
    nudgeEntropy(entropyParticlesMini);
    if (source === "pedestal" && isDocked) {
      interruptReggieQuote();
    }
    if (source === "pedestal" && isDocked && sceneStatus) {
      fieldPressCount++;
      sceneStatus.textContent = "PRESS #" + fieldPressCount + " RECORDED - FIELD DATA LOGGED";
      sceneStatus.classList.add("show");
      queueSceneStatusReset(900);
    }
    updateStats();
  }

  var buttonActive = false;
  var buttonDownAt = 0;
  var buttonReleaseTimer = null;
  var pedestalActive = false;
  var pedestalDownAt = 0;
  var pedestalReleaseTimer = null;
  var activePointerId = null;
  var pedestalPointerId = null;
  var lastTouchStart = 0;
  var pedestalLastTouchStart = 0;
  var pedestalTouchId = null;

  function finalizeButton(cancelled) {
    if (!buttonActive) return;
    if (buttonReleaseTimer !== null) {
      clearTimeout(buttonReleaseTimer);
      buttonReleaseTimer = null;
    }
    buttonActive = false;
    if (btn) btn.classList.remove("is-pressed");
    if (!cancelled) handlePress(clamp(Date.now() - buttonDownAt, 40, 1600), "lab");
  }

  function beginButton() {
    if (!btn) return;
    if (buttonActive && buttonReleaseTimer !== null) finalizeButton(false);
    else if (buttonActive) return;
    if (buttonReleaseTimer !== null) {
      clearTimeout(buttonReleaseTimer);
      buttonReleaseTimer = null;
    }
    buttonActive = true;
    buttonDownAt = Date.now();
    btn.classList.add("is-pressed");
  }

  function endButton(cancelled) {
    if (!buttonActive) return;
    if (cancelled) {
      finalizeButton(true);
      return;
    }
    var elapsed = Date.now() - buttonDownAt;
    if (elapsed >= 90) {
      finalizeButton(false);
      return;
    }
    if (buttonReleaseTimer !== null) return;
    buttonReleaseTimer = setTimeout(function () {
      buttonReleaseTimer = null;
      finalizeButton(false);
    }, 90 - elapsed);
  }

  function triggerExternalPress(holdMs, source) {
    var ms = clamp(Number(holdMs) || 120, 40, 1600);
    if (btn && !buttonActive) {
      btn.classList.add("is-pressed");
      clearNamedTimer("proxyButton");
      timers.proxyButton = setTimeout(function () {
        if (btn && !buttonActive) btn.classList.remove("is-pressed");
        timers.proxyButton = null;
      }, 140);
    }
    handlePress(ms, source || "external");
  }

  function finalizePedestal(cancelled) {
    if (!pedestalActive) return;
    if (pedestalReleaseTimer !== null) {
      clearTimeout(pedestalReleaseTimer);
      pedestalReleaseTimer = null;
    }
    pedestalActive = false;
    if (dome) {
      dome.classList.remove("pushed");
      dome.style.transform = "";
    }
    if (dome && !cancelled) {
      dome.classList.remove("rebound");
      void dome.offsetWidth;
      dome.classList.add("rebound");
    }
    if (dome && cancelled) dome.classList.remove("rebound");
    if (!cancelled) {
      runPedestalEffects();
      triggerExternalPress(clamp(Date.now() - pedestalDownAt, 40, 1600), "pedestal");
    }
  }

  function beginPedestal() {
    if (!pedestal || !dome || isUndocking) return;
    if (pedestalActive && pedestalReleaseTimer !== null) finalizePedestal(false);
    else if (pedestalActive) return;
    if (pedestalReleaseTimer !== null) {
      clearTimeout(pedestalReleaseTimer);
      pedestalReleaseTimer = null;
    }
    pedestalActive = true;
    pedestalDownAt = Date.now();
    dome.style.transform = "";
    dome.classList.remove("rebound");
    dome.classList.remove("pushed");
    void dome.offsetWidth;
    dome.classList.add("pushed");
  }

  function endPedestal(cancelled) {
    if (!pedestalActive) return;
    if (cancelled) {
      finalizePedestal(true);
      return;
    }
    var elapsed = Date.now() - pedestalDownAt;
    if (elapsed >= 90) {
      finalizePedestal(false);
      return;
    }
    if (pedestalReleaseTimer !== null) return;
    pedestalReleaseTimer = setTimeout(function () {
      pedestalReleaseTimer = null;
      finalizePedestal(false);
    }, 90 - elapsed);
  }

  window.BRB = window.BRB || {};
  window.BRB.triggerPress = triggerExternalPress;

  initAmbient();
  resizeAmbient();
  resizeCanvases();
  updateStats();
  drawAmbient();
  drawAllViz();
  walkPeople();
  renderPedestalLoop();

  window.addEventListener("resize", function () {
    resizeAmbient();
    resizeCanvases();
    if (isDocked && pedestal) {
      var absolute = getDockAbsolutePos();
      if (absolute) {
        pedestal.style.left = absolute.left + "px";
        pedestal.style.top = absolute.top + "px";
        pedestal.style.width = absolute.width + "px";
        pedestal.style.height = absolute.height + "px";
      }
    }
  });

  if (pedestalSvg) {
    if ("PointerEvent" in window) {
      pedestalSvg.addEventListener("pointerdown", function (e) {
        if (e.pointerType === "mouse" && e.button !== 0) return;
        e.preventDefault();
        pedestalPointerId = e.pointerId;
        if (pedestalSvg.setPointerCapture) {
          try { pedestalSvg.setPointerCapture(e.pointerId); } catch (_) {}
        }
        beginPedestal();
      });
      pedestalSvg.addEventListener("pointerup", function (e) {
        if (pedestalPointerId !== null && e.pointerId !== pedestalPointerId) return;
        endPedestal(false);
        pedestalPointerId = null;
      });
      pedestalSvg.addEventListener("pointercancel", function (e) {
        if (pedestalPointerId !== null && e.pointerId !== pedestalPointerId) return;
        endPedestal(true);
        pedestalPointerId = null;
      });
      pedestalSvg.addEventListener("lostpointercapture", function () {
        pedestalPointerId = null;
        endPedestal(true);
      });
    } else {
      pedestalSvg.addEventListener("touchstart", function (e) {
        pedestalLastTouchStart = Date.now();
        e.preventDefault();
        if (!e.changedTouches || !e.changedTouches.length) return;
        pedestalTouchId = e.changedTouches[0].identifier;
        beginPedestal();
      }, { passive: false });
      pedestalSvg.addEventListener("touchend", function (e) {
        if (pedestalTouchId === null) return;
        e.preventDefault();
        endPedestal(false);
        pedestalTouchId = null;
      }, { passive: false });
      pedestalSvg.addEventListener("touchcancel", function () {
        endPedestal(true);
        pedestalTouchId = null;
      });
      pedestalSvg.addEventListener("click", function () {
        if (Date.now() - pedestalLastTouchStart < 700) return;
        beginPedestal();
        endPedestal(false);
      });
    }
    pedestalSvg.addEventListener("keydown", function (e) {
      if (!e.repeat && (e.key === "Enter" || e.key === " ")) {
        e.preventDefault();
        beginPedestal();
      }
    });
    pedestalSvg.addEventListener("keyup", function (e) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        endPedestal(false);
      }
    });
    pedestalSvg.addEventListener("blur", function () {
      endPedestal(true);
    });
    if (window.matchMedia && window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
      pedestalSvg.addEventListener("mouseenter", function () {
        if (!dome || dome.classList.contains("pushed")) return;
        dome.style.transition = "transform 300ms cubic-bezier(0.34, 1.56, 0.64, 1)";
        dome.style.transform = "scale(1.04)";
      });
      pedestalSvg.addEventListener("mouseleave", function () {
        if (!dome || dome.classList.contains("pushed")) return;
        dome.style.transform = "";
      });
    }
  }

  if (btn) {
    if ("PointerEvent" in window) {
      btn.addEventListener("pointerdown", function (e) {
        if (e.pointerType === "mouse" && e.button !== 0) return;
        e.preventDefault();
        activePointerId = e.pointerId;
        if (btn.setPointerCapture) {
          try { btn.setPointerCapture(e.pointerId); } catch (_) {}
        }
        beginButton();
      });
      btn.addEventListener("pointerup", function (e) {
        if (activePointerId !== null && e.pointerId !== activePointerId) return;
        endButton(false);
        activePointerId = null;
      });
      btn.addEventListener("pointercancel", function (e) {
        if (activePointerId !== null && e.pointerId !== activePointerId) return;
        endButton(true);
        activePointerId = null;
      });
      btn.addEventListener("lostpointercapture", function () {
        activePointerId = null;
        endButton(true);
      });
    } else {
      btn.addEventListener("touchstart", function (e) {
        lastTouchStart = Date.now();
        e.preventDefault();
        beginButton();
      }, { passive: false });
      btn.addEventListener("touchend", function (e) {
        e.preventDefault();
        endButton(false);
      }, { passive: false });
      btn.addEventListener("touchcancel", function () {
        endButton(true);
      });
      btn.addEventListener("click", function () {
        if (Date.now() - lastTouchStart < 700) return;
        beginButton();
        endButton(false);
      });
    }
    btn.addEventListener("keydown", function (e) {
      if (!e.repeat && (e.key === "Enter" || e.key === " ")) {
        e.preventDefault();
        beginButton();
      }
    });
    btn.addEventListener("keyup", function (e) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        endButton(false);
      }
    });
  }

  setInterval(function () {
    if (!waveData.length) return;
    waveData.push(waveData[waveData.length - 1] * 0.85);
    if (waveData.length > 160) waveData.splice(0, waveData.length - 160);
    if (Math.abs(waveData[waveData.length - 1]) < 0.01) waveData.push(0);
  }, 60);

  setInterval(updateStats, 1000);
})();
