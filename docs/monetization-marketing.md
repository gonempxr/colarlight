# Coralight: монетизация и маркетинг

Дата: 09.10.2026. Источники: документация CrazyGames (ссылки внизу).

## Решения Марка (09.10)
- Площадки: сначала **CrazyGames**, затем **itch.io**, потом **Poki / GameDistribution**.
- Реклама: **за награду** (по желанию игрока) + **межуровневая** только в естественных паузах.
- Без покупок, без платной случайности, без давящих таймеров, без ботов под видом людей.
- Игру **не подаём как детскую**: CrazyGames отклоняет игры «для детей» (их аудитория 13+, PEGI 12). Подача: «уютный idle-тайкун для всех».

## Что уже сделано в коде
| Что | Где | Статус |
|---|---|---|
| SDK CrazyGames v3, загрузка/пауза, облачные сохранения, mute от сайта | `web/shell`, `Platform`, `CloudSave` | было раньше |
| Награда: ×2 монеты на 30 мин | `ad_boost.gd` | было раньше |
| Награда: ×2 офлайн-дохода (кнопка рядом с «Забрать», того же размера) | `main.gd` `_open_offline` | ветка `p-money` |
| Награда: вторые «+5 ходов» в пазле (первые бесплатно, раз за уровень) | `puzzle_screen.gd` | ветка `p-money` |
| Межуровневая реклама: после пазла, после рыбалки, при перелёте в мир. Не раньше 4 минут игры, не во время обучения, не чаще раза в ~3 мин (SDK тоже ограничивает) | `Platform.request_midgame` | ветка `p-money` |
| Тесты правил рекламы | `tests/test_ads.gd` | ветка `p-money` |
| Проверка: `?ads=test` показывает пробную рекламу вместо настоящей | `ad_overlay.gd` | работает |

Ветка `p-money` **не влита** в `worlds`, пока другая сессия выкладывает игру на CrazyGames. Потом влить и перезалить сборку.

## CrazyGames: как проходит запуск
1. **Basic Launch.** Реклама выключена, денег нет. Минимум 7 дней и 500 запусков (иначе завершается через 21 день). CrazyGames смотрит три цифры:
   - **конверсия**: доля игроков, которые играют ≥ 1 минуты. Хорошо: 80%+ (загрузка < 10 с, сборка < 20 МБ);
   - **среднее время игры**: хорошо 10+ минут;
   - **возврат на следующий день (D1)**: хорошо 10–15%.
2. **Full Launch** (по приглашению, если цифры хорошие): включается реклама и доход. Выплаты от 100 €, раз в месяц. Доля дохода не публикуется. Эксклюзив не нужен.

## Что нужно до Full Launch (обязательные требования)
| # | Требование | Сейчас у нас | Что сделать |
|---|---|---|---|
| 1 | **Сразу в игру** (land directly in gameplay) | Титульный экран и ввод имени | На CrazyGames пропускать титул; имя брать из аккаунта CrazyGames |
| 2 | Имя и аватар из аккаунта CrazyGames, авто-вход | Свои профили игроков | Подключить User module SDK; на CrazyGames один профиль = их аккаунт |
| 3 | Прогресс привязан к аккаунту CrazyGames | Data module уже сохраняет | Проверить на их сайте при входе с двух устройств |
| 4 | Реклама только через SDK, по правилам | Готово (ветка `p-money`) | Влить, проверить на их QA-инструменте |
| 5 | Работает с AdBlock, без наказаний | Кнопки рекламы скрываются, если рекламы нет | Проверить с включённым блокировщиком |
| 6 | Начальная загрузка ≤ 50 МБ (мобильная главная ≤ 20 МБ) | Движок 30 МБ (≈7,7 МБ сжатый) + данные 2,6 МБ | Узнать, как они считают; если по несжатому — облегчённая сборка движка |
| 7 | PEGI 12, английский язык | Да | — |
| 8 | Обложки: 1920×1080, 800×1200, 800×800, только название, без рамок и надписей | Нет | Нарисовать из игровой графики + логотип |
| 9 | Видео-превью 15–20 с, без звука, 1080p горизонтальное **и** вертикальное 2:3, первый кадр = обложка, без курсора | Нет | Записать из игры (есть запись кадров `tests/motion_rec.gd`) |

