// Coralight promo: a deterministic 2D canvas animation. render(t) draws
// the frame at time t (seconds). window.CFG = {w, h, captions, endcard,
// t0}. Sprites (pre-rasterized SVG) come in window.SPR.
'use strict';
const INK = '#241a3a';
const cv = document.getElementById('c');
const ctx = cv.getContext('2d');
let W = 1080, H = 1920, K = 1, CX = 540, CY = 960;

function setup(w, h) {
	W = w; H = h; cv.width = w; cv.height = h;
	K = Math.min(w / 1080, h / 1350);
	CX = w / 2; CY = h / 2;
}

// ---------------------------------------------------------------- math
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const lerp = (a, b, u) => a + (b - a) * u;
const sat = (x) => clamp(x, 0, 1);
const span = (t, a, b) => sat((t - a) / (b - a));
const eOut = (u) => 1 - Math.pow(1 - u, 3);
const eIn = (u) => u * u * u;
const eIO = (u) => (u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2);
const eBack = (u) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(u - 1, 3) + c1 * Math.pow(u - 1, 2); };
const eElastic = (u) => (u <= 0 ? 0 : u >= 1 ? 1 : Math.pow(2, -10 * u) * Math.sin((u * 10 - 0.75) * (2 * Math.PI / 3)) + 1);
function rnd(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }

// Design coordinates: origin at the screen center, 1 unit = K px.
const X = (x) => CX + x * K;
const Y = (y) => CY + y * K;

// ---------------------------------------------------------------- drawing
function rr(x, y, w, h, r) {
	ctx.beginPath();
	ctx.moveTo(x + r, y);
	ctx.arcTo(x + w, y, x + w, y + h, r);
	ctx.arcTo(x + w, y + h, x, y + h, r);
	ctx.arcTo(x, y + h, x, y, r);
	ctx.arcTo(x, y, x + w, y, r);
	ctx.closePath();
}

function vgrad(y0, y1, stops) {
	const g = ctx.createLinearGradient(0, y0, 0, y1);
	stops.forEach((c, i) => g.addColorStop(i / (stops.length - 1), c));
	return g;
}

function fillBg(stops) {
	ctx.fillStyle = vgrad(0, H, stops);
	ctx.fillRect(0, 0, W, H);
}

const ANCH = {
	diverSad: [360, 960], diverHappy: [360, 960], diverStar: [360, 960], diverGold: [360, 960],
	rigSad: [360, 960], rigHappy: [360, 960], rigStar: [360, 960],
	armP: [70, 240], armO: [70, 240], armG: [70, 240], armE: [70, 240],
	chest: [330, 560], coin: [70, 70], bar: [70, 35], emerald: [70, 80], crystal: [70, 80], ruby: [70, 80], pearl: [70, 80],
};

// A sprite at design (x, y) with scale s (1 = its SVG size in design units).
function spr(name, x, y, s, rot = 0, alpha = 1, sx = 1, sy = 1) {
	const im = SPR[name];
	if (!im) return;
	const a = ANCH[name];
	const r = im.ratio;
	ctx.save();
	ctx.globalAlpha *= alpha;
	ctx.translate(X(x), Y(y));
	ctx.rotate(rot);
	ctx.scale(s * K * sx / r, s * K * sy / r);
	ctx.drawImage(im, -a[0] * r, -a[1] * r);
	ctx.restore();
}

function glow(x, y, r, color, a) {
	const g = ctx.createRadialGradient(X(x), Y(y), 0, X(x), Y(y), r * K);
	g.addColorStop(0, color.replace('A', a));
	g.addColorStop(1, color.replace('A', 0));
	ctx.fillStyle = g;
	ctx.fillRect(X(x) - r * K, Y(y) - r * K, 2 * r * K, 2 * r * K);
}

