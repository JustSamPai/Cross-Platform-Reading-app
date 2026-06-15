# Refactor Plan

Use this checklist to turn the old cross-platform app into a polished portfolio repo.

## Phase 1: Clean Packaging

- Create a fresh Flutter project.
- Move old `main.dart`, `pages/`, `data/`, and `utilities/` files into `lib/`.
- Rename `utilites` to `utilities` if keeping the old folder.
- Remove generated build files and IDE metadata.
- Add a real `README.md`.
- Add screenshots.

## Phase 2: Improve Architecture

- Split features into `library`, `quiz`, `habits`, and `pdf`.
- Keep models separate from UI widgets.
- Move Hive logic into repository/service classes.
- Avoid business logic directly inside widgets.

## Phase 3: Portfolio Polish

- Add a clean home dashboard.
- Add sample data so the app looks useful immediately.
- Add a short demo GIF.
- Add tests for quiz scoring and streak calculation.
- Add a "What I learned" section to the README.

## Phase 4: Future AI Extension

- Generate quiz questions from selected reading material.
- Summarise PDF chapters.
- Track topics the user struggles with.
- Recommend review sessions based on quiz history.
