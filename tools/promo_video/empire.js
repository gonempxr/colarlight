// The working empire in world units (drawn inside a camera transform):
// a mine with 4 floors, the elevator and its headframe, a conveyor to the
// pier, a cargo boat, a crane and a cutaway gold factory on an island.
// Everything moves from t alone, so any frame can be drawn on its own.
'use strict';

const FH = 360, MINE_TOP = 80, NFL = 4;
const SH_X = -600, SH_W = 130;
const CAVE_L = -520, CAVE_R = 220;
const SHORE = 360, SEA_Y = 50, DOCK1 = 560, DOCK2 = 1220, COAST = 1540;
const FAC_L = 1820, FAC_R = 2560, FAC_TOP = -540;
const CAB_TOP = -300, PULLEY_Y = -500;
const MFL = [
	{ rock: '#dba06a', rock2: '#b97b4b', w0: '#5cc8e6', w1: '#1f86b8', ore: ['#ff7fa6', '#ffd6e3'] },
	{ rock: '#c9765a', rock2: '#995240', w0: '#4fb4e0', w1: '#1a6aa6', ore: ['#ff4d6d', '#ffc4cd'] },
	{ rock: '#8f7dbb', rock2: '#625191', w0: '#4f8fd8', w1: '#173f86', ore: ['#7fdcff', '#eafcff'] },
	{ rock: '#4c7d77', rock2: '#2f5550', w0: '#3d78c4', w1: '#0f2b66', ore: ['#2ee08a', '#cdffe4'] },
];
const floorTop = (i) => MINE_TOP + i * FH;
const floorY = (i) => MINE_TOP + i * FH + FH - 64;

// ------------------------------------------------------------ small kit
function P(...p) { ctx.beginPath(); ctx.moveTo(p[0], p[1]); for (let i = 2; i < p.length; i += 2) ctx.lineTo(p[i], p[i + 1]); ctx.closePath(); }
function fs(fill, lw = 7) {
	ctx.fillStyle = fill; ctx.fill();
	if (lw) { ctx.strokeStyle = INK; ctx.lineWidth = lw; ctx.lineJoin = 'round'; ctx.stroke(); }
}
function lg(x0, y0, x1, y1, stops) { const g = ctx.createLinearGradient(x0, y0, x1, y1); stops.forEach((c, i) => g.addColorStop(i / (stops.length - 1), c)); return g; }
function circ(x, y, r) { ctx.beginPath(); ctx.arc(x, y, Math.max(0.1, r), 0, Math.PI * 2); }
function line(x0, y0, x1, y1, col, lw) { ctx.strokeStyle = col; ctx.lineWidth = lw; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke(); }
function rrf(x, y, w, h, r, fill, lw = 7) { rr(x, y, w, h, r); fs(fill, lw); }
function wglow(x, y, r, rgb, a) {
	const g = ctx.createRadialGradient(x, y, 0, x, y, r);
	g.addColorStop(0, `rgba(${rgb},${a})`); g.addColorStop(1, `rgba(${rgb},0)`);
	ctx.fillStyle = g; ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
}
function wspr(name, x, y, s, rot = 0, flip = 1, alpha = 1) {
	const im = SPR[name]; if (!im) return;
	const a = ANCH[name], r = im.ratio;
	ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s * flip / r, s / r);
	ctx.drawImage(im, -a[0] * r, -a[1] * r); ctx.restore();
}
// Game-style text in the current transform (world units).
function wtext(s, x, y, size, fill = '#ffd23a', alpha = 1, sc = 1) {
	if (alpha <= 0) return;
	ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(x, y); ctx.scale(sc, sc);
	ctx.font = `${size}px Nunito`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
	ctx.lineWidth = size * 0.24; ctx.strokeStyle = INK; ctx.strokeText(s, 0, 0);
	ctx.fillStyle = fill === 'gold' || fill === '#ffd23a' ? lg(0, -size * 0.45, 0, size * 0.45, ['#fff7b0', '#ffd23a', '#f39a12']) : fill;
	ctx.fillText(s, 0, 0); ctx.restore();
}
function wpop(t, t0, x, y, s, size = 46, life = 1.0) {
	const u = (t - t0) / life; if (u < 0 || u > 1) return;
	wtext(s, x, y - eOut(u) * 90, size, 'gold', u < 0.7 ? 1 : (1 - u) / 0.3, eBack(sat(u * 3)));
}
// A faceted ore gem.
function gem(x, y, r, c0, c1, rot = 0) {
	ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
	P(-r, -r * 0.25, -r * 0.5, -r, r * 0.5, -r, r, -r * 0.25, 0, r);
	fs(lg(0, -r, 0, r, [c1, c0, c0]), Math.max(2.5, r * 0.17));
	ctx.fillStyle = 'rgba(255,255,255,0.6)'; P(-r * 0.5, -r, -r * 0.05, -r * 0.25, -r, -r * 0.25); ctx.fill();
	ctx.fillStyle = 'rgba(0,0,0,0.14)'; P(r, -r * 0.25, 0, r, r * 0.15, -r * 0.25); ctx.fill();
	ctx.restore();
}
// A heap of gems (fill 0..1) on a flat base at y, width w.
function heap(x, y, w, fill, cols, seed) {
	if (fill <= 0.02) return;
	const n = Math.round(4 + fill * 10);
	for (let k = 0; k < n; k++) {
		const u = rnd(seed + k), row = Math.floor(k / 5);
		const px = x + (u - 0.5) * w * (1 - row * 0.28);
		const py = y - 10 - row * 15 * fill - rnd(seed + k * 3) * 6;
		gem(px, py, 11 + rnd(seed + k * 7) * 5, cols[0], cols[1], (u - 0.5) * 1.2);
	}
}
// Rock chips flying out of a hit (stateless).
function chips(t, t0, x, y, n, seed, cols, dir = -1, pw = 1) {
	const dt = t - t0; if (dt < 0 || dt > 0.75) return;
	const g = ctx.createRadialGradient(x, y, 0, x, y, 30 + dt * 120);
	g.addColorStop(0, `rgba(255,250,235,${0.55 * (1 - dt / 0.75)})`); g.addColorStop(1, 'rgba(255,250,235,0)');
	ctx.fillStyle = g; ctx.fillRect(x - 160, y - 160, 320, 320);
	for (let i = 0; i < n; i++) {
		const a = -Math.PI / 2 + dir * (0.25 + rnd(seed + i) * 1.1);
		const v = (240 + rnd(seed + i * 3) * 380) * pw;
		const px = x + Math.cos(a) * v * dt, py = y + Math.sin(a) * v * dt + 1100 * dt * dt;
		const r = (5 + rnd(seed + i * 7) * 7) * pw;
		ctx.save(); ctx.globalAlpha *= sat((0.75 - dt) * 5); ctx.translate(px, py); ctx.rotate(dt * 12 + i);
		P(-r, -r * 0.6, r * 0.7, -r, r, r * 0.5, -r * 0.4, r); fs(cols[i % cols.length], 2.5); ctx.restore();
	}
	// impact star
	if (dt < 0.12) { ctx.save(); ctx.globalAlpha *= 1 - dt / 0.12; ctx.translate(x, y); ctx.rotate(seed); ctx.fillStyle = '#fffbe6'; const R = 34 * pw * (0.6 + dt * 4), q = R * 0.18; ctx.beginPath(); ctx.moveTo(0, -R); ctx.quadraticCurveTo(q, -q, R, 0); ctx.quadraticCurveTo(q, q, 0, R); ctx.quadraticCurveTo(-q, q, -R, 0); ctx.quadraticCurveTo(-q, -q, 0, -R); ctx.fill(); ctx.restore(); }
}
// A gem hopping along an arc from (x0,y0) to (x1,y1).
function hop(t, t0, dur, x0, y0, x1, y1, h, cols, seed, r = 13) {
	const u = (t - t0) / dur; if (u < 0 || u > 1) return;
	gem(lerp(x0, x1, u), lerp(y0, y1, u) - Math.sin(u * Math.PI) * h, r, cols[0], cols[1], u * 6 + seed);
}

