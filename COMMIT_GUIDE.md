# Руководство по написанию сообщений коммитов

## Автоматическая генерация коммитов

Для автоматической генерации коммитов используйте команду:

```bash
npm run commit
```

Это запустит интерактивный процесс создания коммита, где вы сможете:

1. Выбрать тип изменений
2. Указать область изменений (опционально)
3. Ввести краткое описание
4. Добавить подробное описание (опционально)
5. Указать breaking changes (опционально)
6. Указать связанные issues (опционально)

### Пример использования

```bash
$ npm run commit

? Select the type of change you're committing: (Use arrow keys)
❯ feat:     A new feature
  fix:      A bug fix
  docs:     Documentation only changes
  style:    Changes that do not affect the meaning of the code
  refactor: A code change that neither fixes a bug nor adds a feature
  perf:     A code change that improves performance
  test:     Adding missing tests or correcting existing tests
  chore:    Changes to the build process or auxiliary tools

? What is the scope of this change (e.g. install, scripts, web)? (press enter to skip)
  install

? Write a short description:
  add ipset installation check

? Provide a longer description of the change: (press enter to skip)
  Added automatic check and installation of ipset package during setup

? Are there any breaking changes? (y/N)
  n

? Does this change affect any open issues? (y/N)
  n
```

## Ручное написание коммитов

Если вы предпочитаете писать коммиты вручную, используйте следующий формат:

```bash
<тип>[область]: <описание>

[тело]

[подвал]
```

### Типы коммитов

- `feat`: Новая функциональность
- `fix`: Исправление ошибок
- `docs`: Изменения в документации
- `style`: Изменения форматирования
- `refactor`: Рефакторинг кода
- `perf`: Улучшение производительности
- `test`: Добавление или изменение тестов
- `chore`: Обновление зависимостей и т.п.
- `revert`: Откат изменений
- `ci`: Изменения в CI/CD
- `build`: Изменения в сборке

### Область (опционально)

Указывает на часть проекта, к которой относятся изменения:

- `install`: Изменения в установке
- `uninstall`: Изменения в удалении
- `scripts`: Изменения в скриптах
- `web`: Изменения в веб-интерфейсе
- `docs`: Изменения в документации

### Описание

Краткое описание изменений в настоящем времени:

- Используйте нижний регистр
- Не используйте точку в конце
- Ограничьте длину 72 символами

### Примеры

```bash
feat(install): add ipset installation check
fix(scripts): resolve timeout command issue
docs: update installation instructions
style: format shell scripts
refactor(web): improve error handling
```

## Установка

1. Установите зависимости:

```bash
npm install
```

2. Инициализируйте husky:

```bash
npm run prepare
```

## Автоматическая проверка

При каждом коммите сообщение будет автоматически проверяться на соответствие правилам.
Если сообщение не соответствует формату, коммит будет отклонен с описанием ошибки.

## Генерация Changelog

Changelog автоматически генерируется на основе сообщений коммитов.

### Первая генерация

Для первой генерации changelog используйте:

```bash
npm run changelog:first
```

### Обновление changelog

Для обновления changelog после новых коммитов:

```bash
npm run changelog
```

### Формат Changelog

Changelog следует формату [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) и включает:

- Версии в формате [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- Группировку изменений по типам (Added, Changed, Deprecated, Removed, Fixed, Security)
- Ссылки на сравнение версий
- Даты релизов

### Пример Changelog

```markdown
# Changelog

## [1.1.0] - 2024-04-10

### Added
- New feature for managing multiple VPN servers
- Support for custom DNS settings

### Fixed
- Resolved timeout issues in installation script
- Fixed web interface connection problems

### Changed
- Improved error handling in all scripts
- Updated documentation with new features

## [1.0.0] - 2024-04-01

### Added
- Initial release
- Basic VPN management functionality
- Web interface
- Installation and uninstallation scripts
```
