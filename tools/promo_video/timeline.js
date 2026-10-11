// The promo timeline: scenes, camera, captions, the end card and the list
// of sound events (render.py turns them into the soundtrack).
'use strict';

const T = { s2: 3.5, up: 6.0, mine: 8.0, boat: 12.4, fac: 15.4, over: 19.0, worlds: 20.6, rich: 25.6, end: 28.2, fin: 32.5 };
const TAPS = [3.75, 4.12, 4.48, 4.84, 5.14, 5.42];
const TAP_V = [1, 5, 5, 10, 25, 50];
const PRESS = 5.86;
const CLICKS = [T.end + 1.9, T.end + 3.2];

const topY = () => -H / 2 / K;
const botY = () => H / 2 / K;

function money(t) {
	if (t < T.s2) return 0;
	if (t < T.mine) {
		let v = 0;
		TAPS.forEach((tt, i) => { if (t > tt + 0.6) v += TAP_V[i]; });
		if (t > T.up + 0.4) v = lerp(96, 1250, eOut(span(t, T.up + 0.4, T.mine)));
		return v;
	}
	if (t < T.over) return 1250 * Math.pow(2000, eIO(span(t, T.mine, T.over)));
	if (t < T.worlds) return 2.5e6 * Math.pow(20, eIO(span(t, T.over, T.worlds)));
	if (t < T.rich) return 5e7 * Math.pow(1000, eIO(span(t, T.worlds, T.rich)));
	return 5e10 * Math.pow(2e4, eOut(span(t, T.rich, T.rich + 2.4)));
}

function caption(s, t, t0, t1, y, size = 110, fill = 'white') {
	if (!CFG.captions || t < t0 || t > t1) return;
	const u = span(t, t0, t0 + 0.4);
	const out = span(t, t1 - 0.25, t1);
	text(s, 0, y, size, { fill, scale: eBack(u) * (1 - out * 0.2), alpha: 1 - out, rot: Math.sin(t * 3) * 0.02 });
}

function vignette() {
	const g = ctx.createRadialGradient(CX, CY, Math.min(W, H) * 0.35, CX, CY, Math.max(W, H) * 0.75);
	g.addColorStop(0, 'rgba(5,10,40,0)');
	g.addColorStop(1, 'rgba(5,10,40,0.4)');
	ctx.fillStyle = g;
	ctx.fillRect(0, 0, W, H);
}

// ---------------------------------------------------------------- scenes
function sceneAt(t) {
	if (t < T.mine) return sceneStart;
	if (t < T.worlds) return sceneEmpire;
	if (t < T.rich) return sceneWorlds;
	if (t < T.end || !CFG.endcard) return sceneRich;
	return sceneEnd;
}
const CUTS = [T.mine, T.worlds, T.rich, T.end];

function render(t) {
	ctx.clearRect(0, 0, W, H);
	t += CFG.t0 || 0;
	// circle-reveal transitions: the old scene stays outside a growing circle
	let cut = null;
	for (const c of CUTS) if (t >= c && t < c + 0.45 && (c !== T.end || CFG.endcard)) cut = c;
	if (cut !== null) {
		sceneAt(cut - 0.001)(Math.min(t, cut - 0.001));
		const u = eIO((t - cut) / 0.45), R = Math.hypot(W, H) * 0.55 * u;
		ctx.save(); ctx.beginPath(); ctx.arc(CX, CY, Math.max(1, R), 0, Math.PI * 2); ctx.clip();
		sceneAt(t)(t);
		ctx.restore();
		ctx.strokeStyle = `rgba(255,255,255,${0.9 * (1 - u)})`; ctx.lineWidth = 40 * K;
		ctx.beginPath(); ctx.arc(CX, CY, Math.max(1, R), 0, Math.PI * 2); ctx.stroke();
	} else {
		sceneAt(t)(t);
	}
	vignette();
	if (t < T.end || !CFG.endcard) {
		let bump = 0;
		for (const tt of TAPS) bump = Math.max(bump, 1 - Math.abs(t - tt - 0.7) * 5);
		bump = Math.max(bump, (Math.sin(t * 14) * 0.5 + 0.5) * span(t, T.mine, T.end) * 0.35);
		counter(money(t), clamp(bump, 0, 1), sat((t - 0.2) * 3));
	}
	sceneCaptions(t);
	if (t < 0.25) { ctx.fillStyle = `rgba(0,0,0,${1 - t / 0.25})`; ctx.fillRect(0, 0, W, H); }
}