// ------------------------------------------------------------ the swing rig
const SHOULDER = [100, -390], REACH = 540;
const REST = 0.95, UP = -1.75, HIT = 0.5;
function drift(t, prev) { return prev === null ? REST : lerp(HIT, REST, eOut(span(t - prev, 0.14, 0.7))); }
// Arm angle from the previous and next hit times.
function swingAt(t, prev, next) {
	if (next !== null && next - t < 0.08) return lerp(UP, HIT, eIn(1 - (next - t) / 0.08));
	if (prev !== null && t - prev < 0.14) return HIT - Math.sin((t - prev) / 0.14 * Math.PI) * 0.2;
	if (next !== null) {
		const from = prev === null ? next - 0.6 : prev + 0.14;
		const w = Math.min(0.42, next - 0.08 - from);
		const ts = next - 0.08 - w;
		if (t >= ts) return lerp(drift(ts, prev), UP, eOut(sat((t - ts) / w)));
	}
	return drift(t, prev);
}
function hitsPeriodic(t, P, off) { const k = Math.floor((t - off) / P); return [off + k * P, off + (k + 1) * P]; }
function rig(body, arm, x, y, s, ang, flip = 1, tilt = 0, sq = 0) {
	ctx.save(); ctx.translate(x, y); ctx.rotate(tilt); ctx.scale(flip * (1 + sq * 0.06), 1 - sq * 0.08);
	wspr(body, 0, 0, s);
	if (arm) { ctx.translate(SHOULDER[0] * s, SHOULDER[1] * s); ctx.rotate(ang); wspr(arm, 0, 0, s); }
	ctx.restore();
}
function hitPoint(x, y, s, flip = 1) {
	const sx = x + SHOULDER[0] * s * flip, sy = y + SHOULDER[1] * s;
	return [sx + Math.cos(HIT) * REACH * s * flip, sy + Math.sin(HIT) * REACH * s];
}

// ------------------------------------------------------------ elevator state
const CAB_KEYS = () => [[7.4, CAB_TOP], [8.7, floorY(1)], [9.5, floorY(1)], [9.95, floorY(0)], [10.65, floorY(0)], [11.65, CAB_TOP], [12.4, CAB_TOP]];
function cabinState(t) {
	const K_ = CAB_KEYS();
	if (t >= K_[0][0] && t < K_[K_.length - 1][0]) {
		let i = 0; while (t >= K_[i + 1][0]) i++;
		const [ta, ya] = K_[i], [tb, yb] = K_[i + 1];
		const y = lerp(ya, yb, eIO((t - ta) / (tb - ta)));
		let load = 0;
		if (t > 8.75) load = 0.5 * span(t, 8.75, 9.4);
		if (t > 10.0) load = 0.5 + 0.5 * span(t, 10.0, 10.55);
		const tip = Math.sin(span(t, 11.7, 12.25) * Math.PI) * 0.7;
		if (t > 11.75) load = 1 - span(t, 11.75, 12.1);
		return { y, load, tip, moving: Math.abs(ya - yb) > 1 && t > ta + 0.05 && t < tb - 0.05 };
	}
	// generic loop: down to a floor, load, up, dump
	const P = 3.6, k = Math.floor((t - 12.4) / P), ph = ((t - 12.4) / P) - k;
	const fl = ((k % NFL) + NFL) % NFL, fy = floorY(fl);
	let y = CAB_TOP, load = 0, tip = 0, moving = false;
	if (ph < 0.3) { y = lerp(CAB_TOP, fy, eIO(ph / 0.3)); moving = true; }
	else if (ph < 0.5) { y = fy; load = span(ph, 0.32, 0.48); }
	else if (ph < 0.82) { y = lerp(fy, CAB_TOP, eIO((ph - 0.5) / 0.32)); load = 1; moving = true; }
	else { tip = Math.sin(span(ph, 0.83, 0.98) * Math.PI) * 0.7; load = 1 - span(ph, 0.85, 0.95); }
	return { y, load, tip, moving };
}

// ------------------------------------------------------------ boat state
function boatState(t) {
	if (t >= 12.0 && t < 16.6) {
		if (t < 13.0) return { x: DOCK1, load: lerp(0.15, 1, span(t, 12.0, 12.95)), v: 0 };
		if (t < 15.0) { const u = (t - 13.0) / 2.0; return { x: lerp(DOCK1, DOCK2, eIO(u)), load: 1, v: (DOCK2 - DOCK1) / 2.0 * 6 * u * (1 - u) * 1.0 }; }
		return { x: DOCK2, load: 1 - span(t, 15.4, 16.6), v: 0 };
	}
	const P = 6.0, ph = (((t - 16.6) / P) % 1 + 1) % 1;
	if (ph < 0.15) return { x: DOCK2, load: 1 - ph / 0.15, v: 0 };
	if (ph < 0.48) { const u = (ph - 0.15) / 0.33; return { x: lerp(DOCK2, DOCK1, eIO(u)), load: 0, v: -(DOCK2 - DOCK1) / (0.33 * P) * 6 * u * (1 - u) }; }
	if (ph < 0.64) return { x: DOCK1, load: (ph - 0.48) / 0.16, v: 0 };
	const u = (ph - 0.64) / 0.36;
	return { x: lerp(DOCK1, DOCK2, eIO(u)), load: 1, v: (DOCK2 - DOCK1) / (0.36 * P) * 6 * u * (1 - u) };
}

// ------------------------------------------------------------ backdrop
function sky(t) {
	ctx.fillStyle = lg(0, -1900, 0, SEA_Y, ['#1f7ad6', '#4aa8ee', '#9fdcff', '#d8f3ff']);
	ctx.fillRect(-3000, -3000, 7000, 3000 + SEA_Y);
	// sun
	wglow(-250, -760, 260, '255,240,170', 0.6);
	circ(-250, -760, 80); fs(lg(0, -840, 0, -680, ['#fff4a8', '#ffd23a']), 8);
	// clouds drifting
	for (let i = 0; i < 9; i++) {
		const x = -1500 + ((rnd(i) * 4600 + t * (12 + rnd(i * 3) * 18)) % 4600);
		const y = -1150 + rnd(i * 5) * 600, s = 0.7 + rnd(i * 7) * 0.8;
		ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
		ctx.fillStyle = 'rgba(255,255,255,0.95)'; ctx.strokeStyle = 'rgba(36,26,58,0.25)'; ctx.lineWidth = 6;
		ctx.beginPath(); ctx.arc(-60, 0, 46, Math.PI * 0.5, Math.PI * 1.5); ctx.arc(-10, -30, 56, Math.PI, Math.PI * 1.9); ctx.arc(60, -6, 44, Math.PI * 1.3, Math.PI * 0.5); ctx.closePath();
		ctx.fill(); ctx.stroke(); ctx.restore();
	}
	// gulls
	for (let i = 0; i < 4; i++) {
		const x = -900 + ((rnd(i * 11) * 3800 + t * 90) % 3800), y = -620 - rnd(i * 13) * 300 + Math.sin(t * 2 + i) * 18;
		const f = Math.sin(t * 9 + i * 2) * 10;
		ctx.strokeStyle = INK; ctx.lineWidth = 5; ctx.lineCap = 'round';
		ctx.beginPath(); ctx.moveTo(x - 24, y - f); ctx.quadraticCurveTo(x - 10, y - 14, x, y); ctx.quadraticCurveTo(x + 10, y - 14, x + 24, y - f); ctx.stroke();
	}
	// far hills
	ctx.fillStyle = '#9dd3e8';
	ctx.beginPath(); ctx.moveTo(-3000, 10);
	for (let x = -3000; x <= 4000; x += 100) ctx.lineTo(x, -40 - Math.abs(Math.sin(x * 0.0021)) * 210 - Math.sin(x * 0.006) * 30);
	ctx.lineTo(4000, 10); ctx.closePath(); ctx.fill();
	ctx.fillStyle = '#b9e2f0';
	ctx.beginPath(); ctx.moveTo(-3000, 10);
	for (let x = -3000; x <= 4000; x += 80) ctx.lineTo(x, -10 - Math.abs(Math.sin(x * 0.0035 + 1)) * 110);
	ctx.lineTo(4000, 10); ctx.closePath(); ctx.fill();
}