## Как поднять цифры Basic Launch (это и есть главный маркетинг на портале)
- **Первая минута:** убрать всё между загрузкой и игрой; обучение сразу на первом тапе; первое улучшение и первый менеджер — за первые 1–2 минуты.
- **Время игры:** ближайшая цель всегда видна (лампочка-подсказка, задания); награда каждые ~30–60 с.
- **Возврат:** офлайн-доход «пока тебя не было» + ×2 за рекламу, подарок дня, серия входов — уже есть. Можно добавить уведомление на CrazyGames «твои дайверы накопили…» (если SDK позволит).
- **Загрузка:** сейчас экран загрузки + ленивые файлы; цель < 10 с на мобильном интернете.
- **Обложка и видео** решают, кликнут ли вообще: яркая сцена шахты с дайверами, понятная с первого взгляда.

## Тексты для страницы (черновик, английский обязателен)
**Title:** Coralight: Dive Tycoon

**Short description:** Build an underwater mining empire! Send divers to the depths, upgrade your lift, boat and factory, hire managers and travel from the ocean to volcanoes, acid swamps and the Moon.

**Description:**
Dive into a cozy idle tycoon! Your divers mine shells, pearls and gems at the bottom of the sea. A lift carries the ore up, a boat takes it to shore and your factory turns it into coins. Upgrade every part of the chain, hire managers to automate it, and watch your little crew work even while you're away.

- 4 worlds: Ocean, Volcano, Acid Swamp and the Moon — each with its own workers and sites
- Match-3 puzzles that restore ancient artifacts for your museum
- Fishing, outfits, pets and office decor
- Daily gifts, quests and a friendly league of sea rivals (game characters)
- Plays great on phone and PC, in English, Spanish, Russian and Chinese

**Controls:** Tap or click to help your workers and buy upgrades. Swipe or use the tabs to switch rooms.

**Теги (выбрать из их списка):** idle, clicker, tycoon, management, casual, underwater, mining, match-3.

## Другие площадки
- **itch.io** (страница `corelight` уже есть): та же сборка без рекламы (провайдер `none`), загрузка zip. Денег от рекламы нет, но это витрина и место для отзывов.
- **Poki:** только по приглашению/заявке, высокая планка качества и свой SDK. Подаём после того, как будут хорошие цифры на CrazyGames.
- **GameDistribution:** свой SDK и рекламная сеть, игра попадает на много сайтов-партнёров. Отдельный «провайдер» в `Platform` (как `crazygames`).
- Новые SDK добавляются как новый провайдер в `Platform` и мост в `web/shell` — остальной код не меняется.

## Продвижение вне порталов (бесплатное)
- Короткие вертикальные ролики 15–30 с (TikTok, YouTube Shorts): «из одного дайвера — в империю», перелёт между мирами, лава-мир.
- Reddit: r/incremental_games (любят честные idle-игры без давления — это наш плюс), r/WebGames, r/godot (как сделано: вся графика рисуется кодом).
- Discord-сообщества idle-игр, страница разработчика на itch.
- Всё это — после Full Launch или параллельно Basic Launch, чтобы набрать 500 запусков.

## Риски
- **Подача «для детей»** → отказ CrazyGames. Решение: подача для всех, правила честности оставляем.
- **Размер для мобильной главной** (≤ 20 МБ): может не пройти, если считают несжатый размер.
- **Экран имени** нарушает «сразу в игру» → нужно сделать до Full Launch.
- Межуровневая реклама может немного снизить время игры: следим за цифрами, при необходимости реже.

## Источники
- [CrazyGames: требования к рекламе](https://docs.crazygames.com/requirements/ads/)
- [CrazyGames: технические требования](https://docs.crazygames.com/requirements/technical)
- [CrazyGames: общий чек-лист Basic/Full](https://docs.crazygames.com/requirements/intro/)
- [CrazyGames: обложки и видео](https://docs.crazygames.com/requirements/game-covers)
- [CrazyGames: метрики Basic Launch](https://docs.crazygames.com/resources/basic-launch-metrics/)
- [CrazyGames: гид по монетизации](https://docs.crazygames.com/resources/ad-monetization-guide/)
- [CrazyGames: FAQ](https://docs.crazygames.com/faq/)