function sceneCaptions(t) {
	const cy = topY() + 330;
	caption('I WAS BROKE...', t, 0.3, T.s2, cy, 120);
	caption('TAP TO DIG!', t, T.s2, 5.25, cy, 140, 'gold');
	caption('UPGRADE!', t, 5.3, T.up, cy, 130, 'gold');
	caption('LEVEL UP!', t, T.up + 0.05, T.mine, cy, 140, 'gold');
	caption('DIG DEEPER!', t, T.mine + 0.3, T.boat - 0.1, cy, 120, 'white');
	caption('SHIP THE ORE!', t, T.boat + 0.1, T.fac - 0.1, cy, 112, 'white');
	caption('SMELT GOLD!', t, T.fac + 0.1, T.over - 0.1, cy, 124, 'gold');
	caption('BUILD AN EMPIRE!', t, T.over + 0.1, T.worlds, cy, 108, 'white');
	caption('NEW WORLDS!', t, T.worlds + 0.3, T.rich, cy, 120, 'white');
	caption('GET RICH!', t, T.rich + 0.3, T.end, cy, 150, 'gold');
}

// A boulder with ore; cracks grow with every hit.
function boulder(x, y, r, rich, shake, cracks, grey) {
	ctx.save(); ctx.translate(x + Math.sin(shake * 40) * shake * 10, y);
	const n = 11;
	ctx.beginPath();
	for (let k = 0; k < n; k++) { const a = k / n * Math.PI * 2, rr_ = r * (0.84 + rnd(k * 3 + (rich ? 9 : 0)) * 0.2); ctx.lineTo(Math.cos(a) * rr_, Math.sin(a) * rr_ * 0.82); }
	ctx.closePath();
	const c0 = rich ? '#7a64b0' : lerpColor('#a2948a', '#8a837c', grey), c1 = rich ? '#3f2f6e' : lerpColor('#6a5c52', '#56504a', grey);
	fs(lg(0, -r, 0, r, [c0, c1]), 10);
	ctx.save(); ctx.clip();
	ctx.fillStyle = 'rgba(255,255,255,0.16)'; P(-r, -r, r * 0.2, -r, -r * 0.2, -r * 0.1, -r, r * 0.1); ctx.fill();
	ctx.restore();
	const gems = rich ? [[-50, -40, 34, '#ffd23a', '#fff4b0'], [30, -70, 28, '#2ee08a', '#cdffe4'], [40, 20, 36, '#ffd23a', '#fff4b0'], [-30, 40, 26, '#ff4d6d', '#ffc4cd'], [80, -20, 22, '#7fdcff', '#eafcff']]
		: [[-40, -30, 18, lerpColor('#ff7fa6', '#9a8a90', grey), '#ffd6e3'], [30, 30, 15, lerpColor('#7fdcff', '#8a9aa0', grey), '#eafcff']];
	if (rich) wglow(0, 0, r * 1.5, '255,214,90', 0.45 + Math.sin(shake * 20) * 0.1);
	for (const g of gems) gem(g[0] * r / 150, g[1] * r / 150, g[2] * r / 150, g[3], g[4], g[0] * 0.01);
	ctx.strokeStyle = INK; ctx.lineWidth = 6; ctx.lineCap = 'round';
	for (let k = 0; k < cracks; k++) {
		const a = Math.PI + (rnd(k * 7) - 0.5) * 1.6;
		let px = Math.cos(a) * r * 0.8, py = Math.sin(a) * r * 0.6;
		ctx.beginPath(); ctx.moveTo(px, py);
		for (let s = 0; s < 3; s++) { px += 30 + rnd(k * 5 + s) * 20; py += (rnd(k * 9 + s) - 0.5) * 50; ctx.lineTo(px, py); }
		ctx.stroke();
	}
	ctx.restore();
}