function rockAndGround() {
	// strata under everything
	for (let i = 0; i < NFL; i++) {
		const f = MFL[i], y0 = floorTop(i);
		ctx.fillStyle = lg(0, y0, 0, y0 + FH, [f.rock, f.rock2]);
		ctx.fillRect(-3000, y0, 7000, FH + 2);
		ctx.fillStyle = 'rgba(40,20,30,0.13)';
		for (let k = 0; k < 70; k++) {
			const x = -1600 + rnd(i * 97 + k) * 4600, y = y0 + 20 + rnd(i * 13 + k * 7) * (FH - 40);
			const r = 5 + rnd(k * 3 + i) * 12;
			ctx.beginPath(); ctx.ellipse(x, y, r * 1.5, r, rnd(k) * 3, 0, 7); ctx.fill();
		}
		ctx.fillStyle = 'rgba(255,255,255,0.14)';
		for (let k = 0; k < 40; k++) { circ(-1600 + rnd(i * 41 + k * 5) * 4600, y0 + rnd(i * 5 + k * 11) * FH, 3 + rnd(k) * 4); ctx.fill(); }
		// wavy strata line
		ctx.strokeStyle = 'rgba(36,26,58,0.55)'; ctx.lineWidth = 7; ctx.beginPath();
		for (let x = -3000; x <= 4000; x += 60) ctx.lineTo(x, y0 + Math.sin(x * 0.013 + i) * 7);
		ctx.stroke();
	}
	ctx.fillStyle = lg(0, floorTop(NFL), 0, floorTop(NFL) + 1400, ['#3b2d55', '#1c1530']); ctx.fillRect(-3000, floorTop(NFL), 7000, 3000);
	ctx.fillStyle = 'rgba(255,255,255,0.07)';
	for (let k = 0; k < 90; k++) { circ(-1600 + rnd(k * 19) * 4600, floorTop(NFL) + 30 + rnd(k * 23) * 1200, 4 + rnd(k) * 10); ctx.fill(); }
	// topsoil + grass on the mainland and the island
	for (const [a, b] of [[-3000, SHORE], [COAST, 4000]]) {
		ctx.fillStyle = lg(0, -10, 0, MINE_TOP, ['#b07a4a', '#8c5a34']); ctx.fillRect(a, -6, b - a, MINE_TOP + 8);
		ctx.beginPath(); ctx.moveTo(a, 14);
		for (let x = a; x <= b; x += 30) ctx.lineTo(x, -8 + Math.sin(x * 0.05) * 4);
		ctx.lineTo(b, 14); ctx.closePath(); fs(lg(0, -14, 0, 14, ['#8fe36a', '#4fb84a']), 7);
	}
}

function sea(t) {
	// basin between the mainland and the island
	ctx.save();
	ctx.beginPath(); ctx.moveTo(SHORE - 60, SEA_Y - 20); ctx.lineTo(SHORE + 280, 470); ctx.lineTo(COAST - 260, 470); ctx.lineTo(COAST + 20, SEA_Y - 20); ctx.closePath();
	ctx.fillStyle = '#f2cf8e'; ctx.fill();
	ctx.restore();
	ctx.fillStyle = lg(0, SEA_Y, 0, 470, ['#46c6e8', '#1d8fc8', '#11589a']);
	ctx.beginPath(); ctx.moveTo(SHORE - 40, SEA_Y);
	for (let x = SHORE - 40; x <= COAST; x += 20) ctx.lineTo(x, SEA_Y + Math.sin(x * 0.03 + t * 3) * 5);
	ctx.lineTo(COAST - 250, 450); ctx.lineTo(SHORE + 270, 450); ctx.closePath(); ctx.fill();
	// seabed sand + weeds
	ctx.fillStyle = '#e8c27e'; ctx.beginPath(); ctx.moveTo(SHORE + 230, 452); ctx.quadraticCurveTo(900, 400, COAST - 220, 452); ctx.lineTo(COAST - 220, 470); ctx.lineTo(SHORE + 230, 470); ctx.fill();
	for (let k = 0; k < 9; k++) {
		const x = SHORE + 330 + k * 85, h = 50 + rnd(k) * 70, sw = Math.sin(t * 2 + k) * 14;
		ctx.strokeStyle = INK; ctx.lineWidth = 16; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x, 450); ctx.quadraticCurveTo(x + sw, 450 - h * 0.6, x + sw * 1.6, 450 - h); ctx.stroke();
		ctx.strokeStyle = k % 2 ? '#3fbf6a' : '#ff7f8f'; ctx.lineWidth = 9; ctx.stroke();
	}
	// fish
	for (let k = 0; k < 5; k++) {
		const span_ = COAST - SHORE - 300, u = ((t * (40 + k * 9) / span_) + rnd(k)) % 1;
		const dir = k % 2 ? 1 : -1, x = dir > 0 ? SHORE + 150 + u * span_ : COAST - 150 - u * span_, y = 160 + rnd(k * 5) * 220 + Math.sin(t * 3 + k) * 10;
		ctx.save(); ctx.translate(x, y); ctx.scale(dir, 1);
		const tail = Math.sin(t * 14 + k) * 6;
		P(-20, 0, -38, -14 + tail, -38, 14 + tail); fs(['#ffb13b', '#ff6f91', '#7fe0ff'][k % 3], 4);
		ctx.beginPath(); ctx.ellipse(0, 0, 26, 15, 0, 0, 7); fs(['#ffd23a', '#ff8fb0', '#a8ecff'][k % 3], 4);
		circ(12, -3, 4); ctx.fillStyle = INK; ctx.fill();
		ctx.restore();
	}
	// light shimmer on the surface
	ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 6; ctx.beginPath();
	for (let x = SHORE - 40; x <= COAST; x += 20) ctx.lineTo(x, SEA_Y + Math.sin(x * 0.03 + t * 3) * 5);
	ctx.stroke();
}
function seaFront(t) {
	ctx.fillStyle = 'rgba(70,200,235,0.45)';
	ctx.beginPath(); ctx.moveTo(SHORE - 40, SEA_Y + 70);
	for (let x = SHORE - 40; x <= COAST; x += 20) ctx.lineTo(x, SEA_Y + 6 + Math.sin(x * 0.03 + t * 3) * 5);
	ctx.lineTo(COAST, SEA_Y + 70); ctx.closePath(); ctx.fill();
}

// ------------------------------------------------------------ mine floors
function mineFloor(i, t) {
	const f = MFL[i], y0 = floorTop(i), fy = floorY(i);
	const cl = CAVE_L, cr = CAVE_R, ct = y0 + 34, cb = y0 + FH - 30;
	// cave hollow with a bumpy ceiling
	ctx.beginPath(); ctx.moveTo(cl, cb);
	ctx.lineTo(cl, ct + 24);
	for (let k = 1; k < 18; k++) ctx.lineTo(lerp(cl, cr, k / 18), ct + rnd(i * 31 + k) * 26);
	ctx.lineTo(cr, ct + 30); ctx.lineTo(cr + 26, lerp(ct, cb, 0.45)); ctx.lineTo(cr, cb); ctx.closePath();
	fs(lg(0, ct, 0, cb, [f.w0, f.w1]), 10);
	ctx.save(); ctx.clip();
	// far rocks
	ctx.fillStyle = 'rgba(10,20,60,0.22)';
	ctx.beginPath(); ctx.moveTo(cl, cb);
	for (let k = 0; k <= 12; k++) ctx.lineTo(lerp(cl, cr, k / 12), fy - 60 - rnd(i * 7 + k) * 90);
	ctx.lineTo(cr, cb); ctx.closePath(); ctx.fill();
	// light beams from the lamps
	for (let k = 0; k < 3; k++) {
		const lx = cl + 150 + k * 260;
		ctx.fillStyle = lg(0, ct, 0, cb, ['rgba(255,240,180,0.28)', 'rgba(255,240,180,0)']);
		P(lx - 14, ct + 30, lx + 14, ct + 30, lx + 90, cb, lx - 90, cb); ctx.fill();
	}
	// bubbles
	for (let k = 0; k < 6; k++) {
		const u = ((t * 0.35 + rnd(i * 9 + k)) % 1);
		const bx = cl + 40 + rnd(i * 3 + k * 5) * (cr - cl - 80), by = cb - u * (cb - ct);
		ctx.strokeStyle = 'rgba(255,255,255,0.75)'; ctx.lineWidth = 3; circ(bx + Math.sin(t * 3 + k) * 6, by, 5 + rnd(k) * 6); ctx.stroke();
	}
	// stalactites
	for (let k = 0; k < 7; k++) {
		const x = cl + 60 + k * 115 + rnd(k + i) * 30, h = 26 + rnd(i * 5 + k) * 34;
		P(x - 16, ct, x + 16, ct, x + 2, ct + h); fs(f.rock2, 5);
	}
	// sand floor + rails
	ctx.fillStyle = lg(0, fy, 0, cb, ['#f7d9a0', '#d9a964']); ctx.fillRect(cl, fy, cr - cl + 40, cb - fy);
	line(cl, fy, cr + 30, fy, INK, 6);
	for (let x = cl + 20; x < cr - 40; x += 46) { ctx.fillStyle = '#7a4a26'; ctx.fillRect(x, fy + 4, 26, 10); }
	line(cl, fy + 4, cr - 30, fy + 4, '#8d94a6', 5);
	ctx.restore();
	// wooden props
	for (const px of [-300, -20]) {
		rrf(px - 11, ct + 4, 22, fy - ct - 4, 4, '#a8693a', 5);
		rrf(px - 46, ct + 2, 92, 20, 5, '#c98249', 5);
		// hanging lamp
		line(px + 40, ct + 22, px + 40, ct + 52, INK, 3);
		const fl = 0.85 + Math.sin(t * 13 + px + i) * 0.08 + Math.sin(t * 7.3 + i) * 0.07;
		wglow(px + 40, ct + 64, 70, '255,220,120', 0.55 * fl);
		circ(px + 40, ct + 64, 12); fs('#ffe9a0', 4);
	}
	// glowing ore vein in the right wall
	const vx = cr - 30, vy = (ct + fy) / 2 + 10;
	const pulse = 0.5 + Math.sin(t * 3 + i) * 0.15;
	wglow(vx, vy, 150, hexRgb(f.ore[0]), pulse * 0.7);
	ctx.beginPath(); ctx.ellipse(vx + 20, vy + 10, 70, 105, 0, 0, 7); fs(f.rock2, 8);
	for (let k = 0; k < 7; k++) gem(vx + (rnd(i * 17 + k) - 0.5) * 80, vy - 70 + k * 22 + (rnd(k) - 0.5) * 10, 15 + rnd(k * 3 + i) * 9, f.ore[0], f.ore[1], rnd(k) * 2);
	// seaweed by the door
	for (let k = 0; k < 3; k++) {
		const x = cl + 70 + k * 18, sw = Math.sin(t * 2.4 + k + i) * 10;
		ctx.strokeStyle = INK; ctx.lineWidth = 14; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(x, fy); ctx.quadraticCurveTo(x + sw, fy - 40, x + sw * 1.5, fy - 80 - k * 10); ctx.stroke();
		ctx.strokeStyle = '#46c46a'; ctx.lineWidth = 8; ctx.stroke();
	}
	// door frame to the shaft
	rrf(cl - 8, fy - 150, 26, 150, 4, '#a8693a', 5);
	rrf(cl - 30, fy - 162, 70, 22, 5, '#c98249', 5);
}
function hexRgb(h) { const p = parseInt(h.slice(1), 16); return `${p >> 16},${(p >> 8) & 255},${p & 255}`; }

