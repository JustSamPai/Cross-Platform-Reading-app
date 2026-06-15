# Flutter Reading Habit and Quiz App

A cross-platform Flutter app concept for tracking reading progress, building reading habits, and testing comprehension with quizzes.

This project is a cleaned portfolio version of an older university cross-platform app. The original code included reading pages, quiz screens, PDF utilities, Hive local storage, habit tiles, and streak tracking. This version restructures that idea into a clearer, recruiter-friendly project.

## Features

- Reading dashboard with current books and progress
- Habit and streak tracking
- Quiz screen for comprehension practice
- PDF reader placeholder for future document support
- Local-first architecture designed for Hive persistence
- Modular feature-based folder structure

## Tech Stack

- Flutter
- Dart
- Hive / Hive Flutter for local persistence
- Material Design

## Project Structure

```text
lib/
  app/
    reading_app.dart
  core/
    theme/
      app_theme.dart
  features/
    habits/
      models/
      pages/
    library/
      data/
      models/
      pages/
    pdf/
      pages/
    quiz/
      models/
      pages/
```

## Why This Project Is Portfolio-Worthy

This app demonstrates:

- cross-platform mobile development
- stateful UI design
- local data modelling
- feature-based architecture
- habit/streak logic
- quiz interaction flow
- product thinking around reading and learning

## Running Locally

If this folder does not yet contain Flutter platform folders such as `android/`,
`ios/`, `web/`, `windows/`, `macos/`, or `linux/`, generate them from inside
the project folder:

```bash
flutter create .
```

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

## Screenshots

Add screenshots here once the app is running:

```text
docs/screenshots/dashboard.png
docs/screenshots/quiz.png
docs/screenshots/habits.png
docs/screenshots/pdf-reader.png
```

## Roadmap

- Add Hive adapters for books, reading sessions, habits, and quiz results
- Add PDF file picker and PDF viewer integration
- Persist reading streaks locally
- Add quiz score history
- Add tests for streak calculation and quiz scoring
- Add screenshots and a short demo GIF

## Portfolio Summary

This app started as a university cross-platform application and has been refactored into a clearer mobile portfolio project. The goal is to show practical Flutter development, clean structure, and a product idea that can grow into a real learning tool.