// 0 - 8 s: broke, taps, the upgrade.
function sceneStart(t) {
	const up = t >= T.up;
	const grey = up ? 1 - eOut(span(t, T.up, T.up + 0.6)) : 1;
	seaBg(grey, t);
	const fy = botY() - 360;
	for (let i = 0; i < 14; i++) {
		const u = ((t * 0.12 + rnd(i)) % 1);
		bubble((rnd(i * 3) - 0.5) * W / K, botY() - u * (H / K + 200), 8 + rnd(i * 5) * 14, 0.8);
	}
	seaFloor(fy, grey);
	coral(-430, fy + 60, 1.1, up ? '#ff5f7e' : '#7d6a6e', up ? '#ffb15e' : '#8d8070');
	const wide = W / K > 1500;
	const s = wide ? 0.74 : 0.95, dx = wide ? -330 : -270, dy = fy + 170;
	const rx = dx + 653 * s, ry = dy - 147 * s, rR = 174 * s;
	ctx.save(); ctx.translate(CX, CY); ctx.scale(K, K);
	if (!up) {
		let prev = null, next = null;
		for (const h of TAPS) { if (h <= t) prev = h; else if (next === null) next = h; }
		const ang = swingAt(t, prev, next);
		const shake = prev === null ? 0 : Math.max(0, 1 - (t - prev) * 6);
		const cracks = TAPS.filter((h) => h <= t).length;
		boulder(rx, ry, rR, false, shake, cracks, grey);
		const breath = Math.sin(t * 2.2) * 0.4;
		rig('rigSad', 'armP', dx, dy, s, ang, 1, 0, prev === null ? breath * 0.3 : shake * 0.5);
		if (prev !== null) {
			const [hx, hy] = hitPoint(dx, dy, s);
			TAPS.forEach((h, i) => {
				chips(t, h, hx + 20, hy, 10, i * 13, ['#a2948a', '#ff7fa6', '#7fdcff'], -1, 1.3);
				hop(t, h + 0.02, 0.55, hx + 30, hy, hx - 120 - i * 25, hy - 40, 260, i % 2 ? ['#7fdcff', '#eafcff'] : ['#ff7fa6', '#ffd6e3'], i, 26);
			});
		}
		if (t < T.s2 + 0.3) {
			const a = t * 5, fx = dx + Math.cos(a) * 190, fyy = dy - 640 + Math.sin(a * 1.3) * 70;
			circ(fx, fyy, 9); ctx.fillStyle = INK; ctx.fill();
			ctx.fillStyle = 'rgba(255,255,255,0.7)'; ctx.beginPath(); ctx.ellipse(fx - 6, fyy - 10, 9, 5, -0.5, 0, 7); ctx.fill();
		}
	} else {
		// the old rock bursts, a rich vein pops in, the diver mines fast
		const tu = t - T.up;
		chips(t, T.up, rx, ry, 26, 99, ['#a2948a', '#ff7fa6', '#7fdcff', '#ffd23a'], -1, 2.2);
		chips(t, T.up, rx, ry, 18, 77, ['#a2948a', '#ffd23a'], 1, 2.0);
		const pop = eBack(span(t, T.up + 0.15, T.up + 0.55));
		const [prev, next] = hitsPeriodic(t, 0.4, T.up + 0.6);
		const p0 = tu < 0.6 ? null : prev, n0 = tu < 0.6 ? T.up + 0.6 + 0.4 : next;
		const shake = p0 === null ? 0 : Math.max(0, 1 - (t - p0) * 8);
		wglow(dx, dy - 300, 520, '255,214,90', 0.55 * (1 - span(t, T.up, T.up + 1.6) * 0.6));
		if (pop > 0) { ctx.save(); ctx.translate(rx, ry + rR); ctx.scale(pop, pop); ctx.translate(-rx, -ry - rR); boulder(rx, ry, rR * 1.1, true, shake, 0, 0); ctx.restore(); }
		const bp = eBack(span(t, T.up, T.up + 0.35));
		rig('rigHappy', 'armG', dx, dy, s * bp, swingAt(t, p0, n0), 1, 0, shake * 0.5);
		if (p0 !== null) {
			const [hx, hy] = hitPoint(dx, dy, s);
			for (let k = -3; k <= 0; k++) {
				const h = p0 + k * 0.4; if (h < T.up + 0.6) continue;
				const j = Math.round((h - T.up) / 0.4);
				chips(t, h, hx + 20, hy, 10, j * 7, ['#ffd23a', '#2ee08a', '#ff4d6d'], -1, 1.3);
				const kind = [['#ffd23a', '#fff4b0'], ['#2ee08a', '#cdffe4'], ['#ff4d6d', '#ffc4cd'], ['#7fdcff', '#eafcff']][j % 4];
				hop(t, h + 0.02, 0.6, hx + 30, hy, hx - 160 - (j % 3) * 60, hy - 60, 300, kind, j, 30);
			}
		}
	}
	ctx.restore();
	// taps: pops and coins
	const coins = [];
	const [hx, hy] = (() => { const sx = dx + SHOULDER[0] * s, sy = dy + SHOULDER[1] * s; return [sx + Math.cos(HIT) * REACH * s, sy + Math.sin(HIT) * REACH * s]; })();
	TAPS.forEach((tt, i) => {
		popText(t, tt, hx - 60 + (i % 2) * 60, hy - 320, '+' + TAP_V[i], 84);
		for (let k = 0; k < 3; k++) coins.push({ t: tt + 0.05 + k * 0.05, x: hx - 100 + (k - 1) * 60, y: hy - 200, dx: (k - 1) * 120 });
	});
	if (up) for (let j = 0; j < 4; j++) {
		const h = T.up + 0.6 + j * 0.4;
		popText(t, h, hx - 40 + (j % 2) * 80, hy - 360, '+' + [50, 120, 250, 500][j], 92);
		for (let k = 0; k < 4; k++) coins.push({ t: h + 0.05 + k * 0.04, x: hx - 120 + (k - 1) * 50, y: hy - 220, dx: (k - 1.5) * 100 });
	}
	flyingCoins(t, coins);
	// the upgrade button
	const by = botY() - 170;
	const bIn = eBack(span(t, 5.25, 5.65));
	const bOut = span(t, T.up + 0.2, T.up + 0.5);
	if (t > 5.25 && bOut < 1) {
		const press = t > PRESS && t < T.up + 0.15 ? 1 : 0;
		const pulse = 1 + Math.sin(t * 12) * 0.03;
		button(0, by + (1 - bIn) * 400 + bOut * 400, 600, 150, 'UPGRADE!', ['#7ef07a', '#2fb84a', '#1f7a35'], press, { scale: pulse, size: 74 });
	}
	confetti(t, T.up, dx + 100, dy - 400, 90, 7, 1.3);
	if (up && !CFG.captions) popText(t, T.up + 0.1, 0, dy - 760, 'LEVEL UP!', 120, 'gold');
	// the tapping hand
	const tx = rx - 40, ty = ry - 20;
	let hxx = 300, hyy = botY() - 120, press = 0, ha = 0;
	if (t > 2.6 && t < T.s2 + 0.1) { ha = span(t, 2.6, 2.9); const u = eIO(span(t, 2.6, T.s2)); hxx = lerp(380, tx, u); hyy = lerp(botY(), ty, u); }
	if (t >= T.s2 && t < 5.5) { ha = 1; hxx = tx; hyy = ty; for (const tt of TAPS) press = Math.max(press, 1 - Math.abs(t - tt) * 8); }
	if (t >= 5.5 && t < T.up + 0.5) { ha = 1 - span(t, T.up + 0.2, T.up + 0.5); const u = eIO(span(t, 5.5, PRESS)); hxx = lerp(tx, 60, u); hyy = lerp(ty, by + 10, u); press = t > PRESS && t < T.up + 0.15 ? 1 : 0; }
	hand(hxx, hyy, clamp(press, 0, 1), ha);
}

