# Paint by Numbers для Roblox

В репозитории лежит исходный шаблон интерфейса `Essential UI Pack - Swarve Studios.rbxl` и два исходных файла:

- `build_paint_by_numbers.lua` — **единый скрипт для Command Bar**. Он разворачивает игру в уже открытом place, создаёт RemoteEvents/RemoteFunctions, ModuleScripts, серверный код, клиентский код и UI.
- `tools/image_to_luau.py` — конвертер PNG/JPG в ModuleScript картины.

> Скрипты нужно запускать/копировать в Roblox Studio. Git-репозиторий не является Roblox place-файлом, который можно запустить из Python.

## 1. Быстрый запуск

1. Откройте Roblox Studio и выберите **File → Open from File…**.
2. Откройте `Essential UI Pack - Swarve Studios.rbxl`.
3. В Studio включите **View → Command Bar**.
4. Откройте `build_paint_by_numbers.lua` в любом редакторе, скопируйте **весь файл целиком** и вставьте в Command Bar. Нажмите Enter и дождитесь сообщений `PaintByNumbers installed` в Output.
5. Нажмите **Play**. На главном экране нажмите **DRAW**, выберите `Sunset Island` или `Tiny Garden`, выберите номер цвета и закрашивайте пиксели.
6. Для сохранения результата используйте **File → Save to File…** и сохраните новый `.rbxl`.

Сборщик можно запускать повторно после изменения кода. Он обновляет сгенерированные scripts/UI и не удаляет вручную импортированные ModuleScripts из `ReplicatedStorage/PaintByNumbers/ArtLibrary`. При установке он также отключает несколько демо-скриптов исходного UI Pack (`ReceiptHandler`, старый `leaderstats`, `PurchaseHandler`, `RebirthHandler` и их зависимые GUI-скрипты), потому что они относятся к другой игре и ждут `Coins`, `Strength`, `Spins` и другие неиспользуемые значения.

## 2. Что создаёт сборщик

Основная иерархия после запуска:

```text
ReplicatedStorage
└── PaintByNumbers
    ├── Shared
    │   ├── Config             (ModuleScript)
    │   └── PixelCodec          (ModuleScript)
    ├── Remotes
    │   ├── GetProfile          (RemoteFunction)
    │   ├── StartArt            (RemoteFunction)
    │   ├── PaintPixel          (RemoteFunction)
    │   ├── UseAbility          (RemoteFunction)
    │   ├── UpgradeAbility      (RemoteFunction)
    │   ├── AdminAction         (RemoteFunction)
    │   ├── ProfileChanged      (RemoteEvent)
    │   └── Toast               (RemoteEvent)
    └── ArtLibrary              (Folder, сюда добавляются картины)
        ├── starter_sunset      (ModuleScript)
        └── starter_garden      (ModuleScript)

ServerScriptService
└── PaintByNumbersServer         (Script)

StarterPlayer
└── StarterPlayerScripts
    └── PaintByNumbersClient     (LocalScript)

StarterGui
└── PaintByNumbersGui            (ScreenGui, UI на базе Essential UI Pack)
```

Сборщик сначала ищет в исходном Essential UI Pack подходящие `TextButton`, `Frame`, `TextLabel` и `ImageLabel` по именам (`button`, `panel`, `card`, `modal`, `label`, `preview` и т. п.). Он клонирует или копирует визуальные свойства, `UICorner`, `UIStroke` и `UIGradient`. Если конкретный объект в версии пака называется иначе, используется стилизованный fallback с той же иерархией и цветовой темой. Это позволяет не привязывать игровой код к неизвестным именам внутренних объектов шаблона.

## 3. Импорт своей картины

### Установка Pillow

```bash
python -m pip install Pillow
```

### Конвертация

Например, для Medium 64×64 и 12 цветов.

Linux/macOS или Git Bash:

```bash
python tools/image_to_luau.py \
  ./art/sunset.png \
  ./art_luau/Sunset.lua \
  --size 64 \
  --colors 12 \
  --id sunset \
  --name "Sunset" \
  --reward 150
```

Windows PowerShell — проще выполнить команду одной строкой:

```powershell
py -3 .\tools\image_to_luau.py .\art\sunset.png .\art_luau\Sunset.lua --size 64 --colors 12 --id sunset --name "Sunset" --reward 150
```

Если `image_to_luau.py` и `first.jpg` находятся прямо в текущей папке, а не в клонированном репозитории, путь будет таким:

```powershell
py -3 .\image_to_luau.py .\first.jpg .\test.lua --size 64 --colors 12 --id test --name "test" --reward 150
```

В PowerShell символ `\` не является переносом строки — для переноса используется обратный апостроф `` ` ``. Ошибка `can't open file ...\tools\image_to_luau.py` означает, что в текущей папке нет подпапки `tools`; используйте `.\image_to_luau.py` или перейдите в корень репозитория командой `cd`.

Допустимые размеры:

| `--size` | Difficulty | Примерная награда по умолчанию |
|---:|---|---:|
| 32 | Easy | 75 Gems |
| 64 | Medium | 150 Gems |
| 128 | Hard | 300 Gems |
| 256 | Extreme / Unreal | 600 Gems |

`--colors` принимает значения от 4 до 16. Прозрачные места исходника композитятся на фон; фон можно задать, например, `--background FFFFFF`.

Сгенерированный файл выглядит так:

