# ⚡ Partivolt

Мобильное приложение для сборки ПК из комплектующих — как DNS, но в вашем кармане.

![Android](https://img.shields.io/badge/Android-3DDC84?style=flat&logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.32-02569B?style=flat&logo=flutter)
![APK](https://img.shields.io/github/v/release/debugmi530-del/pcbuilder?label=APK)

## 📱 Скачать APK

Перейдите в раздел [Releases](https://github.com/debugmi530-del/pcbuilder/releases) и скачайте последний APK.

- **arm64-v8a** — современные Android (Snapdragon 800+, Exynos 9+, Dimensity) — **рекомендуется**
- **armeabi-v7a** — старые устройства (Android 5+)
- **x86_64** — эмулятор Android Studio
- **universal** — если не знаете какой выбрать

## ✨ Функции

| Функция | Описание |
|---------|----------|
| 🗂️ **Каталог** | 8 категорий комплектующих, 4+ реальных товара в каждой |
| 🔧 **Сборщик** | Выбор и сборка ПК из комплектующих с бюджетом |
| ✅ **Совместимость** | Проверка совместимости сокета, памяти, питания, форм-фактора |
| 🔍 **Поиск** | Полнотекстовый поиск по всему каталогу |
| ⚖️ **Сравнение** | Сравнение до 3 комплектующих с подсветкой отличий |
| 💾 **Сохранение** | Сохранение нескольких сборок и загрузка их |
| 📡 **Офлайн** | Работает без интернета |

## 🛠️ Комплектующие

- **CPU**: Intel Core i9-13900K, AMD Ryzen 9 7950X, i5-13600K, Ryzen 5 7600X
- **GPU**: RTX 4090, RX 7900 XTX, RTX 4070 Ti, RX 7800 XT
- **RAM**: G.Skill Trident Z5 DDR5-6000, Corsair Vengeance DDR5, Kingston FURY Beast DDR4, G.Skill Ripjaws V DDR4
- **Storage**: Samsung 990 Pro 2TB, WD Black SN850X 1TB, Seagate Barracuda 4TB, Crucial MX500 2TB
- **PSU**: Corsair RM1000x, EVGA SuperNOVA 850 G6, Seasonic Focus GX-650, be quiet! Straight Power 11
- **Motherboard**: ASUS ROG Maximus Z790 Hero, MSI MEG X670E ACE, Gigabyte B650 AORUS Elite, ASUS PRIME Z790-P
- **Case**: Lian Li O11 Dynamic EVO, Fractal Design Meshify 2, NZXT H510 Flow, be quiet! Pure Base 500DX
- **Cooling**: Noctua NH-D15, CORSAIR H150i ELITE LCD, DeepCool LT720, EKWB Custom Loop

## 🔄 Автосборка

Каждый push в `main` автоматически собирает и публикует APK в Releases через GitHub Actions.

## 🧰 Сборка локально

```bash
# Требуется Flutter 3.32+
flutter pub get
flutter build apk --release
```

## 📋 Стек

- **Flutter** 3.32 / **Dart** 3.8
- **Provider** — управление состоянием
- **Go Router** — навигация
- **Shared Preferences** — офлайн-хранилище
- **Google Fonts** — типографика
