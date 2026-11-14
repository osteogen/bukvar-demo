# Пакет Д, Б, Г

Источник: `intro31_d_b_g_dev_v1`. В игру вошли четыре новых предметных PNG 2×. Композиции из `review/` не импортированы. Дом, зонт и кот совпали по SHA256 с уже лежащими файлами.

| Файл пакета | Путь в репозитории | Экран |
| --- | --- | --- |
| `e/intro_s4/pic_dom.png` | уже `godot-proto/art/lesson_e/pic_dom.png` | носитель Д и верная картинка «дом» (`from: e`) |
| `z/intro_s1/pic_zont.png` | уже `godot-proto/art/lesson_z/pic_zont.png` | вторая картинка Д (`from: z`) |
| `b/intro_s1/pic_busy.png` | `godot-proto/art/lesson_b/pic_busy.png` | носитель Б, бусы; вторая картинка Г |
| `b/intro_s4/pic_byk.png` | `godot-proto/art/lesson_b/pic_byk.png` | верная картинка «бык» |
| `k/intro_s1/pic_kot_sit.png` | уже `godot-proto/art/lesson_k/pic_kot_sit.png` | вторая картинка Б (`from: k`) |
| `g/intro_s1/pic_gus.png` | `godot-proto/art/lesson_g/pic_gus.png` | носитель Г, один гусь |
| `g/intro_s4/pic_gusi.png` | `godot-proto/art/lesson_g/pic_gusi.png` | верная картинка «гу́си», несколько гусей |

Сцена 2 — только ухо и две позиции, без слова и без предмета. Сцена 3 — «да», «ба» или «гу». Сцена 4 Г использует `pic_gusi`, не одиночный `pic_gus`. Реплики не менялись. Озвучки нет.

В «гу́си» ударение сидит на красной «у́». «г» перед «у» синий, «с» перед «и» зелёный. Это уже делает текущий `_ink`: мягкий цвет только перед ь или е/ё/и/ю/я, Ж и Ш остаются синими. Отдельной правки для этой группы не потребовалось.

На размере носителя нить бус видна. На карточке три гуся различимы. Бык с рогами. Узнаваемость детьми не проверялась.

Указатель прежний: `godot-proto/art/common/ui/ui_hand_f1.png` и `godot-proto/art/common/ui/ui_hand_f2.png`.