```lua
return {
    Id = "sunset",
    Name = "Sunset",
    Difficulty = "Medium",
    Width = 64,
    Height = 64,
    Reward = 150,
    PaletteSize = 12,
    PixelEncoding = "hex-nibble-v1",
    Palette = {
        [1] = Color3.fromRGB(24, 30, 60),
        -- ...
    },
    Pixels = [[12A...]], -- ровно Width * Height символов, ID 1..16
}
```

Каждый пиксель — один hex-символ (`1`…`9`, `A`…`F`), поэтому даже 256×256 занимает около 64 KiB данных. В `Pixels` нельзя вручную добавлять переносы строк: это сериализованная последовательность, а не визуальная таблица.

### Вставка в place

1. В Explorer найдите `ReplicatedStorage → PaintByNumbers → ArtLibrary`.
2. Создайте внутри `ArtLibrary` объект **ModuleScript**.
3. Назовите его, например, `Sunset` и вставьте в него содержимое `art_luau/Sunset.lua`.
4. Сохраните place и снова нажмите **Play**. Сервер автоматически перечитает `ArtLibrary`, а клиент покажет картину в галерее.
5. Поле `Id` должно быть уникальным и не должно меняться после релиза: оно используется как ключ сохранения прогресса.

При добавлении/удалении ModuleScript во время Play сервер перечитывает библиотеку. В production лучше добавлять картины в edit mode, затем сохранить и перепубликовать place.

## 4. Производительность холста

- Для любого размера используется один `ImageLabel` и `EditableImage`, а не `Frame` на каждый пиксель.
- Буфер RGBA записывается через `EditableImage:WritePixelsBuffer`; незакрашенные клетки остаются нейтральными/бесцветными, а закрашенная клетка получает цвет из палитры.
- Номера поверх сетки создаются виртуализированно только для видимой области. Для обычного клика обновляется один пиксель EditableImage, а не перерисовывается весь 256×256 буфер.
- `Mouse Wheel` и touch pinch меняют zoom. Drag двигает холст. Удержание/перетаскивание при купленном Auto-Brush вызывает обычную серверную валидацию каждой новой ячейки.
- Если конкретная Studio/runtime-версия не даёт создать `EditableImage` или `WritePixelsBuffer`, включается совместимый renderer: он создаёт только видимые **чанки**, примерно до 1 100 GUI-объектов, а не 65 536 пиксельных Frames. Координаты клика всё равно вычисляются по полной сетке.
- `PixelCodec` декодирует ID за O(1), а сервер проверяет координаты и ожидаемый цвет. Клиент не является источником истины.

Если Studio выводит ошибку о правах EditableImage, включите в **Game Settings → Security** доступ к Mesh/Image APIs (название пункта зависит от версии Studio) и повторите тест. Совместимый chunk fallback всё равно позволяет проверить логику.

## 5. Сохранения и DataStore

Сервер сохраняет:

- битовую строку `Bits` для каждого `Art.Id` и количество закрашенных ячеек;
- Gems;
- уровни `Splash`, `ColorBomb`, `AutoBrush`.

Сохранение выполняется раз в 60 секунд, при `PlayerRemoving` и через `BindToClose`. Каждый клик, Splash и Color Bomb сначала валидируются сервером, после чего прогресс записывается в текущий профиль. При следующем входе `StartArt` возвращает тот же bitset.

Для настоящего опубликованного теста:

1. Опубликуйте place хотя бы один раз.
2. В **Game Settings → Security** включите **Enable Studio Access to API Services**.
3. Тестируйте через **Play** или Test → Start Server/Players. Если API Services выключен, игра всё равно запускается с профилем в памяти, но после остановки Studio данные не гарантируются.
4. Не переименовывайте `DataStoreName` в `Shared/Config`, если хотите сохранить текущие профили.

## 6. Экономика и способности

В `Shared/Config` находятся стартовые 250 Gems и цены трёх уровней:

- **Splash** — уровень 1/2/3 красит правильные клетки в квадрате 3×3/5×5/7×7; cooldown уменьшается с 5 до 1.5 секунд.
- **Color Bomb** — после покупки заполняет все оставшиеся клетки выбранного номера; за применение списывается 15 Gems.
- **Auto-Brush** — открывает непрерывное закрашивание при drag/удержании.

Кнопка **ABILITIES SHOP** использует отдельный модальный экран в стиле пака. Все покупки повторно проверяются сервером.

## 7. Панель разработчика

Панель создаётся клиентом только если `Player.Name == "RabanFix"`; сервер дополнительно проверяет это имя на каждом `AdminAction`. Для остальных игроков Developer UI не создаётся и не загружается как экран.

Доступны:

- **Instant Complete** — заполняет текущую картину и открывает Victory Modal с выдачей награды;
- **+10,000 Gems**;
- **Max Upgrades**;
- **Reset Art Progress** — сбрасывает открытую картину.

Это намеренная проверка по `Player.Name`, а не по `DisplayName` и не по клиентскому флагу.

## 8. Перед релизом

- Замените starter arts своими ModuleScripts и проверьте уникальные `Id`.
- Оставьте серверную проверку `PaintPixel`/`UseAbility` включённой; не переносите выдачу Gems в LocalScript.
- Протестируйте 32, 64, 128 и 256 в отдельном опубликованном place на ПК и мобильном устройстве.
- Проверьте DataStore на частично заполненной картине, повторный вход, выход во время автосохранения и `BindToClose`.
- При изменении формата сохранения увеличьте `Config.Version` и добавьте миграцию в `normalizeProfile`.