// Workers, the cart and the ore crate of one floor (drawn after the shaft).
function floorLife(i, t) {
	const f = MFL[i], fy = floorY(i), s = 0.235;
	// miner at the vein
	const mx = CAVE_R - 205;
	const P_ = 0.95 + i * 0.07, off = i * 0.23;
	const [prev, next] = hitsPeriodic(t, P_, off);
	const ang = swingAt(t, prev, next);
	const [hx, hy] = hitPoint(mx, fy, s);
	const shake = Math.max(0, 1 - (t - prev) * 10);
	rig(i === 3 ? 'rigStar' : 'rigHappy', 'armO', mx, fy, s, ang, 1, 0, shake * 0.6);
	chips(t, prev, hx + 10, hy, 9, Math.floor(prev * 10), [f.ore[0], f.rock2, f.ore[1]], -1, 0.8);
	wpop(t, prev + 0.05, hx - 30, hy - 120, '+' + fmt(Math.pow(14, i + 1) * (2 + (Math.floor(prev / P_) % 3))), 40, 0.9);
	// the cart
	const CP = 4.4 + i * 0.35, coff = i * 0.9;
	const ph = ((((t - coff) / CP) % 1) + 1) % 1;
	const xl = CAVE_R - 420, xs = CAVE_L + 85;
	let cx = xl, load = 0, tilt = 0, moving = false;
	if (ph < 0.18) { cx = xl; load = ph / 0.18; }
	else if (ph < 0.5) { cx = lerp(xl, xs, eIO((ph - 0.18) / 0.32)); load = 1; moving = true; }
	else if (ph < 0.64) { cx = xs; tilt = -Math.sin(((ph - 0.5) / 0.14) * Math.PI) * 0.55; load = 1 - span(ph, 0.53, 0.6); }
	else { cx = lerp(xs, xl, eIO((ph - 0.64) / 0.36)); moving = true; }
	// ore hopping from the miner into the parked cart
	if (ph < 0.18) for (let k = 0; k < 3; k++) hop(t, t - ((t - coff - k * 0.25) % 0.75) , 0.5, hx - 40, hy - 10, cx + 10, fy - 70, 70, f.ore, k + i);
	// pusher behind the cart (on its right, facing left)
	const walk = moving ? Math.abs(Math.sin(t * 11 + i)) * 7 : 0;
	rig('rigHappy', 'armE', cx + 112, fy - walk, s * 0.92, 0.25 + (moving ? Math.sin(t * 11) * 0.06 : 0.5), -1, moving ? Math.sin(t * 11) * 0.05 : 0);
	ctx.save(); ctx.translate(cx, fy - 22); ctx.rotate(tilt);
	heap(0, -40, 90, load, f.ore, i * 11);
	P(-62, -62, 62, -62, 50, 0, -50, 0); fs(lg(0, -62, 0, 0, ['#b9c1cf', '#6f7787']), 6);
	line(-54, -40, 54, -40, 'rgba(36,26,58,0.45)', 4);
	for (const wx of [-32, 32]) { circ(wx, 6, 15); fs('#4a5266', 5); line(wx, 6, wx + Math.cos(-t * 9) * 12, 6 + Math.sin(-t * 9) * 12, '#c9ced8', 3); }
	ctx.restore();
	// ore pile at the shaft door
	const lastDump = t - ((ph - 0.53) * CP);
	const bump = ph > 0.53 && ph < 0.7 ? Math.sin(span(ph, 0.53, 0.7) * Math.PI) * 0.15 : 0;
	heap(CAVE_L + 20, fy - 2, 70, 0.6 + bump, f.ore, i * 7 + 3);
	if (ph > 0.53 && ph < 0.75) wpop(t, lastDump, xs + 10, fy - 140, '+' + fmt(Math.pow(14, i + 2)), 44, 1.0);
}

