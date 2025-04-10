module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "feat", // Новая функциональность
        "fix", // Исправление ошибок
        "docs", // Изменения в документации
        "style", // Изменения форматирования
        "refactor", // Рефакторинг кода
        "perf", // Улучшение производительности
        "test", // Добавление или изменение тестов
        "chore", // Обновление зависимостей и т.п.
        "revert", // Откат изменений
        "ci", // Изменения в CI/CD
        "build", // Изменения в сборке
      ],
    ],
    "type-case": [2, "always", "lower"],
    "type-empty": [2, "never"],
    "scope-case": [2, "always", "lower"],
    "subject-case": [2, "always", "lower"],
    "subject-empty": [2, "never"],
    "subject-full-stop": [2, "never", "."],
    "header-max-length": [2, "always", 72],
  },
};
