# Cloud-Local: Установка n8n, Flowise, Zep и crawl4ai

Автоматизированный скрипт для установки n8n, Flowise, Zep и crawl4ai с веб-сервером Caddy для безопасного доступа по HTTPS.

## Описание

Этот репозиторий содержит скрипты для автоматической настройки:

- **n8n** - мощная open-source платформа для автоматизации рабочих процессов
- **Flowise** - инструмент для создания кастомизируемых AI-приложений
- **Zep** - хранилище памяти и векторная база данных для LLM-приложений
- **crawl4ai** - API-сервис для скрапинга веб-страниц
- **Caddy** - современный веб-сервер с автоматическим HTTPS

Система настроена для работы с вашим доменным именем и автоматически получает SSL-сертификаты Let's Encrypt.

## Требования

- Ubuntu 22.04
- Доменное имя, указывающее на IP-адрес вашего сервера
- Доступ к серверу с правами администратора (sudo)
- Открытые порты 80, 443
- API-ключ OpenRouter (для функциональности LLM в Zep)

## Установка

1.  Клонируйте репозиторий:
    ```bash
    git clone https://github.com/PavelBelove/cloud-local-n8n-flowise.git && cd cloud-local-n8n-flowise
    ```

2.  Сделайте скрипт исполняемым:
    ```bash
    chmod +x setup.sh
    ```

3.  Запустите установочный скрипт:
    ```bash
    ./setup.sh
    ```