// ------------------------------------------------------------ shaft, cabin, headframe
function shaft(t, cab) {
	const x0 = SH_X - SH_W / 2, x1 = SH_X + SH_W / 2, top = -10, bot = floorTop(NFL) - 30;
	ctx.fillStyle = lg(x0, 0, x1, 0, ['#14283f', '#26496c', '#14283f']); ctx.fillRect(x0, top, SH_W, bot - top);
	ctx.strokeStyle = 'rgba(150,185,220,0.28)'; ctx.lineWidth = 6;
	for (let y = top; y < bot; y += 110) { ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y + 110); ctx.moveTo(x1, y); ctx.lineTo(x0, y + 110); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke(); }
	line(x0 + 14, top, x0 + 14, bot, '#8d97ab', 8); line(x1 - 14, top, x1 - 14, bot, '#8d97ab', 8);
	ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.strokeRect(x0, top, SH_W, bot - top);
	// floor number badges
	for (let i = 0; i < NFL; i++) {
		const y = floorY(i) - 150;
		circ(x0 - 34, y, 26); fs('#ffd23a', 6);
		ctx.fillStyle = INK; ctx.font = '34px Nunito'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(String(i + 1), x0 - 34, y + 2);
	}
	// counterweight goes opposite to the cabin
	const cw = lerp(floorY(NFL - 1) - 60, CAB_TOP + 40, span(cab.y, CAB_TOP, floorY(NFL - 1)));
	line(x0 + 30, PULLEY_Y, x0 + 30, cw - 40, '#2a2f3a', 4);
	rrf(x0 + 18, cw - 40, 24, 80, 4, '#6f7787', 4);
}
function cabin(t, st) {
	const x = SH_X, y = st.y, w = 112, h = 128;
	line(x, PULLEY_Y + 40, x, y - h - 18, '#20242e', 6);
	ctx.save(); ctx.translate(x, y);
	if (st.tip) { ctx.translate(w / 2, 0); ctx.rotate(st.tip); ctx.translate(-w / 2, 0); }
	rrf(-w / 2, -h, w, h, 12, lg(-w / 2, 0, w / 2, 0, ['#d6dce6', '#9aa3b4', '#6f7787']), 7);
	rrf(-w / 2 + 12, -h + 28, w - 24, h - 40, 6, '#1a2a44', 4);
	ctx.save(); rr(-w / 2 + 12, -h + 28, w - 24, h - 40, 6); ctx.clip();
	heap(0, -14, w - 34, st.load, MFL[Math.min(3, Math.max(0, Math.round((y - MINE_TOP) / FH - 0.5)))].ore, 77);
	ctx.restore();
	for (let k = -2; k <= 2; k++) line(k * 18, -h + 30, k * 18, -14, 'rgba(200,210,230,0.5)', 3);
	// hazard roof
	ctx.save(); rr(-w / 2 - 6, -h - 16, w + 12, 26, 7); ctx.clip();
	ctx.fillStyle = '#ffcc33'; ctx.fillRect(-w, -h - 20, 2 * w, 40);
	ctx.fillStyle = INK; for (let k = -6; k < 6; k++) { P(k * 24, -h - 16, k * 24 + 12, -h - 16, k * 24 - 2, -h + 10, k * 24 - 14, -h + 10); ctx.fill(); }
	ctx.restore();
	rr(-w / 2 - 6, -h - 16, w + 12, 26, 7); ctx.strokeStyle = INK; ctx.lineWidth = 6; ctx.stroke();
	// lamp
	const on = st.moving ? (Math.sin(t * 16) > 0 ? 1 : 0.3) : 0.4;
	wglow(30, -h - 26, 40, '255,90,60', 0.6 * on);
	circ(30, -h - 24, 9); fs(on > 0.5 ? '#ff6a4a' : '#a8443a', 4);
	ctx.restore();
}
function headframe(t, cab) {
	const x = SH_X;
	// winch house
	const hx = x - 300;
	rrf(hx - 110, -170, 220, 170, 10, lg(0, -170, 0, 0, ['#e9eef6', '#b8c2d4']), 8);
	P(hx - 130, -165, hx, -240, hx + 130, -165); fs('#3f7fd0', 8);
	rrf(hx - 80, -130, 60, 54, 8, '#ffe9a0', 6);
	wglow(hx - 50, -103, 60, '255,230,140', 0.35);
	// drum spinning with the cable
	const ang = cab.y / 30;
	circ(hx + 40, -90, 40); fs('#6f7787', 7);
	for (let k = 0; k < 4; k++) line(hx + 40, -90, hx + 40 + Math.cos(ang + k * 1.57) * 34, -90 + Math.sin(ang + k * 1.57) * 34, INK, 5);
	line(hx + 40, -130, x - 46, PULLEY_Y, '#20242e', 5);
	// tower legs with lattice
	const top = PULLEY_Y + 30;
	for (const [a, b] of [[x - 120, x - 30], [x + 120, x + 30]]) {
		line(a, 0, b, top, INK, 26); line(a, 0, b, top, '#d0463c', 16);
	}
	for (let k = 0; k < 5; k++) {
		const u0 = k / 5, u1 = (k + 1) / 5;
		const y0 = lerp(0, top, u0), y1 = lerp(0, top, u1);
		const l0 = lerp(x - 120, x - 30, u0), r0 = lerp(x + 120, x + 30, u0), l1 = lerp(x - 120, x - 30, u1), r1 = lerp(x + 120, x + 30, u1);
		line(l0, y0, r1, y1, '#9e2f2a', 7); line(r0, y0, l1, y1, '#9e2f2a', 7); line(l1, y1, r1, y1, '#9e2f2a', 8);
	}
	// back strut
	line(x - 200, 0, x - 40, top + 40, INK, 20); line(x - 200, 0, x - 40, top + 40, '#d0463c', 11);
	// platform + pulley
	rrf(x - 90, top - 10, 180, 22, 6, '#c9ced8', 6);
	const pa = -cab.y / 46;
	wglow(x, PULLEY_Y, 90, '255,255,255', 0.15);
	circ(x, PULLEY_Y, 52); fs('#4a5266', 8);
	circ(x, PULLEY_Y, 38); fs('#8d97ab', 5);
	for (let k = 0; k < 6; k++) line(x, PULLEY_Y, x + Math.cos(pa + k * 1.047) * 36, PULLEY_Y + Math.sin(pa + k * 1.047) * 36, INK, 5);
	circ(x, PULLEY_Y, 10); fs('#ffd23a', 4);
	// flag on top
	const fw = Math.sin(t * 6) * 6;
	line(x, PULLEY_Y - 52, x, PULLEY_Y - 140, INK, 6);
	ctx.beginPath(); ctx.moveTo(x, PULLEY_Y - 140); ctx.quadraticCurveTo(x + 40, PULLEY_Y - 150 + fw, x + 80, PULLEY_Y - 132 + fw); ctx.lineTo(x + 80, PULLEY_Y - 96 + fw); ctx.quadraticCurveTo(x + 40, PULLEY_Y - 112 - fw, x, PULLEY_Y - 104); ctx.closePath(); fs('#ffd23a', 5);
	// dump bin beside the top stop
	P(x + 66, CAB_TOP - 110, x + 190, CAB_TOP - 110, x + 160, CAB_TOP - 20, x + 96, CAB_TOP - 20); fs(lg(0, CAB_TOP - 110, 0, CAB_TOP, ['#ffd23a', '#e09a12']), 7);
	line(x + 128, CAB_TOP - 20, x + 128, -20, INK, 14); line(x + 128, CAB_TOP - 20, x + 128, -20, '#8d97ab', 8);
}

// Conveyor from the dump bin down to the pier hopper.
const CONV = { x0: SH_X + 150, y0: -150, x1: DOCK1 + 40, y1: -300 };
function conveyor(t) {
	const { x0, y0, x1, y1 } = CONV;
	const len = Math.hypot(x1 - x0, y1 - y0), a = Math.atan2(y1 - y0, x1 - x0);
	// trestles
	for (let k = 1; k <= 7; k++) { const u = k / 7.4, x = lerp(x0, x1, u), y = lerp(y0, y1, u), gy = x < SHORE - 30 ? -4 : SEA_Y + 150; line(x - 24, gy, x, y + 10, INK, 12); line(x + 24, gy, x, y + 10, INK, 12); line(x - 24, gy, x, y + 10, '#c98249', 6); line(x + 24, gy, x, y + 10, '#c98249', 6); }
	ctx.save(); ctx.translate(x0, y0); ctx.rotate(a);
	rrf(-10, -14, len + 20, 30, 14, '#3a4258', 7);
	const sh = (t * 120) % 40;
	for (let s = -sh; s < len; s += 40) line(s, -10, s + 10, -10, '#8d97ab', 4);
	for (let s = 10; s < len; s += 60) { circ(s, 1, 9); fs('#c9ced8', 3); }
	// ore stream
	const sp = 120, gap = 52;
	for (let k = 0; k < len / gap; k++) {
		const s = ((t * sp + k * gap) % len);
		const cc = MFL[k % 4].ore;
		gem(s, -26, 12, cc[0], cc[1], s * 0.03);
	}
	ctx.restore();
	// pier hopper
	P(x1 - 50, y1 - 70, x1 + 70, y1 - 70, x1 + 30, y1 + 20, x1 - 10, y1 + 20); fs(lg(0, y1 - 70, 0, y1 + 20, ['#ffd23a', '#e09a12']), 7);
}
function pier(x0, x1) {
	for (let x = x0 + 20; x < x1; x += 70) { rrf(x - 9, -14, 18, SEA_Y + 140, 4, '#7a4a26', 5); }
	rrf(x0, -26, x1 - x0, 24, 6, lg(0, -26, 0, 0, ['#d99a5c', '#a8693a']), 6);
	for (let x = x0 + 20; x < x1; x += 34) line(x, -24, x, -4, 'rgba(36,26,58,0.35)', 3);
	for (const bx of [x0 + 40, x1 - 40]) { rrf(bx - 12, -50, 24, 26, 8, '#4a5266', 5); }
}

