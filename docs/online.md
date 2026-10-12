# Online: leaderboard, promo codes, founders, invites

Branch `p-online` (2026-10-11). Works on our site (gonempxr.github.io/colarlight/
and /beta/) and on CrazyGames. Backend: the existing Firebase project
**coral-light** (free Spark plan, no Cloud Functions), Firebase **Anonymous
Auth** + **Firestore**. All protection is in the Firestore security rules below.

## What the player sees
- **Leaderboard of real players** — round globe button under the lightbulb
  (also in Profile, Settings and at the bottom of the Rivals League). Tabs
  "This week" (coins earned since Monday 00:00 UTC) and "All time" (total
  coins earned). Top 50, own row highlighted, own place shown below if outside
  the top 50. Green "Real players" tag; the Rivals League stays the board of
  clearly marked *computer* characters.
- **Promo code** — Settings → "Promo code". Works offline too (checked in the
  game), each code once per player (remembered in `user://online.json`, which
  the cloud save carries).
- **Founder #N** — the first 100 players who open the game online get +100
  pearls, the Founder Cap and the thank-you dialog.
- **Invite friends** — Settings / Profile / leaderboard → "Invite friends".
  On our site the link is `https://gonempxr.github.io/colarlight/?ref=CODE`
  (shared with `navigator.share` or copied); on CrazyGames the link comes from
  `CrazyGames.SDK.game.inviteLink({ref: CODE})` and is read back with
  `getInviteParam('ref')`. A new player (fresh save, < 20 000 coins earned,
  never referred, not their own code) gets +30 pearls; the inviter gets +30
  pearls per new friend (max 20) the next time they open the game, and the
  Founder Cap after the first friend.