function rays(x, y, n, color, rot, len = 2200) {
	ctx.save();
	ctx.translate(X(x), Y(y));
	ctx.rotate(rot);
	const g = ctx.createRadialGradient(0, 0, 0, 0, 0, len * K);
	g.addColorStop(0, color);
	g.addColorStop(1, 'rgba(255,255,255,0)');
	ctx.fillStyle = g;
	for (let i = 0; i < n; i++) {
		const a = (i / n) * Math.PI * 2;
		const da = Math.PI / n * 0.5;
		ctx.beginPath();
		ctx.moveTo(0, 0);
		ctx.lineTo(Math.cos(a - da) * len * K, Math.sin(a - da) * len * K);
		ctx.lineTo(Math.cos(a + da) * len * K, Math.sin(a + da) * len * K);
		ctx.closePath();
		ctx.fill();
	}
	ctx.restore();
}

function sparkle(x, y, r, a = 1) {
	ctx.save();
	ctx.globalAlpha *= a;
	ctx.translate(X(x), Y(y));
	ctx.fillStyle = '#fffbe6';
	ctx.beginPath();
	const R = r * K, q = R * 0.14;
	ctx.moveTo(0, -R); ctx.quadraticCurveTo(q, -q, R, 0); ctx.quadraticCurveTo(q, q, 0, R);
	ctx.quadraticCurveTo(-q, q, -R, 0); ctx.quadraticCurveTo(-q, -q, 0, -R);
	ctx.fill();
	ctx.restore();
}