// 8 - 20.6 s: one continuous camera over the working empire.
function camAt(t) {
	const pw = W / K, ph_ = H / K;
	const fit = Math.min(pw / 3900, ph_ / 2300);
	const portrait = H > W;
	const keys = [
		[T.mine, { x: -250, y: 520, s: 1.3 }],
		[10.5, { x: -240, y: 400, s: 1.15 }],
		[11.7, { x: -320, y: -160, s: 1.0 }],
		[T.boat, { x: -60, y: -150, s: 1.05 }],
		[13.0, { x: DOCK1 + 60, y: -130, s: 1.1 }],
		[15.0, { x: DOCK2 + 120, y: -150, s: 1.05 }],
		[T.fac, { x: portrait ? 1640 : 1800, y: portrait ? -300 : -270, s: portrait ? 1.4 : 1.15 }],
		[18.6, { x: portrait ? 2420 : 2250, y: portrait ? -300 : -270, s: portrait ? 1.4 : 1.15 }],
		[19.75, { x: portrait ? 300 : 820, y: portrait ? 250 : 300, s: portrait ? 0.36 : fit }],
		[T.worlds, { x: portrait ? 1150 : 820, y: portrait ? 250 : 300, s: portrait ? 0.36 : fit * 1.02 }],
	];
	if (t <= keys[0][0]) return keys[0][1];
	for (let i = 0; i < keys.length - 1; i++) {
		const [ta, a] = keys[i], [tb, b] = keys[i + 1];
		if (t < tb) {
			const u = eIO((t - ta) / (tb - ta));
			// zoom in log space feels even
			return { x: lerp(a.x, b.x, u), y: lerp(a.y, b.y, u), s: Math.exp(lerp(Math.log(a.s), Math.log(b.s), u)) };
		}
	}
	return keys[keys.length - 1][1];
}
function sceneEmpire(t) {
	// the boat leg follows the boat itself
	let cam = camAt(t);
	if (t >= 13.0 && t < 15.0) { const b = boatState(t); cam = { x: b.x + 90, y: cam.y, s: cam.s }; }
	empireWorld(t, cam);
	if (t > T.over) coinRain(t, T.over + 0.2, 12, 31, 0.9);
}

