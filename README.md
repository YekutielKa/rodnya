# Rodnya 👨‍👩‍👧‍��

Семейный мессенджер с аудио/видео звонками для связи между Израилем и Россией.

## Структура проекта
```
rodnya/
├── backend/          # Node.js API сервер
├── rodnya_app/       # Flutter мобильное приложение
└── README.md
```

## Технологии

**Backend:**
- Node.js + Express
- Socket.IO (real-time)
- PostgreSQL
- Redis
- WebRTC (TURN/STUN)

**Mobile:**
- Flutter
- WebRTC

## Запуск

### Backend (Railway)
Backend развёрнут на Railway с PostgreSQL и Redis.

### Mobile
```bash
cd rodnya_app
flutter run
```

## Авторы
- Yekutiel
