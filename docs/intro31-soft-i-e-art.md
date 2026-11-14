# Пакет Ь, И, Е

Источник: `intro31_soft_i_e_dev_v1`. В игру вошли восемь предметных PNG 2×. Композиции из `review/` не импортированы. Рама и кот совпали по SHA256 с уже лежащими файлами.

| Файл пакета | Путь в репозитории | Экран |
| --- | --- | --- |
| `soft/intro_s1/pic_los.png` | `godot-proto/art/lesson_soft/pic_los.png` | носитель Ь, лось |
| `soft/intro_s2/pic_kon.png` | `godot-proto/art/lesson_soft/pic_kon.png` | конь, три звука |
| `soft/intro_s4/pic_rul.png` | `godot-proto/art/lesson_soft/pic_rul.png` | верная картинка «руль» |
| `r/intro_s4/pic_rama.png` | уже `godot-proto/art/lesson_r/pic_rama.png` | вторая картинка Ь (`from: r`) |
| `i/intro_s1/pic_iva.png` | `godot-proto/art/lesson_i/pic_iva.png` | носитель И, ива |
| `i/intro_s4/pic_kit.png` | `godot-proto/art/lesson_i/pic_kit.png` | верная картинка «кит» |
| `k/intro_s1/pic_kot_sit.png` | уже `godot-proto/art/lesson_k/pic_kot_sit.png` | вторая картинка И (`from: k`) |
| `e/intro_s1/pic_el.png` | `godot-proto/art/lesson_e/pic_el.png` | носитель Е, ель |
| `e/intro_s4/pic_les.png` | `godot-proto/art/lesson_e/pic_les.png` | верная картинка «лес» |
| `e/intro_s4/pic_dom.png` | `godot-proto/art/lesson_e/pic_dom.png` | вторая картинка «дом» |

Реплики не менялись. Озвучки нет. Указатель прежний: `godot-proto/art/common/ui/ui_hand_f1.png` и `godot-proto/art/common/ui/ui_hand_f2.png`.

В текущем коде до этой правки согласная всегда была синей. Теперь в слове согласная зелёная `#3FA34D`, если за ней ь или е/ё/и/ю/я. Ж и Ш остаются синими. Отдельная буква без соседа по-прежнему синяя, красная или тёмная.

У «конь» три звуковые позиции, четвёртой для ь нет. Последний знак не рисуется, пока ребёнок не выберет ь; клетка закрыта непрозрачной шторкой.

Е2: полоски из одной и двух точек появляются только после обоих ушей. Затем «Можно отдохнуть», «Далее» остаётся, возврат к пройденной сцене тоже. Е3: после прослушивания обеих карточек ребёнок сам выбирает «ле»; «ла» дорожку не открывает. Под выбранным «ле» две позиции, дорожка только там.