// 20.6 - 25.6 s: four worlds swipe in, each unlocks.
function sceneWorlds(t) {
	const per = (T.rich - T.worlds) / 4;
	const i = clamp(Math.floor((t - T.worlds) / per), 0, 3);
	const lt = t - T.worlds - i * per;
	const prev = WORLDS[Math.max(0, i - 1)], cur = WORLDS[i];
	const mix = eOut(sat(lt / 0.4));
	fillBg([lerpColor(prev.bg[0], cur.bg[0], mix), lerpColor(prev.bg[1], cur.bg[1], mix)]);
	rays(0, 0, 18, 'rgba(255,255,255,0.12)', t * 0.2);
	const s = Math.min((W / K) / 900, (H / K - 520) / 940) * 0.85;
	if (i > 0 && lt < 0.45) {
		const u = eIn(sat(lt / 0.45));
		worldCard(i - 1, -u * 1400, 80, s * (1 - u * 0.2), t, 1);
	}
	const inU = eBack(sat(lt / 0.5));
	worldCard(i, (1 - inU) * 1300, 80, s, t, span(lt, 0.45, 0.85));
	if (lt > 0.5) {
		confetti(t, T.worlds + i * per + 0.5, 0, -100, 50, 100 + i * 13, 0.9);
		popText(t, T.worlds + i * per + 0.55, 0, 380, 'UNLOCKED!', 100, 'gold');
	}
}

// 25.6 - 28.2 s: rich!
function sceneRich(t) {
	fillBg(['#1a6fc4', '#0a2d66']);
	rays(0, 100, 22, 'rgba(255,240,180,0.35)', t * 0.35, 2600);
	glow(160, 260, 700, 'rgba(255,200,80,A)', 0.6);
	coinRain(t, T.rich, 14, 77);
	const fy = botY() - 220;
	seaFloor(fy, 0);
	spr('chest', 200, fy + 60, 0.9);
	fountain(t, T.rich + 0.1, 99, 200, fy - 380, 26, 5, 1.0);
	const hop_ = Math.abs(Math.sin((t - T.rich) * 5)) * 40;
	spr('diverGold', -230, fy + 90 - hop_, 0.66, Math.sin(t * 5) * 0.05);
	spr('bar', -20, fy + 120, 1.2, -0.1);
	spr('bar', 430, fy + 130, 1.0, 0.12);
	for (let k = 0; k < 12; k++) {
		const ph = (t * 0.8 + rnd(k)) % 1;
		sparkle((rnd(k * 3) - 0.5) * 900, (rnd(k * 5) - 0.6) * 900, 30 * Math.sin(ph * Math.PI), 1);
	}
}

// The classic arrow mouse cursor, tip at design (x, y).
function arrowCursor(x, y, press, alpha) {
	if (alpha <= 0) return;
	ctx.save(); ctx.globalAlpha = alpha;
	ctx.translate(X(x), Y(y)); const s = K * 1.55 * (1 - press * 0.12); ctx.scale(s, s); ctx.rotate(-0.12);
	const pts = [0, 0, 0, 172, 42, 134, 72, 200, 104, 186, 74, 122, 128, 122];
	ctx.save(); ctx.translate(10, 14); P(...pts); ctx.fillStyle = 'rgba(10,8,30,0.4)'; ctx.fill(); ctx.restore();
	P(...pts); ctx.fillStyle = '#ffffff'; ctx.fill();
	ctx.strokeStyle = '#111122'; ctx.lineWidth = 10; ctx.lineJoin = 'round'; ctx.stroke();
	ctx.restore();
}

