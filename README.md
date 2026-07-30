# ⚡ Partivolt — NEW STYLE

Мобильное приложение для сборки и сравнения ПК-комплектующих с переработанным UI на основе дизайна DNS.

![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.32-02569B?style=flat&logo=flutter)
![APK](https://img.shields.io/github/v/release/debugmi530-del/partivolt-NEW-STYLE?label=APK)

---

## 🆕 Что нового в NEW STYLE

Этот репозиторий — переработанная версия [pcbuilder](https://github.com/debugmi530-del/pcbuilder) с новым дизайном страницы **Сравнения**, вдохновлённым сайтом DNS-shop.ru.

### Новые механики сравнения:
| Механика | Описание |
|----------|----------|
| 🔶 **Оранжевая точка** | Маркер отличия рядом с названием характеристики |
| 🟢 **Зелёная подсветка** | Выделение лучшего значения среди сравниваемых товаров |
| 🔀 **Только различающиеся** | Toggle-переключатель для скрытия одинаковых характеристик |
| 📂 **Группы (секции)** | Характеристики разбиты на коллапсируемые категории (Экран, Процессор и т.д.) |
| ◀▶ **Навигация по товарам** | Стрелки для листания товаров в колонках при > 2 позициях |
| ❓ **Подсказки** | Иконка `?` с пояснением к сложным характеристикам |

---

## 📱 Скачать APK

Перейдите в раздел [Releases](https://github.com/debugmi530-del/partivolt-NEW-STYLE/releases) и скачайте последний APK.

| Архитектура | Рекомендуется для |
|-------------|-------------------|
| **arm64-v8a** | Современные Android (Snapdragon 800+, Exynos 9+, Dimensity) — **рекомендуется** |
| **armeabi-v7a** | Старые устройства (Android 5+) |
| **x86_64** | Эмулятор Android Studio |
| **universal** | Если не знаете какой выбрать |

---

## ✨ Функции

| Функция | Описание |
|---------|----------|
| 🗂️ **Каталог** | 8 категорий комплектующих, 4+ реальных товара в каждой |
| 🔧 **Сборщик** | Выбор и сборка ПК из комплектующих с бюджетом |
| ✅ **Совместимость** | Проверка совместимости сокета, памяти, питания, форм-фактора |
| 🔍 **Поиск** | Полнотекстовый поиск по всему каталогу |
| ⚖️ **Сравнение** | Сравнение до 3 комплектующих — DNS-стиль с подсветкой отличий |
| 💾 **Сохранение** | Сохранение нескольких сборок и загрузка их |
| 📡 **Офлайн** | Работает без интернета |

---

## 🛠️ Комплектующие

- **CPU**: Intel Core i9-13900K, AMD Ryzen 9 7950X, i5-13600K, Ryzen 5 7600X
- **GPU**: RTX 4090, RX 7900 XTX, RTX 4070 Ti, RX 7800 XT
- **RAM**: G.Skill Trident Z5 DDR5-6000, Corsair Vengeance DDR5, Kingston FURY Beast DDR4
- **Storage**: Samsung 990 Pro 2TB, WD Black SN850X 1TB, Seagate Barracuda 4TB
- **PSU**: Corsair RM1000x, EVGA SuperNOVA 850 G6, Seasonic Focus GX-650
- **Motherboard**: ASUS ROG Maximus Z790 Hero, MSI MEG X670E ACE, Gigabyte B650 AORUS Elite
- **Case**: Lian Li O11 Dynamic EVO, Fractal Design Meshify 2, NZXT H510 Flow
- **Cooling**: Noctua NH-D15, CORSAIR H150i ELITE LCD, DeepCool LT720

---

## 🔄 CI/CD

Каждый push в `main` автоматически собирает и публикует APK в Releases через GitHub Actions.

---

## 🧰 Сборка локально

```bash
# Требуется Flutter 3.32+
git clone https://github.com/debugmi530-del/partivolt-NEW-STYLE.git
cd partivolt-NEW-STYLE
flutter pub get
flutter build apk --release
```

---

## 📋 Стек

- **Flutter** 3.32 / **Dart** 3.8
- **Provider** — управление состоянием
- **Go Router** — навигация
- **Shared Preferences** — офлайн-хранилище
- **Google Fonts** — типографика

---

## 🗂️ Структура проекта

```
lib/
├── models/          # Модели данных (Part, Build, ComparisonItem)
├── providers/       # State management (BuildProvider, CompareProvider)
├── screens/         # Экраны приложения
│   ├── comparison/  # 🆕 Переработанный экран сравнения (DNS-стиль)
│   ├── catalog/     # Каталог комплектующих
│   ├── builder/     # Сборщик ПК
│   └── ...
├── widgets/         # Переиспользуемые виджеты
└── data/            # Данные о комплектующих
```

---

> Этот проект создан в учебных целях. Цены и характеристики товаров являются приблизительными.
