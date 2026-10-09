# Coralight на CrazyGames: полная инструкция

Проверено по документации CrazyGames 9 октября 2026 года. Ссылки на источники указаны в конце.

## 1. Загрузка (форма «Upload your game»)

1. В блоке **Upload files** нажми **Delete all files**. Zip-архивы форма не принимает.
2. Скачай файл **index.html**: https://gonempxr.github.io/colarlight/crazygames/coralight-crazygames-loader.zip (распакуй) или возьми его из файлов проекта: `crazygames/index.html`.
3. Перетащи **index.html** прямо в зону загрузки. Это единственный файл.
4. **Game name**: `Coralight: Dive Tycoon`. Название должно совпадать с тем, что написано в игре (до 35 символов).
5. **Game engine**: Godot.
6. **Does your game save progress**: «Yes, using the Data Module from the CrazyGames SDK». Это правда: игра сохраняется через их SDK.
7. **Game options**: мобильные поддерживаются, ориентация BOTH, mute через SDK отмечен.
8. Нажми **Save**, затем открой **Preview** и проверь игру. Она должна запуститься за несколько секунд.

Как это работает: index.html весит 2 КБ. При каждом запуске он скачивает актуальную игру с gonempxr.github.io/colarlight/, поэтому всё, что мы выкладываем на сайт, сразу появляется и на CrazyGames.

## 2. Как игра попадает на сайт (Basic Launch)

- После отправки игру проверяет QA CrazyGames. Затем она выходит в **Basic Launch**: её видят реальные игроки, но без денег.
- Тест длится **минимум 7 дней и до 500 запусков**. Если 500 запусков не набирается, он заканчивается через **21 день**.
- Результаты видны в **Developer Dashboard**. Статистика обновляется раз в день, удержание на 1-й день появляется через день.
- Ориентиры, по которым игру берут на **Full Launch** (это не жёсткие пороги):
  - среднее время игры **10+ минут**;
  - возврат на следующий день **10–15%**;
  - **80%+** игроков играют больше минуты; загрузка до 10 секунд.
- Как проверить, что игра доступна: в Dashboard статус сменится на «Basic Launch» или «Live», и там же будет ссылка на страницу игры. Открой её в окне инкогнито и с телефона.

## 3. Реклама

- В **Basic Launch реклама выключена** для всех игр. Это правило площадки, а не наша ошибка.
- В игре уже всё подключено к их SDK: rewarded-реклама «x2 добыча на 30 минут» (только по желанию игрока), сохранения через Data Module, gameplayStart/Stop, mute.
- После перехода на **Full Launch** реклама включится сама, ничего перезагружать не нужно.
- Деньги — доля от рекламы, выплата раз в месяц при сумме от €100. Платёжные данные указываются в профиле разработчика.
- Другую рекламу (AdSense и т. п.) ставить нельзя, разрешена только реклама через их SDK.
- Принудительных реклам между уровнями у нас нет и не будет: это наше правило для детской аудитории.

## 4. Донат (покупки в игре)

- В Basic Launch **покупок нет**.
- Покупки доступны **только избранным играм** после Full Launch, через платёжную систему **Xsolla**. Заявку подают через команду CrazyGames.
- Что делаем: ждём Full Launch, потом пишем им и просим доступ к покупкам. Когда дадут, подключу Xsolla в игре. В игре можно продавать только косметику (скины, наряды): без лутбоксов и без случайных наград за деньги.

## 5. «Детская» ли игра

- CrazyGames — сайт для аудитории **13+**, игра должна соответствовать **PEGI 12**.
- Для игр, сделанных именно для маленьких детей, у них есть отдельный детский сайт, и **монетизация там выключена**.
- Coralight подходит для 13+: мультяшная, без насилия и азартных механик. Это нормально, «безопасная для всех» не значит «только для малышей».
- Чтобы игру не отнесли к детским:
  - не пиши в описании и тегах «for kids», «для детей», «toddlers», «preschool»;
  - в описании делай упор на tycoon / idle / clicker / strategy / управление базой;
  - категория: **Clicker** или **Idle / Tycoon**.
- Окончательно решает команда CrazyGames. Если отнесут к детским, это будет видно в Dashboard или в письме от них.

## 6. Риски

- QA может придраться, что игра загружается с другого сайта. Правила это разрешают, если геймплей начинается не позже 20 секунд. Если откажут, загрузим полный билд (около 33 МБ). Тогда каждое обновление придётся загружать вручную.
- Игра весит больше 20 МБ, поэтому на мобильную главную CrazyGames её, скорее всего, не возьмут. На обычный сайт и в мобильную версию это не влияет.
- Сохранения на CrazyGames отдельные от сохранений на нашем сайте.
- Если сломается основной сайт, сломается и версия на CrazyGames. Обновления сначала проверяем на /beta/.
- Не проверено: работа на самом CrazyGames. Из моей среды их сайт недоступен, поэтому проверь Preview сам.

## Источники

- Требования: Basic и Full Launch, реклама, покупки через Xsolla — https://docs.crazygames.com/requirements/intro/
- Возраст 13+, PEGI 12, детский сайт без монетизации — https://docs.crazygames.com/requirements/gameplay/
- Внешние файлы (до 20 секунд), лимиты размера — https://docs.crazygames.com/requirements/technical/
- Basic Launch: 7 дней / 500 запусков / 21 день, метрики — https://docs.crazygames.com/resources/basic-launch-metrics/

## 7. Обложки и тексты для формы

Обложки (все три обязательны): https://gonempxr.github.io/colarlight/crazygames/coralight-covers.zip
- cover-landscape-1920x1080.png → Landscape 16:9
- cover-portrait-800x1200.png → Portrait 2:3
- cover-square-800x800.png → Square 1:1 (она же «иконка» игры на сайте)

Перерисовать: `xvfb-run -a godot --rendering-driver opengl3 --path game --resolution 1920x1080 -s res://tests/cover_shot.gd -- out.png 0.5 0.06 200 1.2` (portrait: `0.86 0.05 0 1.0`, square: `0.78 0.05 120 1.0`).

**Category:** Clicker. **Tags:** Idle, Tycoon, Clicker, Mining, Management, Casual, 2D, Underwater.

**Description:**
Build your own underwater mining empire! Hire divers and send them to the seabed to dig shells, coral and treasure. The lift carries the ore up, the boat ships it to shore, and your factory turns it into coins. Upgrade every station, hire managers to automate the work and keep earning even while you are away. Evolve your divers, travel to new worlds – a volcano, an acid swamp and even the Moon – win match-3 puzzles for museum artifacts, go fishing and dress up your crew.

**Controls:**
Left click / tap – interact, tap divers to make them work faster. Mouse wheel / drag – scroll the mine. Tabs or swipe – switch between the Mine, Factory and Office.

**Languages:** English, Russian, Spanish, Chinese (Simplified).