4.  Следуйте инструкциям в терминале:
    - Введите ваше доменное имя (например, example.com)
    - Введите ваш email (будет использоваться для входа в n8n и Let's Encrypt)
    - Введите ваш API-ключ OpenRouter (для использования внешних LLM в Zep)
    - Опционально, измените модель OpenRouter (по умолчанию: meta-llama/llama-4-maverick:free)

## Что делает установочный скрипт

1.  **Обновление системы** - обновляет список пакетов и устанавливает необходимые зависимости
2.  **Установка Docker** - устанавливает Docker Engine и Docker Compose
3.  **Настройка директорий** - создает пользователя n8n и необходимые директории
4.  **Генерация секретов** - создает случайные пароли и ключи шифрования
5.  **Создание файлов конфигурации** - генерирует файлы docker-compose и Caddyfile
6.  **Настройка брандмауэра** - открывает необходимые порты (22, 80, 443)
7.  **Настройка Zep** - создает директории и устанавливает разрешения для Zep
8.  **Запуск сервисов** - собирает образ crawl4ai и запускает все Docker-контейнеры

## Доступ к сервисам

После завершения установки вы сможете получить доступ к сервисам по следующим URL:

- **n8n**: https://n8n.ваш-домен.xxx
- **Flowise**: https://flowise.ваш-домен.xxx
- **Zep API**: https://zep.ваш-домен.xxx/api
- **crawl4ai API**: https://crawl4ai.ваш-домен.xxx/api/v1/crawl/

Учетные данные для входа (n8n, Flowise) и API-ключи (Zep Admin) будут отображены в конце процесса установки.

## Структура проекта

- `setup.sh` - основной установочный скрипт
- `crawl4ai-docker/` - директория с Dockerfile и requirements.txt для сборки crawl4ai
- `setup-files/` - директория со вспомогательными скриптами:
    - `01-update-system.sh` - обновление системы
    - `02-install-docker.sh` - установка Docker
    - `03-setup-directories.sh` - настройка директорий и пользователя
    - `04-generate-secrets.sh` - генерация секретных ключей
    - `05-create-templates.sh` - создание файлов конфигурации
    - `06-setup-firewall.sh` - настройка брандмауэра
    - `07-start-services.sh` - запуск сервисов
    - `08-setup-zep.sh` - настройка Zep
- `n8n-docker-compose.yaml.template` - шаблон docker-compose для n8n и Caddy
- `flowise-docker-compose.yaml.template` - шаблон docker-compose для Flowise
- `zep-docker-compose.yaml.template` - шаблон docker-compose для Zep, PostgreSQL и Qdrant
- `crawl4ai-docker-compose.yaml.template` - шаблон docker-compose для crawl4ai

## Конфигурация Zep

Zep настроен с:
- Базой данных PostgreSQL для хранения памяти
- Векторной базой данных Qdrant для хранения эмбеддингов
- Моделью эмбеддингов Sentence Transformers (all-MiniLM-L6-v2)
- OpenRouter для доступа к API языковых моделей
- Включенной аутентификацией (Admin API Key генерируется при установке)

## Интеграция Zep

При взаимодействии с API Zep вам потребуется предоставить API-ключ. Admin API-ключ генерируется во время установки и выводится в конце. Вы можете создать дополнительные ключи через сам API (см. документацию Zep).

### С n8n
Вы можете использовать Zep в n8n через ноды HTTP Request:
- Базовый URL: `https://zep.ваш-домен.xxx/api`
- Аутентификация: Используйте сгенерированный Admin API Key или создайте новый через API.
- Документация API: https://docs.getzep.com/api/

### С Flowise
Вы можете интегрировать Zep в Flowise, создавая кастомные инструменты или используя компоненты памяти:
- API Endpoint: `https://zep.ваш-домен.xxx/api`
- Аутентификация: Используйте сгенерированный Admin API Key или создайте новый через API.
- Документация: https://docs.getzep.com

## Интеграция crawl4ai

crawl4ai предоставляет API для скрапинга веб-страниц. Его можно вызывать из n8n или Flowise.

- **API Endpoint**: `https://crawl4ai.ваш-домен.xxx/api/v1/crawl/`
- **Метод**: `POST`
- **Тело запроса (JSON)**:
  ```json
  {
    "url": "URL_сайта_для_скрапинга",
    "proxy": null, // Опционально: настройки прокси
    "crawler_options": { // Опционально: настройки скрапинга
      "limit": 1, // Лимит страниц
      "depth": 1, // Глубина обхода
      "include_raw_html": false, // Включать ли сырой HTML
      "use_playwright": false // Использовать ли Playwright (требует доп. настроек)
    }
  }
  ```
- **Документация crawl4ai**: https://github.com/unclecode/crawl4ai

## Управление сервисами

### Перезапуск сервисов

```bash
docker compose -f n8n-docker-compose.yaml restart
docker compose -f flowise-docker-compose.yaml restart
docker compose -f zep-docker-compose.yaml restart
docker compose -f crawl4ai-docker-compose.yaml restart
```

### Остановка сервисов

```bash
docker compose -f n8n-docker-compose.yaml down
docker compose -f flowise-docker-compose.yaml down
docker compose -f zep-docker-compose.yaml down
docker compose -f crawl4ai-docker-compose.yaml down
```

### Просмотр логов

```bash
docker compose -f n8n-docker-compose.yaml logs
docker compose -f flowise-docker-compose.yaml logs
docker compose -f zep-docker-compose.yaml logs
docker compose -f crawl4ai-docker-compose.yaml logs
```

## Безопасность

- Все сервисы доступны только по HTTPS с автоматически обновляемыми сертификатами Let's Encrypt
- Случайные пароли создаются для n8n, Flowise и PostgreSQL
- Пользователи создаются с минимальными необходимыми привилегиями
- API-ключи (OpenRouter, Zep Admin) надежно хранятся в переменных окружения
- Убедитесь, что порты 80 и 443 открыты на вашем сервере
- Просмотрите логи контейнеров для выявления ошибок
- Для проблем, связанных с Zep, проверьте логи Zep: `docker compose -f zep-docker-compose.yaml logs zep`
- Для проблем, связанных с crawl4ai, проверьте логи crawl4ai: `docker compose -f crawl4ai-docker-compose.yaml logs crawl4ai`

## Лицензия

Этот проект распространяется под лицензией MIT.

## Автор

@pavelbelove