// ------------------------------------------------------------ the boat
function boat(t, st) {
	const bob = Math.sin(t * 2.6) * 5, tilt = Math.sin(t * 1.9) * 0.025 - clamp(st.v, -600, 600) * 0.00008;
	const sink = st.load * 12;
	// wake
	if (Math.abs(st.v) > 20) {
		const dir = Math.sign(st.v);
		ctx.fillStyle = 'rgba(255,255,255,0.85)';
		for (let k = 0; k < 8; k++) {
			const u = ((t * 3 + k / 8) % 1);
			ctx.beginPath(); ctx.ellipse(st.x - dir * (220 + u * 260), SEA_Y + 4, 40 * (1 - u) + 10, 9 * (1 - u) + 3, 0, 0, 7); ctx.fill();
		}
		ctx.beginPath(); ctx.ellipse(st.x + dir * 240, SEA_Y, 30 + Math.sin(t * 20) * 6, 14, 0, 0, 7); ctx.fill();
	}
	ctx.save(); ctx.translate(st.x, SEA_Y - 6 + bob + sink); ctx.rotate(tilt);
	// smoke from the funnel
	for (let k = 0; k < 5; k++) {
		const u = ((t * 0.8 + k / 5) % 1);
		ctx.fillStyle = `rgba(240,240,248,${0.8 * (1 - u)})`; circ(-150 - u * 120 - st.v * 0.05 * u, -250 - u * 160, 18 + u * 30); ctx.fill();
	}
	// funnel + deckhouse
	rrf(-172, -250, 44, 80, 6, lg(-172, 0, -128, 0, ['#ff6a5a', '#c8392c']), 7);
	rrf(-172, -250, 44, 18, 4, INK, 0);
	rrf(-205, -175, 130, 115, 12, lg(0, -175, 0, -60, ['#ffffff', '#d5e2f0']), 7);
	for (let k = 0; k < 3; k++) { rrf(-192 + k * 38, -150, 28, 28, 7, '#7fdcff', 5); }
	// mast + flag
	line(170, -60, 170, -230, INK, 8);
	const fw = Math.sin(t * 7) * 7;
	ctx.beginPath(); ctx.moveTo(170, -228); ctx.quadraticCurveTo(205, -238 + fw, 240, -222 + fw); ctx.lineTo(240, -188 + fw); ctx.quadraticCurveTo(205, -200 - fw, 170, -190); ctx.closePath(); fs('#ff5d73', 5);
	// cargo in the hold
	ctx.save(); rr(-70, -150, 220, 92, 0); ctx.clip();
	heap(40, -58, 200, st.load, ['#ffd23a', '#fff4b0'], 5);
	heap(40, -58 - st.load * 22, 150, st.load * 0.8, MFL[1].ore, 9);
	ctx.restore();
	// hull
	ctx.beginPath(); ctx.moveTo(-235, -70); ctx.lineTo(250, -70); ctx.quadraticCurveTo(262, -90, 280, -100); ctx.quadraticCurveTo(250, 10, 170, 40); ctx.lineTo(-180, 40); ctx.quadraticCurveTo(-225, 10, -235, -70); ctx.closePath();
	fs(lg(0, -100, 0, 40, ['#ffffff', '#e8eef6']), 9);
	ctx.save(); ctx.clip();
	ctx.fillStyle = lg(0, -20, 0, 40, ['#ff5a4a', '#c8392c']); ctx.fillRect(-260, -22, 560, 80);
	ctx.fillStyle = '#ffd23a'; ctx.fillRect(-260, -34, 560, 12);
	ctx.restore();
	ctx.beginPath(); ctx.moveTo(-235, -70); ctx.lineTo(250, -70); ctx.quadraticCurveTo(262, -90, 280, -100); ctx.quadraticCurveTo(250, 10, 170, 40); ctx.lineTo(-180, 40); ctx.quadraticCurveTo(-225, 10, -235, -70); ctx.closePath();
	ctx.strokeStyle = INK; ctx.lineWidth = 9; ctx.stroke();
	for (let k = 0; k < 4; k++) { circ(-140 + k * 90, -46, 11); fs('#7fdcff', 4); }
	ctx.strokeStyle = 'rgba(255,255,255,0.7)'; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(-200, -60); ctx.lineTo(200, -60); ctx.stroke();
	ctx.restore();
}

// ------------------------------------------------------------ crane on the island
function crane(t, bst) {
	const bx = 1600, top = -600, ax0 = 1220, ax1 = 1860;
	const PC = 2.6, ph = ((t / PC) % 1 + 1) % 1;
	const xb = DOCK2 + 45, xh = 1775, ylow = SEA_Y - 150 + bst.load * 6, yhigh = -480, yhop = -520;
	let tx = xb, hy = yhigh, full = false, tip = 0;
	if (ph < 0.18) { tx = xb; hy = lerp(yhigh, ylow, eIO(ph / 0.18)); }
	else if (ph < 0.26) { tx = xb; hy = ylow; full = ph > 0.21; }
	else if (ph < 0.42) { tx = xb; hy = lerp(ylow, yhigh, eIO((ph - 0.26) / 0.16)); full = true; }
	else if (ph < 0.62) { tx = lerp(xb, xh, eIO((ph - 0.42) / 0.2)); hy = yhigh; full = true; }
	else if (ph < 0.74) { tx = xh; hy = lerp(yhigh, yhop, eIO((ph - 0.62) / 0.12)); full = true; tip = Math.sin(span(ph, 0.66, 0.74) * Math.PI) * 0.9; }
	else { tx = lerp(xh, xb, eIO((ph - 0.74) / 0.26)); hy = lerp(yhop, yhigh, span(ph, 0.74, 0.85)); }
	// pouring into the hopper
	if (ph > 0.67 && ph < 0.8) for (let k = 0; k < 4; k++) { const u = ((ph - 0.67) / 0.13 + k * 0.25) % 1; gem(xh + 20 + k * 6, yhop + 40 + u * 120, 11, MFL[k % 4].ore[0], MFL[k % 4].ore[1], u * 5); }
	// tower
	line(bx - 50, 0, bx - 14, top, INK, 22); line(bx + 50, 0, bx + 14, top, INK, 22);
	line(bx - 50, 0, bx - 14, top, '#ffcc33', 12); line(bx + 50, 0, bx + 14, top, '#ffcc33', 12);
	for (let k = 0; k < 6; k++) { const y0 = lerp(0, top, k / 6), y1 = lerp(0, top, (k + 1) / 6); line(lerp(bx - 50, bx - 14, k / 6), y0, lerp(bx + 50, bx + 14, (k + 1) / 6), y1, '#c98a12', 6); }
	rrf(bx - 60, top - 70, 120, 74, 10, lg(0, top - 70, 0, top, ['#ffe066', '#e8a21a']), 7);
	rrf(bx - 40, top - 56, 40, 32, 6, '#7fdcff', 5);
	// jib
	rrf(ax0, top - 16, ax1 - ax0, 26, 8, lg(0, top - 16, 0, top + 10, ['#ffe066', '#e8a21a']), 7);
	for (let x = ax0 + 20; x < ax1 - 20; x += 44) line(x, top - 12, x + 22, top + 6, '#c98a12', 4);
	rrf(ax1 - 10, top - 30, 70, 60, 8, '#6f7787', 7);
	// trolley, rope, bucket
	rrf(tx - 26, top + 8, 52, 20, 6, '#4a5266', 5);
	line(tx - 10, top + 26, tx - 10, hy - 40, '#20242e', 4); line(tx + 10, top + 26, tx + 10, hy - 40, '#20242e', 4);
	ctx.save(); ctx.translate(tx, hy); ctx.rotate(tip);
	if (full) heap(0, -40, 60, 0.9, MFL[(Math.floor(t / PC)) % 4].ore, 3 + Math.floor(t / PC));
	P(-44, -44, 44, -44, 30, 10, -30, 10); fs(lg(0, -44, 0, 10, ['#c9ced8', '#7d8596']), 6);
	ctx.restore();
}

