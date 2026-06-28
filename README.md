# ReadFlow

ReadFlow is a cross-platform Flutter app for tracking reading progress, daily reading habits, comprehension quizzes, and PDF study notes.

The project is structured as a portfolio-ready rewrite of a university reading app prototype. It keeps the same core feature set while presenting the code in a cleaner feature-based architecture.

## Why I built this

I rebuilt this app because I wanted to replace some of the time I spent watching YouTube Shorts with reading. I was inspired by apps like LNReader and Aniyomi, especially their extension-based approach to finding and reading content.

I also wanted to add a points-based progression system because I find reading more engaging when I can see my streak increase, earn XP, and make visible progress over time. The goal was to combine a flexible reading app with light gamification, making it easier and more enjoyable to build a consistent reading habit.

This project also gave me a practical way to improve my Flutter and Dart skills while working on an app idea I would personally use and continue developing.

## Features

- Reading dashboard with active books, page progress, and topic tags
- Hive-backed habit tracker with streaks, daily targets, completion state, and an activity heat map
- Quiz flow with scoring, XP rewards, level progress, and completed-quiz tracking
- PDF / EPUB import library with search, delete, and native PDF preview support on Android and iOS
- Platform-safe document reader fallbacks for web and desktop builds
- Responsive navigation for mobile and wider web/desktop layouts

## Tech Stack

- Flutter and Dart
- Material 3
- Hive / Hive Flutter
- File Picker
- Flutter PDFView
- Flutter test and model tests

## Project Structure

```text
lib/
  app/
    reading_app.dart
  core/
    storage/
    theme/
    widgets/
  features/
    habits/
      data/
      models/
      pages/
      widgets/
    library/
      data/
      models/
      pages/
    pdf/
      pages/
      widgets/
    quiz/
      data/
      models/
      pages/
test/
```

## Running Locally

Install dependencies:

```bash
flutter pub get
```

Run on the default connected device:

```bash
flutter run
```

Run on Chrome:

```bash
flutter run -d chrome
```

Run on Firefox or another browser:

```bash
flutter run -d web-server --web-port 8080
```

Then open `http://localhost:8080` in that browser.

If a release web build is blocked by Windows Application Control at Flutter's
`font-subset.exe` step, build with:

```bash
flutter build web --no-tree-shake-icons
```

## Quality Checks

```bash
dart analyze
flutter test
```

## Portfolio Highlights

- Separates app bootstrap, theme, storage, feature data, models, and pages
- Replaces starter-template tests with tests for the actual app and domain logic
- Uses sample data so reviewers can understand the product immediately
- Preserves the original university app behavior with typed models, stores, and tests

## Roadmap
- Add Hive adapters if the stored models become more complex
- Add full text extraction/search inside PDF contents
- Add a dedicated EPUB renderer
- Add screenshots or a short demo GIF for the GitHub READM