const TIPX = () => (W / K > 1500 ? 300 : 300);

// 28.2 - 32.5 s: logo, a huge TRY NOW and the cursor clicking it.
function sceneEnd(t) {
	fillBg(['#2a7fe0', '#0a2d66']);
	rays(0, -60, 24, 'rgba(255,255,255,0.18)', t * 0.3, 2600);
	coinRain(t, T.end - 1, 8, 91, 0.6);
	glow(0, -150, 760, 'rgba(120,220,255,A)', 0.45);
	const e = T.end;
	const wide = W / K > 1500;
	const portrait = H > W;
	// logo with the title
	const lu = eElastic(span(t, e + 0.1, e + 1.1));
	const lw = Math.min(portrait ? 1000 : 1080, W / K * 0.9);
	const ly = portrait ? -560 : -400;
	if (lu > 0 && SPR.logo) {
		ctx.save();
		ctx.translate(X(0), Y(ly + Math.sin(t * 2) * 8));
		ctx.scale(lu, lu);
		const lh = lw * SPR.logo.height / SPR.logo.width;
		ctx.drawImage(SPR.logo, -lw * K / 2, -lh * K / 2, lw * K, lh * K);
		ctx.restore();
	}
	if (CFG.sub !== '') text('DIVE • MINE • GET RICH', 0, ly + (portrait ? 230 : 200), 50, { fill: 'gold', alpha: span(t, e + 0.6, e + 1.0) });
	// side heroes
	const ek = Math.min(1, (botY() - 420) / 540) * (wide ? 1.5 : 1);
	spr('diverStar', wide ? -760 : -330, Math.min(880, botY() - 20), (portrait ? 0.42 : 0.58) * ek * eBack(span(t, e + 0.5, e + 0.9)), Math.sin(t * 6) * 0.06);
	spr('chest', wide ? 760 : 330, Math.min(840, botY() - 40), (portrait ? 0.46 : 0.6) * ek * eBack(span(t, e + 0.6, e + 1.0)));
	// the giant TRY NOW
	const by = portrait ? 60 : 90;
	const bw = Math.min(W / K * 0.92, 1100), bh = portrait ? 300 : 270;
	const bu = eBack(span(t, e + 0.7, e + 1.15));
	let press = 0;
	for (const c of CLICKS) press = Math.max(press, 1 - Math.abs(t - c) * 7);
	press = clamp(press, 0, 1);
	if (bu > 0) {
		const pulse = 1 + Math.sin(t * 7) * 0.04 * (1 - press);
		glow(0, by, bw * 0.75, 'rgba(255,220,90,A)', 0.55 + Math.sin(t * 7) * 0.15);
		button(0, by, bw, bh, '', ['#ffe066', '#ffb21a', '#c97a10'], press, { scale: bu * pulse });
		const sh = 14 * (1 - press);
		text('TRY NOW', 0, by - sh + 10, Math.min(250, bw * (portrait ? 0.2 : 0.235)), { scale: bu * pulse, fill: 'white' });
		// shine sweep
		const su = ((t - e) % 1.6) / 1.6;
		ctx.save(); ctx.translate(X(0), Y(by)); ctx.scale(bu * pulse, bu * pulse);
		rr(-bw / 2 * K, (-bh / 2 - 14) * K, bw * K, bh * K, bh * 0.3 * K); ctx.clip();
		ctx.fillStyle = 'rgba(255,255,255,0.35)';
		const sx = lerp(-bw, bw, su) * K;
		ctx.beginPath(); ctx.moveTo(sx, -bh * K); ctx.lineTo(sx + 60 * K, -bh * K); ctx.lineTo(sx - 40 * K, bh * K); ctx.lineTo(sx - 100 * K, bh * K); ctx.fill();
		ctx.restore();
	}
	// click rings + confetti
	for (const c of CLICKS) {
		const u = (t - c) / 0.6;
		if (u > 0 && u < 1) {
			ctx.save(); ctx.strokeStyle = `rgba(255,255,255,${1 - u})`; ctx.lineWidth = 14 * K * (1 - u);
			ctx.beginPath(); ctx.ellipse(X(TIPX()), Y(by + 60), (60 + u * 420) * K, (40 + u * 200) * K, 0, 0, 7); ctx.stroke(); ctx.restore();
		}
		confetti(t, c, TIPX(), by, 60, Math.round(c * 10), 1.1);
	}
	// link + platforms
	const ty = by + bh / 2 + (portrait ? 220 : 110);
	if (CFG.link) text(CFG.link, wide ? -260 : 0, ty, 46, { alpha: span(t, e + 1.0, e + 1.4) });
	text('FREE  •  PHONE & PC', wide ? -260 : 0, ty + 62, 40, { fill: 'gold', alpha: span(t, e + 1.2, e + 1.6) });
	// the cursor flies in and clicks
	const cu = eIO(span(t, e + 1.0, CLICKS[0] - 0.1));
	const cx = lerp(wide ? 1000 : 600, TIPX(), cu) + (t > CLICKS[0] ? Math.sin((t - CLICKS[0]) * 3) * 10 : 0);
	const cy = lerp(botY() + 100, by + 60, cu) + (t > CLICKS[0] ? Math.cos((t - CLICKS[0]) * 3) * 8 : 0);
	arrowCursor(cx, cy, press, sat((t - e - 1.0) * 5));
}