// ------------------------------------------------------------ the factory
function bricks(x0, y0, x1, y1) {
	ctx.fillStyle = lg(0, y0, 0, y1, ['#c97a5a', '#a85a40']); ctx.fillRect(x0, y0, x1 - x0, y1 - y0);
	ctx.strokeStyle = 'rgba(70,30,30,0.35)'; ctx.lineWidth = 3;
	for (let y = y0, r = 0; y < y1; y += 30, r++) {
		ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke();
		for (let x = x0 + (r % 2) * 32; x < x1; x += 64) { ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, Math.min(y1, y + 30)); ctx.stroke(); }
	}
	ctx.fillStyle = 'rgba(255,255,255,0.06)';
	for (let k = 0; k < 40; k++) ctx.fillRect(x0 + rnd(k) * (x1 - x0), y0 + Math.floor(rnd(k * 3) * (y1 - y0) / 30) * 30 + 3, 58, 24);
}
function gear(x, y, r, n, a, col) {
	ctx.save(); ctx.translate(x, y); ctx.rotate(a);
	ctx.beginPath();
	for (let k = 0; k < n; k++) {
		const a0 = k / n * Math.PI * 2, a1 = (k + 0.5) / n * Math.PI * 2;
		ctx.lineTo(Math.cos(a0) * r, Math.sin(a0) * r); ctx.lineTo(Math.cos(a0 + 0.1) * (r + 14), Math.sin(a0 + 0.1) * (r + 14));
		ctx.lineTo(Math.cos(a1 - 0.1) * (r + 14), Math.sin(a1 - 0.1) * (r + 14)); ctx.lineTo(Math.cos(a1) * r, Math.sin(a1) * r);
	}
	ctx.closePath(); fs(col, 6);
	circ(0, 0, r * 0.62); fs('rgba(0,0,0,0.18)', 4);
	for (let k = 0; k < 4; k++) line(0, 0, Math.cos(k * 1.57) * r * 0.6, Math.sin(k * 1.57) * r * 0.6, INK, 7);
	circ(0, 0, r * 0.2); fs('#ffd23a', 5);
	ctx.restore();
}
const CRUSH = 0.8;
function factory(t) {
	const L = FAC_L, R = FAC_R, T0 = FAC_TOP;
	// chimneys + smoke (behind)
	for (const [cx, h] of [[1960, 260], [2290, 330]]) {
		for (let k = 0; k < 6; k++) {
			const u = ((t * 0.5 + k / 6 + cx * 0.001) % 1);
			ctx.fillStyle = `rgba(235,235,245,${0.85 * (1 - u)})`; circ(cx + 20 + u * 140 + Math.sin(u * 6 + k) * 18, T0 - h - 30 - u * 260, 30 + u * 50); ctx.fill();
		}
		rrf(cx - 34, T0 - h, 68, h + 20, 6, lg(cx - 34, 0, cx + 34, 0, ['#d86a50', '#a8473a']), 8);
		rrf(cx - 44, T0 - h - 16, 88, 30, 6, '#4a3a48', 7);
		ctx.fillStyle = '#fff'; ctx.fillRect(cx - 34, T0 - h + 40, 68, 18); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.strokeRect(cx - 34, T0 - h + 40, 68, 18);
	}
	// interior back wall
	bricks(L, T0, R, 0);
	// sawtooth roof with skylights
	const teeth = 4, tw = (R - L + 60) / teeth;
	for (let k = 0; k < teeth; k++) {
		const x = L - 30 + k * tw;
		P(x, T0, x + tw, T0, x + tw, T0 - 110, x + tw * 0.25, T0); fs(lg(0, T0 - 110, 0, T0, ['#5a6a8a', '#3a4462']), 8);
		P(x + tw - 10, T0 - 92, x + tw - 10, T0 - 6, x + tw * 0.3, T0 - 6); fs('rgba(160,230,255,0.85)', 5);
	}
	rrf(L - 40, T0 - 12, R - L + 80, 28, 8, '#4a5266', 8);
	// sign
	rrf(2050, T0 - 210, 280, 70, 14, lg(0, T0 - 210, 0, T0 - 140, ['#ffe066', '#f2a91c']), 8);
	ctx.fillStyle = INK; ctx.font = '50px Nunito'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('GOLD  CO.', 2190, T0 - 173);
	line(2110, T0 - 140, 2110, T0 - 12, INK, 8); line(2270, T0 - 140, 2270, T0 - 12, INK, 8);
	// gears + pipes
	const ga = t * 1.4;
	gear(2470, -400, 62, 12, ga, '#b9c1cf');
	gear(2470 - 62 - 48 - 4, -400 + 30, 44, 9, -ga * 62 / 44 + 0.2, '#8d97ab');
	rrf(L + 20, -470, R - L - 40, 22, 10, lg(0, -470, 0, -448, ['#e0e6ee', '#8d97ab']), 6);
	for (let x = L + 80; x < R - 40; x += 150) rrf(x - 9, -476, 18, 34, 4, '#6f7787', 4);
	circ(1900, -410, 34); fs('#f4f6fa', 6);
	const nd = -2.2 + Math.sin(t * 5) * 0.25 + Math.sin(t * 13) * 0.08;
	line(1900, -410, 1900 + Math.cos(nd) * 24, -410 + Math.sin(nd) * 24, '#e8483c', 5);
	// steam puff
	const su = (t % 1.6) / 1.6;
	if (su < 0.6) { ctx.fillStyle = `rgba(255,255,255,${0.8 * (1 - su / 0.6)})`; circ(2380 + su * 40, -470 - su * 90, 14 + su * 40); ctx.fill(); }
	// hazard floor
	ctx.save(); rr(L, -22, R - L, 22, 0); ctx.clip();
	ctx.fillStyle = '#ffcc33'; ctx.fillRect(L, -22, R - L, 22); ctx.fillStyle = INK;
	for (let x = L - 20; x < R; x += 40) { P(x, -22, x + 18, -22, x + 4, 0, x - 14, 0); ctx.fill(); }
	ctx.restore();

	// ---- conveyor 1 from the hopper to the crusher
	const c1y = -350, c1x0 = 1740, c1x1 = 2080;
	rrf(c1x0, c1y - 12, c1x1 - c1x0, 26, 13, '#3a4258', 7);
	for (let x = c1x0 + 16; x < c1x1; x += 34) { circ(x, c1y + 1, 8); fs('#c9ced8', 3); line(x, c1y + 1, x + Math.cos(t * 10) * 7, c1y + 1 + Math.sin(t * 10) * 7, INK, 2); }
	for (let k = 0; k < 6; k++) { const s = ((t * 110 + k * 58) % (c1x1 - c1x0 - 20)); gem(c1x0 + 10 + s, c1y - 26, 13, MFL[k % 4].ore[0], MFL[k % 4].ore[1], s * 0.04); }
	// hopper (outside, left)
	P(1700, -520, 1850, -520, 1800, -390, 1750, -390); fs(lg(0, -520, 0, -390, ['#ffd23a', '#e09a12']), 8);
	rrf(1758, -392, 34, 40, 4, '#6f7787', 6);

	// ---- crusher
	const cx = 2140, ph = (t % CRUSH) / CRUSH;
	let sy;
	if (ph < 0.12) sy = lerp(-470, -300, eIn(ph / 0.12)); else if (ph < 0.3) sy = -300; else sy = lerp(-300, -470, eIO((ph - 0.3) / 0.7));
	const lastHit = Math.floor(t / CRUSH) * CRUSH + CRUSH * 0.12;
	rrf(cx - 90, -520, 24, 330, 6, '#6f7787', 7); rrf(cx + 66, -520, 24, 330, 6, '#6f7787', 7);
	rrf(cx - 100, -560, 200, 52, 10, lg(0, -560, 0, -508, ['#ff6a5a', '#c8392c']), 8);
	line(cx, -510, cx, sy - 40, '#c9ced8', 22); line(cx, -510, cx, sy - 40, INK, 0.1);
	ctx.strokeStyle = INK; ctx.lineWidth = 5; ctx.strokeRect(cx - 11, -510, 22, sy - 40 + 510);
	rrf(cx - 60, sy - 46, 120, 50, 10, lg(0, sy - 46, 0, sy, ['#c9ced8', '#6f7787']), 8);
	rrf(cx - 70, -296, 140, 40, 8, '#4a5266', 8);
	if (t - lastHit >= 0 && t - lastHit < 0.5) {
		chips(t, lastHit, cx, -300, 10, Math.floor(lastHit * 10), ['#ffd23a', '#ff8fb0', '#7fdcff'], -1, 0.8);
		chips(t, lastHit, cx, -300, 6, Math.floor(lastHit * 10) + 3, ['#ffd23a', '#ffe066'], 1, 0.8);
	}
	// chute to the furnace
	P(cx + 30, -256, cx + 70, -256, 2250, -170, 2210, -170); fs('#8d97ab', 6);
	for (let k = 0; k < 3; k++) { const u = ((t * 1.6 + k / 3) % 1); circ(lerp(cx + 50, 2230, u), lerp(-262, -176, u), 9); fs('#ffd23a', 3); }

	// ---- furnace
	const fx = 2290;
	rrf(fx - 90, -330, 180, 312, 22, lg(0, -330, 0, -18, ['#6a7088', '#3a3f52']), 9);
	for (let y = -300; y < -30; y += 46) line(fx - 86, y, fx + 86, y, 'rgba(255,255,255,0.12)', 4);
	const fl = 0.8 + Math.sin(t * 17) * 0.1 + Math.sin(t * 7.7) * 0.1;
	wglow(fx, -150, 230, '255,150,40', 0.55 * fl);
	rrf(fx - 52, -220, 104, 120, 50, '#2a1418', 7);
	ctx.save(); rr(fx - 46, -214, 92, 108, 46); ctx.clip();
	ctx.fillStyle = lg(0, -214, 0, -106, ['#ffef9a', '#ff9a2a', '#ff4a1a']); ctx.fillRect(fx - 50, -220, 100, 120);
	for (let k = 0; k < 5; k++) { const fh = 40 + Math.sin(t * 11 + k * 1.7) * 18; P(fx - 50 + k * 22, -106, fx - 40 + k * 22, -106 - fh, fx - 30 + k * 22, -106); ctx.fillStyle = k % 2 ? '#fff3b0' : '#ffd23a'; ctx.fill(); }
	ctx.restore();
	rrf(fx - 70, -340, 140, 26, 8, '#4a5266', 7);
	// ladle pouring
	const pour = 0.5 + 0.5 * Math.sin(t * 2.4);
	ctx.save(); ctx.translate(fx + 110, -130); ctx.rotate(0.3 + pour * 0.5);
	P(-30, -30, 34, -30, 26, 26, -22, 26); fs(lg(0, -30, 0, 26, ['#8d97ab', '#4a5266']), 7);
	ctx.fillStyle = '#ffd23a'; ctx.fillRect(-26, -26, 56, 10);
	ctx.restore();
	const sx = fx + 140 + pour * 10;
	ctx.fillStyle = lg(0, -130, 0, -60, ['#fff3b0', '#ffb21a']);
	rr(sx - 6, -128, 12 + pour * 4, 80, 6); ctx.fill();
	wglow(sx, -70, 60, '255,190,60', 0.6);

	// ---- conveyor 2 with molds
	const c2y = -48, c2x0 = 2380, c2x1 = R + 40;
	rrf(c2x0, c2y - 10, c2x1 - c2x0, 24, 12, '#3a4258', 7);
	const msp = 70, gap = 74;
	for (let k = 0; k < 6; k++) {
		const x = c2x0 + 10 + ((t * msp + k * gap) % (c2x1 - c2x0 - 20));
		const filled = x > sx - 10;
		const cool = sat((x - sx) / 140);
		rrf(x - 26, c2y - 30, 52, 22, 5, '#5a6278', 5);
		if (filled) {
			ctx.fillStyle = cool < 1 ? lerpColor('#ff8a2a', '#ffd23a', cool) : '#ffd23a';
			rr(x - 22, c2y - 34, 44, 14, 4); ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 4; ctx.stroke();
			ctx.fillStyle = 'rgba(255,255,255,0.6)'; ctx.fillRect(x - 16, c2y - 32, 22, 4);
		}
	}
	// outer walls (cutaway frame)
	rrf(L - 26, T0, 30, -T0, 6, lg(L - 26, 0, L + 4, 0, ['#a8473a', '#d86a50']), 8);
	rrf(R - 4, T0, 30, -T0 - 140, 6, lg(R - 4, 0, R + 26, 0, ['#d86a50', '#a8473a']), 8);
	rrf(R - 10, -150, 42, 20, 4, '#4a5266', 6);
	// worker at the furnace lever
	const lever = Math.sin(t * 2.4) * 0.4;
	rig('rigHappy', 'armE', fx - 150, -22, 0.22, -0.4 + lever, 1);
	// worker by the gold pile outside
	const hopT = Math.abs(Math.sin(t * 4)) * 10;
	rig('rigStar', 'armE', R + 230, -22 - hopT, 0.22, -1.3 + Math.sin(t * 8) * 0.3, -1);
	// gold pile outside the door
	const px = R + 120;
	wglow(px, -60, 160, '255,210,80', 0.5);
	const rows = [5, 4, 3, 2];
	rows.forEach((n, r) => { for (let k = 0; k < n; k++) { const x = px - (n - 1) * 26 + k * 52, y = -30 - r * 24; rrf(x - 24, y - 14, 48, 22, 5, lg(0, y - 14, 0, y + 8, ['#fff3a0', '#ffcc33', '#e09a12']), 4); } });
	// bars drop off the belt, coins jump out of the pile
	for (let k = 0; k < 3; k++) {
		const T1 = 1.06, u = ((t + k * T1 / 3) % T1) / T1;
		spr2('coin', px - 40 + k * 40 + u * (k - 1) * 60, -110 - Math.sin(u * Math.PI) * 140, 0.4, u * 8, sat((1 - u) * 4));
	}
	const per = 1.06, last = Math.floor(t / per) * per;
	wpop(t, last, px, -200, '+$' + fmt(2.5e5 * (1 + Math.floor(t / per) % 4)), 46, 1.0);
}
function spr2(name, x, y, s, rot, alpha) { wspr(name, x, y, s, rot, 1, alpha); }