function bubble(x, y, r, a = 1) {
	ctx.save();
	ctx.globalAlpha *= a;
	ctx.strokeStyle = 'rgba(255,255,255,0.8)';
	ctx.lineWidth = Math.max(2, r * 0.12 * K);
	ctx.fillStyle = 'rgba(230,251,255,0.15)';
	ctx.beginPath(); ctx.arc(X(x), Y(y), r * K, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
	ctx.fillStyle = 'rgba(255,255,255,0.9)';
	ctx.beginPath(); ctx.arc(X(x - r * 0.38), Y(y - r * 0.38), r * 0.22 * K, 0, Math.PI * 2); ctx.fill();
	ctx.restore();
}

// Big bold game text with a thick ink outline and a drop shadow.
function text(s, x, y, size, opt = {}) {
	const fill = opt.fill || 'white';
	ctx.save();
	ctx.translate(X(x), Y(y));
	ctx.rotate(opt.rot || 0);
	const sc = opt.scale === undefined ? 1 : opt.scale;
	ctx.scale(sc, sc);
	ctx.globalAlpha *= opt.alpha === undefined ? 1 : opt.alpha;
	ctx.font = `${size * K}px Nunito`;
	ctx.textAlign = opt.align || 'center';
	ctx.textBaseline = 'middle';
	ctx.lineJoin = 'round';
	ctx.fillStyle = 'rgba(10,8,30,0.45)';
	ctx.lineWidth = size * K * 0.26;
	ctx.strokeStyle = 'rgba(10,8,30,0.45)';
	ctx.strokeText(s, 0, size * K * 0.09);
	ctx.strokeStyle = opt.stroke || INK;
	ctx.strokeText(s, 0, 0);
	if (fill === 'gold') {
		ctx.fillStyle = vgrad(-size * K * 0.45, size * K * 0.45, ['#fff7b0', '#ffd23a', '#f39a12']);
	} else if (fill === 'white') {
		ctx.fillStyle = vgrad(-size * K * 0.45, size * K * 0.45, ['#ffffff', '#ffffff', '#cfe9ff']);
	} else {
		ctx.fillStyle = fill;
	}
	ctx.fillText(s, 0, 0);
	ctx.restore();
}

function button(x, y, w, h, label, colors, press = 0, opt = {}) {
	ctx.save();
	ctx.translate(X(x), Y(y));
	const s = (opt.scale || 1);
	ctx.scale(s, s);
	const ww = w * K, hh = h * K, d = 14 * K * (1 - press);
	ctx.fillStyle = 'rgba(10,8,30,0.35)';
	rr(-ww / 2, -hh / 2 + 18 * K, ww, hh, hh * 0.32); ctx.fill();
	ctx.fillStyle = INK;
	rr(-ww / 2 - 6 * K, -hh / 2 - 6 * K + 14 * K - d, ww + 12 * K, hh + 12 * K, hh * 0.36); ctx.fill();
	ctx.fillStyle = colors[2];
	rr(-ww / 2, -hh / 2 + 14 * K - d, ww, hh, hh * 0.3); ctx.fill();
	ctx.fillStyle = vgrad(-hh / 2 + 14 * K - d - 14 * K, hh / 2 - d, [colors[0], colors[1]]);
	rr(-ww / 2, -hh / 2 - (14 * K - 14 * K) + (14 * K - d) - 14 * K, ww, hh, hh * 0.3); ctx.fill();
	ctx.fillStyle = 'rgba(255,255,255,0.35)';
	rr(-ww / 2 + 18 * K, -hh / 2 + 8 * K + (14 * K - d) - 14 * K, ww - 36 * K, hh * 0.32, hh * 0.16); ctx.fill();
	ctx.restore();
	text(label, x, y + (14 - 14 * (1 - press)) * s - 4 * s, opt.size || h * 0.5, { scale: s });
}

function coinIcon(x, y, r) { spr('coin', x, y, r / 60); }

function fmt(v) {
	if (v < 1000) return Math.floor(v).toString();
	const u = ['K', 'M', 'B', 'T', 'aa'];
	let i = -1;
	while (v >= 1000 && i < u.length - 1) { v /= 1000; i++; }
	return (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + u[i];
}

// The money panel at the top.
function counter(v, bump, alpha = 1) {
	if (alpha <= 0) return;
	const y = -H / 2 / K + 120;
	ctx.save();
	ctx.globalAlpha = alpha;
	const s = 1 + bump * 0.12;
	ctx.translate(X(0), Y(y));
	ctx.scale(s, s);
	ctx.translate(-X(0), -Y(y));
	const w = 470, h = 120;
	ctx.fillStyle = 'rgba(10,8,30,0.35)';
	rr(X(-w / 2), Y(y - h / 2 + 10), w * K, h * K, 40 * K); ctx.fill();
	ctx.fillStyle = INK;
	rr(X(-w / 2 - 7), Y(y - h / 2 - 7), (w + 14) * K, (h + 14) * K, 46 * K); ctx.fill();
	ctx.fillStyle = vgrad(Y(y - h / 2), Y(y + h / 2), ['#2b3e7a', '#16224d']);
	rr(X(-w / 2), Y(y - h / 2), w * K, h * K, 40 * K); ctx.fill();
	ctx.restore();
	ctx.save();
	ctx.globalAlpha = alpha;
	spr('coin', -150 * s, y, 0.75 * s, 0);
	text(fmt(v), 40, y + 4, 78 * s, { fill: 'gold' });
	ctx.restore();
}

// Hand cursor (simple glove) pointing at design (x, y); press 0..1.
function hand(x, y, press, alpha = 1) {
	if (alpha <= 0) return;
	ctx.save();
	ctx.globalAlpha = alpha;
	ctx.translate(X(x), Y(y));
	const s = K * (1 - press * 0.15);
	ctx.scale(s, s);
	ctx.rotate(-0.35);
	ctx.lineJoin = 'round';
	ctx.lineWidth = 9;
	ctx.strokeStyle = INK;
	ctx.fillStyle = '#ffffff';
	// finger
	rr(-16, 0, 34, 110, 17); ctx.fill(); ctx.stroke();
	// palm
	rr(-30, 80, 110, 120, 36); ctx.fill(); ctx.stroke();
	for (let i = 0; i < 3; i++) { rr(18 + i * 26, 60 + i * 6, 28, 70, 14); ctx.fill(); ctx.stroke(); }
	ctx.fillStyle = '#4aa8ff';
	rr(-34, 186, 118, 34, 12); ctx.fill(); ctx.stroke();
	ctx.restore();
	if (press > 0.5) {
		ctx.save();
		ctx.strokeStyle = `rgba(255,255,255,${(press - 0.5) * 1.6})`;
		ctx.lineWidth = 8 * K;
		ctx.beginPath(); ctx.arc(X(x), Y(y), (40 + (1 - press) * 60) * K, 0, Math.PI * 2); ctx.stroke();
		ctx.restore();
	}
}

// Flying coins: each with a start time, from (x0,y0) to the counter.
function flyingCoins(t, list) {
	const ty = -H / 2 / K + 120;
	for (const c of list) {
		const u = (t - c.t) / 0.7;
		if (u < 0 || u > 1) continue;
		const e = eIn(u);
		const x = lerp(c.x, -150, e) + Math.sin(u * Math.PI) * c.dx;
		const y = lerp(c.y, ty, e) - Math.sin(u * Math.PI) * 160;
		spr('coin', x, y, 0.42 * (1 - u * 0.3), u * 6, 1);
	}
}

// Gold "+N" floating up from a point.
function popText(t, t0, x, y, s, size = 70, fill = 'gold') {
	const u = (t - t0) / 1.0;
	if (u < 0 || u > 1) return;
	text(s, x, y - eOut(u) * 140, size, { fill, alpha: u < 0.7 ? 1 : (1 - u) / 0.3, scale: eBack(sat(u * 3)) });
}

// Confetti burst from a point at t0 (stateless).
function confetti(t, t0, x, y, n, seed, spread = 1) {
	const dt = t - t0;
	if (dt < 0 || dt > 2.2) return;
	const cols = ['#ffd23a', '#ff6f91', '#5fd3ff', '#8aff8a', '#c08aff', '#ffffff'];
	for (let i = 0; i < n; i++) {
		const a = rnd(seed + i) * Math.PI * 2;
		const sp = (500 + rnd(seed + i * 3) * 900) * spread;
		const px = x + Math.cos(a) * sp * dt * 0.8;
		const py = y + Math.sin(a) * sp * dt * 0.8 - 300 * dt + 900 * dt * dt;
		ctx.save();
		ctx.globalAlpha = sat(1.6 - dt);
		ctx.translate(X(px), Y(py));
		ctx.rotate(dt * 8 + i);
		ctx.fillStyle = cols[i % cols.length];
		ctx.fillRect(-9 * K, -5 * K, 18 * K, 10 * K * Math.abs(Math.cos(dt * 9 + i)));
		ctx.restore();
	}
}

// Coin fountain out of a point, continuous between t0 and t1.
function fountain(t, t0, t1, x, y, rate, seed, power = 1) {
	const life = 1.6;
	const start = Math.max(t0, t - life);
	const first = Math.ceil(start * rate), last = Math.floor(Math.min(t, t1) * rate);
	const kinds = ['coin', 'coin', 'coin', 'emerald', 'coin', 'ruby', 'coin', 'crystal', 'coin', 'pearl'];
	for (let i = first; i <= last; i++) {
		const ts = i / rate, dt = t - ts;
		if (dt < 0 || dt > life) continue;
		const a = -Math.PI / 2 + (rnd(seed + i) - 0.5) * 1.6;
		const v = (900 + rnd(seed + i * 7) * 900) * power;
		const px = x + Math.cos(a) * v * dt;
		const py = y + Math.sin(a) * v * dt + 1100 * dt * dt;
		const k = kinds[i % kinds.length];
		spr(k, px, py, k === 'coin' ? 0.5 : 0.6, dt * (3 + rnd(i) * 4) * (i % 2 ? 1 : -1), sat((life - dt) * 3));
	}
}

// Coins raining down over the whole screen.
function coinRain(t, t0, rate, seed, alpha = 1) {
	const top = -H / 2 / K - 100, fall = H / K + 300;
	const first = Math.ceil(Math.max(t0, t - 2.4) * rate), last = Math.floor(t * rate);
	for (let i = first; i <= last; i++) {
		const dt = t - i / rate;
		const x = (rnd(seed + i) - 0.5) * W / K;
		const y = top + dt * fall / 2.0 * (0.8 + rnd(seed + i * 5) * 0.5);
		spr('coin', x, y, 0.35 + rnd(i) * 0.3, dt * 5 * (i % 2 ? 1 : -1), alpha);
	}
}

// ---------------------------------------------------------------- scenery
function seaBg(grey, t) {
	const c = (a, b) => lerpColor(a, b, grey);
	fillBg([c('#4fd8ee', '#5d6b78'), c('#1d9bd2', '#3e4b58'), c('#0f5aa4', '#28323f'), c('#08306a', '#161d27')]);
	// light shafts from the surface
	ctx.save();
	for (let i = 0; i < 6; i++) {
		const x0 = (i / 6 - 0.45) * W + Math.sin(t * 0.4 + i) * 30;
		const g = ctx.createLinearGradient(0, 0, 0, H * 0.8);
		g.addColorStop(0, `rgba(255,255,255,${0.16 * (1 - grey * 0.7)})`);
		g.addColorStop(1, 'rgba(255,255,255,0)');
		ctx.fillStyle = g;
		ctx.beginPath();
		ctx.moveTo(x0, 0); ctx.lineTo(x0 + 90 * K, 0); ctx.lineTo(x0 + 330 * K, H * 0.8); ctx.lineTo(x0 + 170 * K, H * 0.8);
		ctx.fill();
	}
	ctx.restore();
}

function lerpColor(a, b, u) {
	const pa = parseInt(a.slice(1), 16), pb = parseInt(b.slice(1), 16);
	const r = Math.round(lerp(pa >> 16, pb >> 16, u)), g = Math.round(lerp((pa >> 8) & 255, (pb >> 8) & 255, u)), bl = Math.round(lerp(pa & 255, pb & 255, u));
	return `rgb(${r},${g},${bl})`;
}

function seaFloor(y, grey) {
	const yy = Y(y);
	ctx.fillStyle = vgrad(yy, H, [lerpColor('#ffe2a6', '#8d8577', grey), lerpColor('#e2a85e', '#5d574d', grey)]);
	ctx.strokeStyle = INK;
	ctx.lineWidth = 8 * K;
	ctx.beginPath();
	ctx.moveTo(-20, yy + 40 * K);
	for (let i = 0; i <= 12; i++) {
		const x = (i / 12) * (W + 40) - 20;
		ctx.lineTo(x, yy + Math.sin(i * 1.3) * 18 * K);
	}
	ctx.lineTo(W + 20, H + 20); ctx.lineTo(-20, H + 20); ctx.closePath();
	ctx.fill(); ctx.stroke();
	ctx.fillStyle = `rgba(120,80,40,${0.35})`;
	for (let i = 0; i < 40; i++) {
		ctx.beginPath();
		ctx.ellipse(rnd(i) * W, yy + (40 + rnd(i * 3) * 600) * K, (6 + rnd(i * 5) * 10) * K, (3 + rnd(i * 7) * 4) * K, 0, 0, Math.PI * 2);
		ctx.fill();
	}
}

function coral(x, y, s, col, tip) {
	ctx.save();
	ctx.translate(X(x), Y(y));
	ctx.scale(s * K, s * K);
	const br = [[0, 0, -5, -60, -10, -110, -40, -170], [-14, -80, -50, -100, -80, -120, -96, -160], [-4, -40, 30, -70, 52, -110, 58, -160], [40, -110, 70, -120, 90, -140, 100, -170]];
	ctx.lineCap = 'round';
	for (const pass of [[INK, 34], [col, 22]]) {
		ctx.strokeStyle = pass[0]; ctx.lineWidth = pass[1];
		for (const b of br) { ctx.beginPath(); ctx.moveTo(b[0], b[1]); ctx.bezierCurveTo(b[2], b[3], b[4], b[5], b[6], b[7]); ctx.stroke(); }
	}
	ctx.fillStyle = tip; ctx.strokeStyle = INK; ctx.lineWidth = 6;
	for (const p of [[-40, -170], [-96, -160], [58, -160], [100, -170]]) { ctx.beginPath(); ctx.arc(p[0], p[1], 17, 0, Math.PI * 2); ctx.fill(); ctx.stroke(); }
	ctx.restore();
}

function crystals(x, y, s, col) {
	ctx.save();
	ctx.translate(X(x), Y(y));
	ctx.scale(s * K, s * K);
	ctx.lineJoin = 'round';
	for (const c of [[-60, 150, 46, -0.25], [40, 120, 42, 0.28], [-8, 220, 58, 0.03]]) {
		ctx.save(); ctx.translate(c[0], 0); ctx.rotate(c[3]);
		const w = c[2], h = c[1];
		ctx.beginPath(); ctx.moveTo(-w / 2, 0); ctx.lineTo(-w / 2, -h + w * 0.6); ctx.lineTo(0, -h); ctx.lineTo(w / 2, -h + w * 0.6); ctx.lineTo(w / 2, 0); ctx.closePath();
		ctx.fillStyle = vgrad(-h, 0, ['#ffffff', col]); ctx.fill();
		ctx.strokeStyle = INK; ctx.lineWidth = 7; ctx.stroke();
		ctx.strokeStyle = 'rgba(255,255,255,0.65)'; ctx.lineWidth = 7; ctx.beginPath(); ctx.moveTo(-w / 4, -h + w * 0.8); ctx.lineTo(-w / 4, -14); ctx.stroke();
		ctx.restore();
	}
	ctx.restore();
}

// ---------------------------------------------------------------- worlds
const WORLDS = [
	{ name: 'OCEAN', sky: ['#2f93e6', '#a8e4ff'], sea: '#2bb8dc', land: '#ffd98e', top: '#6fcf5a', bg: ['#1a6fc4', '#0a2d66'] },
	{ name: 'VOLCANO', sky: ['#5a1a2a', '#ff8a3c'], sea: '#ff6a1a', land: '#4a3a40', top: '#2e2430', bg: ['#a8341a', '#2a0a10'] },
	{ name: 'ACID SWAMP', sky: ['#1f5a2a', '#b6f06a'], sea: '#7ad84a', land: '#5a6a3a', top: '#3e8a3a', bg: ['#2f8a3a', '#0a2a14'] },
	{ name: 'MOON', sky: ['#05051a', '#2a2a5a'], sea: '#5a5a7a', land: '#b8bccb', top: '#d8dce8', bg: ['#2a2a6a', '#05051a'] },
];

function worldCard(i, x, y, s, t, lockBreak) {
	const w = WORLDS[i];
	const cw = 720, ch = 940;
	ctx.save();
	ctx.translate(X(x), Y(y));
	ctx.scale(s * K, s * K);
	ctx.rotate((x / 3000));
	// shadow + frame
	ctx.fillStyle = 'rgba(0,0,0,0.35)'; rr(-cw / 2, -ch / 2 + 24, cw, ch, 60); ctx.fill();
	ctx.fillStyle = INK; rr(-cw / 2 - 10, -ch / 2 - 10, cw + 20, ch + 20, 66); ctx.fill();
	ctx.save();
	rr(-cw / 2, -ch / 2, cw, ch, 56); ctx.clip();
	let g = ctx.createLinearGradient(0, -ch / 2, 0, ch / 2);
	g.addColorStop(0, w.sky[0]); g.addColorStop(1, w.sky[1]);
	ctx.fillStyle = g; ctx.fillRect(-cw / 2, -ch / 2, cw, ch);
	ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.lineJoin = 'round';
	if (i === 3) {
		for (let k = 0; k < 40; k++) { ctx.fillStyle = `rgba(255,255,255,${0.4 + rnd(k) * 0.6})`; ctx.beginPath(); ctx.arc(-cw / 2 + rnd(k * 3) * cw, -ch / 2 + rnd(k * 7) * ch * 0.6, 2 + rnd(k) * 3, 0, 7); ctx.fill(); }
		ctx.fillStyle = '#3a8ae0'; ctx.beginPath(); ctx.arc(180, -280, 80, 0, 7); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#6fcf5a'; ctx.beginPath(); ctx.ellipse(160, -300, 34, 24, 0.4, 0, 7); ctx.fill();
	} else {
		ctx.fillStyle = i === 1 ? '#ffb24a' : '#ffe066'; ctx.beginPath(); ctx.arc(-200, -300, 70, 0, 7); ctx.fill(); ctx.stroke();
	}
	// sea / lava / goo
	ctx.fillStyle = w.sea; ctx.fillRect(-cw / 2, 120, cw, ch);
	ctx.strokeStyle = 'rgba(255,255,255,0.8)'; ctx.lineWidth = 7; ctx.beginPath();
	for (let xx = -cw / 2; xx <= cw / 2; xx += 20) ctx.lineTo(xx, 120 + Math.sin(xx * 0.04 + t * 4) * 6);
	ctx.stroke();
	ctx.strokeStyle = INK; ctx.lineWidth = 9;
	// land
	ctx.fillStyle = w.land; ctx.beginPath(); ctx.ellipse(0, 150, 300, 110, 0, Math.PI, 0); ctx.fill(); ctx.stroke();
	if (i === 0) {
		ctx.fillStyle = w.top; ctx.beginPath(); ctx.ellipse(0, 90, 220, 50, 0, Math.PI, 0); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#8a5a30'; rr(90, -200, 26, 210, 10); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#46b84a'; for (let k = 0; k < 5; k++) { ctx.save(); ctx.translate(103, -200); ctx.rotate(-1.2 + k * 0.6 + Math.sin(t * 2) * 0.05); ctx.beginPath(); ctx.ellipse(70, 0, 80, 22, 0, 0, 7); ctx.fill(); ctx.stroke(); ctx.restore(); }
		ctx.fillStyle = '#c98249'; rr(-170, -40, 150, 110, 12); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#e8b04a'; ctx.beginPath(); ctx.moveTo(-190, -40); ctx.lineTo(-95, -120); ctx.lineTo(0, -40); ctx.closePath(); ctx.fill(); ctx.stroke();
	} else if (i === 1) {
		ctx.fillStyle = '#5a3a3a'; ctx.beginPath(); ctx.moveTo(-260, 120); ctx.lineTo(-60, -200); ctx.lineTo(60, -200); ctx.lineTo(260, 120); ctx.closePath(); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#ff6a1a'; ctx.beginPath(); ctx.moveTo(-60, -200); ctx.lineTo(60, -200); ctx.lineTo(30, -120); ctx.lineTo(10, -40); ctx.lineTo(-10, -100); ctx.lineTo(-40, -150); ctx.closePath(); ctx.fill(); ctx.stroke();
		for (let k = 0; k < 6; k++) { const u = ((t * 0.8 + k / 6) % 1); ctx.fillStyle = `rgba(90,70,80,${0.8 * (1 - u)})`; ctx.beginPath(); ctx.arc(Math.sin(k) * 40 * u, -230 - u * 300, 40 + u * 60, 0, 7); ctx.fill(); }
		for (let k = 0; k < 8; k++) { const u = ((t * 1.3 + k / 8) % 1); ctx.fillStyle = '#ffd24a'; ctx.beginPath(); ctx.arc((rnd(k) - 0.5) * 300 * u, -220 - Math.sin(u * Math.PI) * 220, 12, 0, 7); ctx.fill(); }
	} else if (i === 2) {
		const mush = [[-150, 70, 1.2, '#ff6fae'], [40, 60, 1.6, '#c86bff'], [180, 90, 0.9, '#ffd23f']];
		for (const m of mush) {
			ctx.save(); ctx.translate(m[0], m[1]); ctx.scale(m[2], m[2]);
			ctx.fillStyle = '#f4eadc'; rr(-18, -110, 36, 110, 14); ctx.fill(); ctx.stroke();
			ctx.fillStyle = m[3]; ctx.beginPath(); ctx.ellipse(0, -110, 80, 56, 0, Math.PI, 0); ctx.closePath(); ctx.fill(); ctx.stroke();
			ctx.fillStyle = 'rgba(255,255,255,0.85)'; for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.arc(-40 + k * 38, -135 + (k % 2) * 12, 10, 0, 7); ctx.fill(); }
			ctx.restore();
		}
		for (let k = 0; k < 8; k++) { const u = ((t * 0.7 + k / 8) % 1); ctx.fillStyle = `rgba(200,255,120,${1 - u})`; ctx.beginPath(); ctx.arc(-250 + rnd(k) * 500, 150 - u * 300, 10 + rnd(k * 2) * 10, 0, 7); ctx.fill(); }
	} else {
		ctx.fillStyle = '#9aa0b4'; for (const c of [[-140, 100, 60], [120, 120, 44], [10, 70, 30]]) { ctx.beginPath(); ctx.ellipse(c[0], c[1], c[2], c[2] * 0.35, 0, 0, 7); ctx.fill(); ctx.stroke(); }
		ctx.fillStyle = '#e8ecf4'; rr(-60, -60, 120, 90, 50); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#9fe6ff'; ctx.beginPath(); ctx.arc(0, -15, 30, 0, 7); ctx.fill(); ctx.stroke();
		ctx.fillStyle = '#ff5a5a'; ctx.beginPath(); ctx.moveTo(-10, -60); ctx.lineTo(-10, -140); ctx.lineTo(50, -120); ctx.lineTo(-10, -100); ctx.fill(); ctx.stroke();
	}
	// a diver on every world
	ctx.restore();
	ctx.restore();
	spr(i === 3 ? 'diverStar' : 'diverHappy', x - 170 * s, y + 360 * s, 0.42 * s);
	// name banner
	ctx.save();
	text(w.name, x, y - 400 * s, 96 * s, { fill: 'gold' });
	ctx.restore();
	// the lock that breaks
	if (lockBreak < 1) {
		const u = lockBreak;
		ctx.save();
		ctx.globalAlpha = 1 - eIn(u);
		ctx.fillStyle = 'rgba(10,8,30,0.55)';
		ctx.translate(X(x), Y(y)); ctx.scale(s * K, s * K);
		rr(-360, -470, 720, 940, 56); ctx.fill();
		ctx.restore();
		const ly = y - 20 * s - eIn(u) * 260 * s;
		ctx.save();
		ctx.globalAlpha = 1 - eIn(u);
		ctx.translate(X(x), Y(ly));
		ctx.scale(s * K * (1 + u * 0.4), s * K * (1 + u * 0.4));
		ctx.rotate(u * 0.6);
		ctx.lineJoin = 'round';
		// shackle (lifts open)
		ctx.save(); ctx.translate(-50, -eOut(u) * 50);
		ctx.lineCap = 'round';
		ctx.strokeStyle = INK; ctx.lineWidth = 46; ctx.beginPath(); ctx.arc(50, -40, 70, Math.PI, 0); ctx.lineTo(120, 10); ctx.stroke();
		ctx.strokeStyle = '#c9ced8'; ctx.lineWidth = 26; ctx.beginPath(); ctx.arc(50, -40, 70, Math.PI, 0); ctx.lineTo(120, 10); ctx.stroke();
		ctx.restore();
		ctx.fillStyle = INK; rr(-130, -50, 260, 210, 40); ctx.fill();
		ctx.fillStyle = vgrad(-40, 150, ['#ffe680', '#f2a91c']); rr(-120, -40, 240, 190, 34); ctx.fill();
		ctx.fillStyle = INK; ctx.beginPath(); ctx.arc(0, 40, 26, 0, 7); ctx.fill(); rr(-12, 40, 24, 60, 8); ctx.fill();
		ctx.fillStyle = 'rgba(255,255,255,0.5)'; rr(-100, -26, 200, 34, 17); ctx.fill();
		ctx.restore();
		for (let k = 0; k < 10; k++) sparkle(x + Math.cos(k) * 260 * s * eOut(u), y - 40 * s + Math.sin(k * 2.3) * 220 * s * eOut(u), 26 * s * Math.sin(u * Math.PI), 1);
	}
}