- **Founder Cap** (`hat_founder`, gold captain's cap with a pearl) — never sold.
  Founders, the THANKYOU code and inviting ≥ 1 friend. In the wardrobe it shows
  locked with the hint how to get it.
- No network / blocked / ad blocker: buttons open "Online is not available right
  now" with a retry button; the game never waits for the network.

## Promo codes
| Code | Gives | id |
|---|---|---|
| `CORALIGHT` | +50 pearls | p1 |
| `DIVE2026` | +30 pearls and x2 coins for 1 hour (the ad boost timer, `GameState.add_boost`) | p2 |
| `THANKYOU` | +25 pearls and the Founder Cap | p3 |

Codes are typed in any case with spaces around; the game trims and upper-cases
them and compares the **SHA-256** with `OnlineRules.PROMOS`
(game/scripts/data/online_rules.gd). Only hashes are in the code.

**Add a new code:**
1. `python3 -c "import hashlib; print(hashlib.sha256('NEWCODE'.strip().upper().encode()).hexdigest())"`
2. Add a line to `PROMOS`: `"<hash>": {"id": "p4", "pearls": 40},`
   (`"boost": 3600` = seconds of x2 coins, `"item": "hat_founder"` = an item).
   Every code needs a **new id** — the id is what is remembered as "used".
3. Add the code to the table above, run `tools/run_tests.sh`, build, publish.

Note: a promo code is a client-side check; a player who reads the game files
can't find the codes (only hashes), but a code shared on the internet works
for everyone once each. Never make codes that give a lot.

## Firestore data
| Path | Fields | Who writes |
|---|---|---|
| `lb_all/{uid}` | name, score, a (avatar JSON), t | the player, own doc |
| `weeks/{weekId}/scores/{uid}` | name, score, a, t | the player, own doc, current week only |
| `meta/founders` | count | founder transaction |
| `founders/{uid}` | n, t | founder transaction (once) |
| `invites/{code}/joined/{uid}` | t | the new player (once) |
| `joins/{uid}` | code, t | the new player (once, same batch) |
| `saves/{uid}` | data | Google cloud save (existing) |

- weekId = weeks since Monday 1970-01-05 00:00 UTC (`OnlineRules.week_id`).
- CODE = the first 8 letters of the Firebase uid. The game remembers friends
  already paid per code.
- Scores are sent at most once a minute (every 5 minutes, on a new world, when
  the page is hidden, when the board opens). Free plan: 20 000 writes and
  50 000 reads a day for everyone together — a board view costs up to ~51 reads
  (cached for a minute in the game).
- Index: none needed (single-field `orderBy('score','desc').limit(50)` and a
  `count()` for the own place use the automatic single-field indexes).

## Firestore rules (paste all of it — it keeps the cloud-save rule)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function isMe(uid) { return signedIn() && request.auth.uid == uid; }

    // Google cloud save (unchanged).
    match /saves/{uid} {
      allow read, write: if isMe(uid);
    }

    // A score row: name 2-24 characters (the game cuts names to 16), the
    // avatar JSON, a number that never goes down, at most every 30 s.
    function goodScore() {
      let d = request.resource.data;
      return d.keys().hasOnly(['name', 'score', 'a', 't', 'p'])
        && d.keys().hasAll(['name', 'score', 'a', 't'])
        && (!('p' in d) || (d.p is string && d.p.size() <= 200))
        && d.name is string && d.name.size() >= 2 && d.name.size() <= 24
        && d.a is string && d.a.size() <= 300
        && d.score is number && d.score >= 0 && d.score <= 1000000000000000000000000000000000000000000000000000000000000.0
        && d.t == request.time
        && ownName(d.name)
        && (resource == null
            || (d.score >= resource.data.score
                && request.time > resource.data.t + duration.value(30, 's')));
    }

    // Names are unique: names/{key} (lower case, no spaces) belongs to
    // one player. A score row carries either its owner's name or "Diver1234".
    function nameKey(n) { return n.lower().replace(' ', ''); }
    function ownName(n) {
      return n.matches('^Diver[0-9]{4}$')
        || get(/databases/$(database)/documents/names/$(nameKey(n))).data.uid == request.auth.uid;
    }
    function goodName(key) {
      let d = request.resource.data;
      return d.keys().hasOnly(['uid', 'name', 't'])
        && d.uid == request.auth.uid
        && d.name is string && d.name.size() >= 2 && d.name.size() <= 16
        && nameKey(d.name) == key
        && d.t == request.time;
    }
    match /names/{key} {
      allow read: if signedIn();
      allow create: if signedIn() && goodName(key);
      allow update: if signedIn() && resource.data.uid == request.auth.uid && goodName(key);
      allow delete: if signedIn() && resource.data.uid == request.auth.uid;
    }

    match /lb_all/{uid} {
      allow read: if signedIn();
      allow create, update: if isMe(uid) && goodScore();
    }

    // Weeks start on Monday 00:00 UTC; only the current week can be written.
    match /weeks/{weekId}/scores/{uid} {
      allow read: if signedIn();
      allow create, update: if isMe(uid) && goodScore()
        && weekId.matches('^[0-9]{1,6}$')
        && request.time.toMillis() >= (int(weekId) * 7 + 4) * 86400000
        && request.time.toMillis() < (int(weekId) * 7 + 11) * 86400000;
    }

    // The weekly puzzle board (stars won in the puzzle), like the weeks.
    match /puzzleweeks/{weekId}/scores/{uid} {
      allow read: if signedIn();
      allow create, update: if isMe(uid) && goodScore()
        && weekId.matches('^[0-9]{1,6}$')
        && request.time.toMillis() >= (int(weekId) * 7 + 4) * 86400000
        && request.time.toMillis() < (int(weekId) * 7 + 11) * 86400000;
    }

    // Seasons: one calendar month (UTC); only the current month is written.
    match /months/{monthId}/scores/{uid} {
      allow read: if signedIn();
      allow create, update: if isMe(uid) && goodScore()
        && monthId.matches('^[0-9]{6}$')
        && int(monthId) == request.time.year() * 100 + request.time.month();
    }

    // Clubs: clubs/{id} {name, owner, n, t} with up to 30 members
    // clubs/{id}/m/{uid} {name, s (this week's coins), w (week), t}. Joining
    // and leaving change n by one in the same transaction as the member row.
    function clubPath(id) { return /databases/$(database)/documents/clubs/$(id); }
    function memberPath(id) { return /databases/$(database)/documents/clubs/$(id)/m/$(request.auth.uid); }
    function goodMember() {
      let d = request.resource.data;
      return d.keys().hasOnly(['name', 's', 'w', 't'])
        && d.keys().hasAll(['name', 's', 'w', 't'])
        && d.name is string && d.name.size() >= 2 && d.name.size() <= 24
        && ownName(d.name)
        && d.s is number && d.s >= 0 && d.s <= 1000000000000000000000000000000000000000000000000000000000000.0
        && d.w is int && d.w >= 0
        && d.t == request.time;
    }
    match /clubs/{id} {
      allow read: if signedIn();
      allow create: if signedIn() && id.matches('^[A-Za-z0-9]{8}$')
        && request.resource.data.keys().hasOnly(['name', 'owner', 'n', 't'])
        && request.resource.data.name is string
        && request.resource.data.name.size() >= 3 && request.resource.data.name.size() <= 20
        && request.resource.data.owner == request.auth.uid
        && request.resource.data.n == 1
        && request.resource.data.t == request.time
        && existsAfter(memberPath(id));
      allow update: if signedIn()
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['n'])
        && ((request.resource.data.n == resource.data.n + 1 && request.resource.data.n <= 30
              && !exists(memberPath(id)) && existsAfter(memberPath(id)))
          || (request.resource.data.n == resource.data.n - 1 && request.resource.data.n >= 0
              && exists(memberPath(id)) && !existsAfter(memberPath(id))));
      match /m/{uid} {
        allow read: if signedIn();
        allow create: if isMe(uid) && goodMember()
          && ((!exists(clubPath(id)) && getAfter(clubPath(id)).data.owner == uid)
            || (exists(clubPath(id)) && getAfter(clubPath(id)).data.n == get(clubPath(id)).data.n + 1));
        allow update: if isMe(uid) && goodMember()
          && request.time > resource.data.t + duration.value(30, 's');
        allow delete: if isMe(uid)
          && getAfter(clubPath(id)).data.n == get(clubPath(id)).data.n - 1;
      }
    }
    // The weekly club board: written by a member (the sum of the members'
    // coins this week), only for the current week.
    match /clubweeks/{weekId}/clubs/{id} {
      allow read: if signedIn();
      allow create, update: if signedIn()
        && existsAfter(memberPath(id))
        && request.resource.data.keys().hasOnly(['name', 's', 'n', 't'])
        && request.resource.data.name == getAfter(clubPath(id)).data.name
        && request.resource.data.n == getAfter(clubPath(id)).data.n
        && request.resource.data.s is number && request.resource.data.s >= 0
        && request.resource.data.s <= 1000000000000000000000000000000000000000000000000000000000000.0
        && request.resource.data.t == request.time
        && weekId.matches('^[0-9]{1,6}$')
        && request.time.toMillis() >= (int(weekId) * 7 + 4) * 86400000
        && request.time.toMillis() < (int(weekId) * 7 + 11) * 86400000
        && (resource == null || request.time > resource.data.t + duration.value(30, 's'));
    }

    // The first 100 players: one transaction writes founders/{uid} {n} and
    // raises meta/founders.count by exactly one; n == the new count <= 100.
    match /meta/founders {
      allow read: if signedIn();
      allow create: if signedIn()
        && request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count == 1
        && !exists(/databases/$(database)/documents/founders/$(request.auth.uid))
        && getAfter(/databases/$(database)/documents/founders/$(request.auth.uid)).data.n == 1;
      allow update: if signedIn()
        && request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count == resource.data.count + 1
        && request.resource.data.count <= 100
        && !exists(/databases/$(database)/documents/founders/$(request.auth.uid))
        && getAfter(/databases/$(database)/documents/founders/$(request.auth.uid)).data.n == request.resource.data.count;
    }
    match /founders/{uid} {
      allow read: if signedIn();
      allow create: if isMe(uid)
        && request.resource.data.keys().hasOnly(['n', 't'])
        && request.resource.data.n is int
        && request.resource.data.n >= 1 && request.resource.data.n <= 100
        && request.resource.data.t == request.time
        && getAfter(/databases/$(database)/documents/meta/founders).data.count == request.resource.data.n
        && ((!exists(/databases/$(database)/documents/meta/founders) && request.resource.data.n == 1)
            || (exists(/databases/$(database)/documents/meta/founders)
                && get(/databases/$(database)/documents/meta/founders).data.count + 1 == request.resource.data.n));
    }

    // Invites: a new player writes both records once (one batch); never
    // their own code. Only the inviter (uid starting with the code) reads.
    match /invites/{code}/joined/{uid} {
      allow read: if signedIn() && code.size() == 8 && request.auth.uid.matches(code + '.*');
      allow create: if isMe(uid)
        && code.matches('^[A-Za-z0-9]{6,12}$')
        && !request.auth.uid.matches(code + '.*')
        && request.resource.data.keys().hasOnly(['t'])
        && request.resource.data.t == request.time
        && !exists(/databases/$(database)/documents/joins/$(uid))
        && getAfter(/databases/$(database)/documents/joins/$(uid)).data.code == code;
    }
    match /joins/{uid} {
      allow read: if isMe(uid);
      allow create: if isMe(uid)
        && request.resource.data.keys().hasOnly(['code', 't'])
        && request.resource.data.code is string
        && request.resource.data.t == request.time
        && existsAfter(/databases/$(database)/documents/invites/$(request.resource.data.code)/joined/$(uid));
    }
  }
}
```
No `update` / `delete` is allowed anywhere except the score rows (update only,
going up), names (owner), clubs (member count by one) and club members
(own row). Everything else is denied by default.

## Инструкция для Марка (по шагам)

Это нужно сделать **один раз**, до того как бета с онлайном пойдёт к игрокам.
Без этого игра работает, но кнопки онлайна пишут «Онлайн сейчас недоступен».

**1. Включить анонимный вход**
1. Откройте https://console.firebase.google.com и войдите тем же Google, где
   создан проект.
2. Нажмите на проект **coral-light**.
3. Слева: **Build → Authentication** (или «Создание → Authentication»).
4. Вкладка **Sign-in method** («Способ входа»).
5. Нажмите **Add new provider** («Добавить поставщика») → **Anonymous**
   («Анонимно») → переключатель **Enable** → **Save**.
   Google-вход, который уже включён, не трогайте.

**2. Проверить домены**
1. Там же, в Authentication → вкладка **Settings** → **Authorized domains**.
2. Должен быть `gonempxr.github.io` (он уже есть для входа через Google).
   Для анонимного входа на CrazyGames ничего добавлять не нужно (этот список
   нужен только для окон входа Google). Если когда-нибудь на CrazyGames онлайн
   не заработает, добавьте туда `crazygames.com` и `game-files.crazygames.com`.

**3. Вставить правила базы**
1. Слева: **Build → Firestore Database**.
2. Вкладка **Rules** («Правила»).
3. Выделите весь старый текст (Ctrl+A) и удалите.
4. Скопируйте весь блок из раздела «Firestore rules» выше (от
   `rules_version` до последней `}`) и вставьте.
5. Нажмите **Publish** («Опубликовать»). Если внизу красная ошибка — пришлите
   мне её текст или скриншот, ничего не публикуйте.

**4. Индексы** — создавать не нужно.

**5. Проверка**
1. Откройте бету: https://gonempxr.github.io/colarlight/beta/
2. Подождите 10 секунд, нажмите круглую кнопку с глобусом и короной под
   лампочкой → должна открыться «Таблица лидеров» (сначала там будете только вы).
3. Если вы среди первых 100 — появится окно «Спасибо…» и «Основатель #N».
4. Настройки → «Промокод» → `CORALIGHT` → +50 жемчужин.

**Важно:** коды из таблицы выше никому не показывайте заранее, кроме тех, кому
хотите их дать. Новый код добавляю я (или любой следующий Claude) по разделу
«Add a new code».

## Testing without Firebase
- `?online=test` — pretend backend in localStorage (same checks as the rules):
  12 "Test diver" rows, founders start at 7. `&as=<uid>` plays as another
  player, `&ref=<code>` opens from an invite, `&fail=1` = network blocked.
  `?online=off` turns online off.
- Tests: `game/tests/test_online.gd` (codes, names, weeks, invites, founder,
  save), pretend backend `game/tests/online_fake.gd`.
- Screenshots: overlays `board[:all][:off]`, `promo[:bad]`, `invite[:off]`,
  `thanks:<founder|promo|join|inviter>`, `onlinebtn`, `wardrobe:hat:end`.

## Code map
- `game/scripts/autoload/online.gd` — Online autoload: state, requests with
  timeouts, scores, founders, invites, promo, rewards, `user://online.json`.