// The whole empire: cam = {x, y, s} (world point at the screen center).
function empireWorld(t, cam) {
	ctx.save();
	ctx.translate(CX, CY); ctx.scale(cam.s * K, cam.s * K); ctx.translate(-cam.x, -cam.y);
	const cab = cabinState(t), bst = boatState(t);
	sky(t);
	rockAndGround();
	sea(t);
	for (let i = 0; i < NFL; i++) mineFloor(i, t);
	shaft(t, cab);
	for (let i = 0; i < NFL; i++) floorLife(i, t);
	// cabin loading hops on the scripted trip
	for (const [a, b, fl] of [[8.75, 9.4, 1], [10.0, 10.55, 0]]) {
		for (let k = 0; t > a && k < 8; k++) hop(t, a + k * 0.08, 0.32, CAVE_L + 20, floorY(fl) - 20, SH_X, floorY(fl) - 60, 80, MFL[fl].ore, k, 13);
	}
	// office + palms on the mainland
	officeHouse(-1050, t);
	palm(-820, 0, 1.0, t); palm(-1300, 0, 0.8, t + 1); palm(250, 0, 0.85, t + 2);
	headframe(t, cab);
	cabin(t, cab);
	// dump into the bin
	if (cab.tip > 0.3) for (let k = 0; k < 4; k++) { const u = ((t * 3 + k / 4) % 1); gem(SH_X + 70 + u * 60, CAB_TOP - 70 + u * 60, 12, MFL[k].ore[0], MFL[k].ore[1], u * 6); }
	pier(SHORE - 40, SHORE + 70);
	conveyor(t);
	// stream from the pier hopper into a docked boat
	if (Math.abs(bst.x - DOCK1) < 4) for (let k = 0; k < 3; k++) { const u = ((t * 2.2 + k / 3) % 1); gem(CONV.x1 + 10, CONV.y1 + 40 + u * 230, 12, MFL[k + 1].ore[0], MFL[k + 1].ore[1], u * 4); }
	boat(t, bst);
	seaFront(t);
	pier(COAST - 50, COAST + 20);
	crane(t, bst);
	factory(t);
	ctx.restore();
}

function palm(x, y, s, t) {
	ctx.save(); ctx.translate(x, y); ctx.scale(s, s);
	ctx.strokeStyle = INK; ctx.lineWidth = 30; ctx.lineCap = 'round';
	ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(20, -120, -10, -240); ctx.stroke();
	ctx.strokeStyle = '#a8693a'; ctx.lineWidth = 20; ctx.stroke();
	for (let k = 0; k < 6; k++) {
		const a = -Math.PI / 2 + (k - 2.5) * 0.55 + Math.sin(t * 1.8 + k) * 0.05;
		ctx.save(); ctx.translate(-10, -240); ctx.rotate(a);
		ctx.beginPath(); ctx.moveTo(0, 0); ctx.quadraticCurveTo(70, -36, 140, 14); ctx.quadraticCurveTo(70, 8, 0, 0); fs('#46b84a', 6);
		ctx.restore();
	}
	circ(-20, -232, 14); fs('#8a5a30', 4); circ(4, -228, 14); fs('#8a5a30', 4);
	ctx.restore();
}
function officeHouse(x, t) {
	rrf(x - 150, -230, 300, 230, 12, lg(0, -230, 0, 0, ['#fff4dc', '#e8d2a8']), 8);
	P(x - 175, -222, x, -330, x + 175, -222); fs(lg(0, -330, 0, -222, ['#4aa8ff', '#2a6fd0']), 8);
	for (const wx of [-95, 45]) { rrf(x + wx, -180, 50, 50, 8, '#9fe6ff', 6); line(x + wx + 25, -180, x + wx + 25, -130, INK, 3); }
	rrf(x - 30, -100, 60, 100, 8, '#a8693a', 7);
	rrf(x - 80, -290, 160, 44, 10, '#ffd23a', 6);
	ctx.fillStyle = INK; ctx.font = '30px Nunito'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('OFFICE', x, -267);
}