// ---------------------------------------------------------------- sound events
// [time, kind, gain] on the full ad timeline.
function sfxEvents() {
	const ev = [];
	const add = (tt, k, g = 1) => ev.push([tt, k, g]);
	add(0.3, 'sad', 0.8);
	TAPS.forEach((tt, i) => { add(tt, 'hit', 0.9); add(tt + 0.05, 'gem', 0.6); add(tt + 0.7, 'coin', 0.7); });
	add(5.25, 'pop', 0.8); add(PRESS, 'click', 1); add(T.up, 'levelup', 1); add(T.up, 'burst', 0.9);
	for (let h = T.up + 0.6; h < T.mine; h += 0.4) { add(h, 'hit', 0.7); add(h + 0.7, 'coin', 0.6); }
	for (const c of [T.mine, T.worlds, T.rich, T.end]) add(c - 0.05, 'whoosh', 0.9);
	// mine
	for (let h = T.mine + 0.2; h < T.boat; h += 0.48) add(h, 'hit', 0.35);
	add(8.65, 'ding', 0.8); add(9.92, 'ding', 0.8); add(11.62, 'ding', 0.9);
	for (let k = 0; k < 8; k++) { add(8.75 + k * 0.08 + 0.3, 'gem', 0.35); add(10.0 + k * 0.08 + 0.3, 'gem', 0.35); }
	add(8.0, 'motor', 0.5); add(9.5, 'motor', 0.4); add(10.65, 'motor', 0.6);
	add(11.75, 'rattle', 0.9);
	// boat
	add(12.6, 'rattle', 0.5); add(13.0, 'horn', 0.9); add(13.1, 'splash', 0.6); add(15.0, 'splash', 0.6);
	// factory
	for (let k = Math.ceil(T.fac / CRUSH); k * CRUSH < T.over; k++) add(k * CRUSH + CRUSH * 0.12, 'stamp', 0.75);
	for (let k = Math.ceil(T.fac / 1.06); k * 1.06 < T.worlds; k++) add(k * 1.06, 'cash', 0.6);
	add(T.fac + 0.6, 'sizzle', 0.5); add(T.fac + 2.2, 'sizzle', 0.5);
	add(T.over + 0.1, 'riser', 0.8);
	// worlds
	const per = (T.rich - T.worlds) / 4;
	for (let i = 0; i < 4; i++) { const w0 = T.worlds + i * per; if (i) add(w0, 'whoosh', 0.7); add(w0 + 0.5, 'unlock', 0.9); add(w0 + 0.55, 'pop', 0.6); }
	// rich
	add(T.rich + 0.1, 'jackpot', 1);
	for (let k = 0; k < 18; k++) add(T.rich + 0.2 + k * 0.13, 'coin', 0.45);
	// end card
	add(T.end + 0.15, 'boom', 1); add(T.end + 0.75, 'pop', 0.9);
	for (const c of CLICKS) { add(c, 'click', 1); add(c + 0.02, 'pop', 0.6); }
	add(CLICKS[0] + 0.05, 'fanfare', 1);
	return ev;
}