- `game/scripts/data/online_rules.gd` — OnlineRules: promo hashes, name filter,
  week id, invite eligibility.
- `game/scripts/ui/online_view.gd` (dialogs), `online_hook.gd` (shows the
  thank-you at a quiet moment), `online_button.gd` (globe button),
  `founder_art.gd` (Founder Cap, medal, podium, letter).
- `game/i18n/online.csv` — strings (RU/EN/ES/ZH).
- `tools/web_shell/shell.src.html` — `window.coralightOnline` bridge (regenerate
  `game/web/shell.html` with `python3 tools/make_web_shell.py`). Firebase is
  loaded only when the game calls `coralightOnline.begin()`, 4 s after start.

## Risks / limits
- Anonymous accounts live in the browser: clearing site data = a new player
  (new code, maybe a new founder number if places are left). Signing in with
  Google on our site links the anonymous account to Google (keeps the id).
- Scores come from the player's browser: the rules stop scores going down,
  fast repeats and absurd values, but a determined cheater can still send a
  big number. If that happens, delete the row in the Firebase console.
- Invites can be farmed with private windows (max 20 friends × 30 pearls).
- CrazyGames forbids external logins; anonymous Firebase has no UI, but if
  CrazyGames objects, `?online=off`-style switch is in the shell
  (`onCrazy` check) — turn it off there.
