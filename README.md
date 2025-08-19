# 🚀 Система бэкапа и восстановления Linux

Полнофункциональное решение для создания, управления и восстановления бэкапов Linux систем через SSH. Система поддерживает полные, инкрементные и дифференциальные бэкапы с автоматическим изменением сетевых настроек при восстановлении.

## 📁 Файлы в проекте

### 🔧 Основные скрипты:
- **`backup_system.sh`** - Создание полных бэкапов системы с помощью dd
- **`restore_system.sh`** - Восстановление системы из бэкапа с изменением сетевых настроек
- **`incremental_backup.sh`** - Инкрементные и дифференциальные бэкапы
- **`network_config.sh`** - Изменение сетевых настроек при восстановлении
- **`system_check.sh`** - Проверка системы перед бэкапом
- **`backup_automation.sh`** - Автоматизация всего процесса

### 📋 Конфигурационные файлы:
- **`backup_excludes.txt`** - Минимальные исключения для бэкапов
- **`restore.conf.example`** - Пример конфигурации для восстановления
- **`README.md`** - Данная документация

### 🛠️ Управление:
- **`install.sh`** - Установка системы
- **`uninstall.sh`** - Удаление системы
- **`Makefile`** - Удобные команды make

## ⚙️ Требования

### 🖥️ На локальной машине (откуда запускаются скрипты)
- **Bash 4.0+** - современная версия bash
- **SSH клиент** - для подключения к удаленным серверам
- **SCP** - для копирования файлов
- **Утилиты**: tar, gzip, bzip2, xz, sha256sum
- **Доступ к удаленному серверу** по SSH

### 🖥️ На удаленном сервере
- **SSH сервер** - для удаленного доступа
- **Утилиты**: dd, lsblk, df, mount
- **Достаточно места** для временных файлов
- **Права root** для создания бэкапов

## 🚀 Установка и настройка

### Быстрая установка:
```bash
# Клонирование или скачивание файлов
git clone https://github.com/Al1kOs/backup_script
cd backup_script

# Установка в пользовательскую директорию
make install

# Или установка в системную директорию (требует root)
sudo make install-system
```

### Ручная установка:
1. **Скопируйте все файлы** в рабочую директорию
2. **Сделайте скрипты исполняемыми**:
   ```bash
   chmod +x *.sh
   ```
3. **Настройте SSH ключи** для беспарольного доступа (рекомендуется)

### 🔑 Настройка SSH ключей:
```bash
# Генерация SSH ключа (если нет)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/backup_key

# Копирование ключа на удаленный сервер
ssh-copy-id -i ~/.ssh/backup_key.pub user@remote-server

# Тест подключения
ssh -i ~/.ssh/backup_key user@remote-server
```

## 📖 Использование

### 🎯 Сценарии использования

#### Сценарий 1: Первичная настройка и бэкап
```bash
# 1. Проверка системы перед бэкапом
./system_check.sh -h 192.168.1.100 -k ~/.ssh/backup_key -v

# 2. Создание полного бэкапа
./backup_system.sh -h 192.168.1.100 -k ~/.ssh/backup_key -d ./backups -c xz -v

# 3. Проверка созданного бэкапа
ls -la ./backups/
sha256sum -c ./backups/*.sha256
```

#### Сценарий 2: Регулярные инкрементные бэкапы
```bash
# Первый полный бэкап
./incremental_backup.sh -h 192.168.1.100 -t full -k ~/.ssh/backup_key

# Ежедневные инкрементные бэкапы
./incremental_backup.sh -h 192.168.1.100 -t incremental -k ~/.ssh/backup_key

# Еженедельные дифференциальные бэкапы
./incremental_backup.sh -h 192.168.1.100 -t differential -k ~/.ssh/backup_key
```

#### Сценарий 3: Восстановление на новый сервер
```bash
# 1. Создание конфигурации восстановления
cp restore.conf.example restore.conf
# Отредактируйте restore.conf с новыми параметрами

# 2. Восстановление системы
./restore_system.sh -b ./backups/system_backup_20231201_120000.img.gz \
                    -t 192.168.1.200 -d /dev/sda -f restore.conf
```

### 1. 🔍 Проверка системы перед бэкапом

```bash
# Базовая проверка
./system_check.sh -h 192.168.1.100

# Подробная проверка с SSH ключом
./system_check.sh -h 192.168.1.100 -k ~/.ssh/backup_key -v

# Проверка с пользовательскими требованиями
./system_check.sh -h 192.168.1.100 -d 50 -r 4 -k ~/.ssh/backup_key
```

**Опции проверки:**
- `-h, --host` - IP адрес или hostname удаленного сервера
- `-u, --user` - Пользователь для SSH (по умолчанию: root)
- `-p, --port` - SSH порт (по умолчанию: 22)
- `-k, --key` - Путь к SSH ключу
- `-d, --disk-space` - Минимальное свободное место в GB (по умолчанию: 10)
- `-r, --ram` - Минимальный объем RAM в GB (по умолчанию: 1)
- `-v, --verbose` - Подробный вывод

### 2. 💾 Создание полного бэкапа системы

```bash
# Базовый бэкап
./backup_system.sh -h 192.168.1.100 -u root -k ~/.ssh/backup_key

# Бэкап с указанием директории и типа сжатия
./backup_system.sh -h server.example.com -d /mnt/backups -c xz -v

# Тестовый запуск без выполнения
./backup_system.sh -h 192.168.1.100 --dry-run

# Бэкап с пользовательским SSH портом
./backup_system.sh -h 192.168.1.100 -p 2222 -k ~/.ssh/backup_key
```

**Опции бэкапа:**
- `-h, --host` - IP адрес или hostname удаленного сервера
- `-u, --user` - Пользователь для SSH (по умолчанию: root)
- `-p, --port` - SSH порт (по умолчанию: 22)
- `-k, --key` - Путь к SSH ключу
- `-d, --dir` - Директория для сохранения бэкапов
- `-c, --compression` - Тип сжатия: gzip, bzip2, xz
- `-v, --verbose` - Подробный вывод
- `--dry-run` - Показать что будет выполнено без выполнения

### 3. 🔄 Восстановление системы из бэкапа

```bash
# Базовое восстановление
./restore_system.sh -b ./backups/system_backup_20231201_120000.img.gz \
                    -t 192.168.1.100 -d /dev/sda

# Восстановление с изменением сетевых настроек
./restore_system.sh -b backup.img.gz -t server.example.com -d /dev/sda \
                    -H newserver -i 192.168.1.200 -g 192.168.1.1

# Восстановление без изменения сети
./restore_system.sh -b backup.img.gz -t 192.168.1.100 -d /dev/sda --skip-network

# Восстановление с полной настройкой сети
./restore_system.sh -b backup.img.gz -t 192.168.1.200 -d /dev/sda \
                    -H webserver -i 192.168.1.200 -m 255.255.255.0 \
                    -g 192.168.1.1 -n 8.8.8.8,8.8.4.4
```

**Опции восстановления:**
- `-b, --backup` - Путь к файлу бэкапа
- `-t, --target` - IP адрес или hostname целевого сервера
- `-d, --device` - Целевое устройство для восстановления
- `-u, --user` - Пользователь для SSH (по умолчанию: root)
- `-p, --port` - SSH порт (по умолчанию: 22)
- `-k, --key` - Путь к SSH ключу
- `-H, --hostname` - Новый hostname
- `-i, --ip` - Новый IP адрес
- `-m, --netmask` - Новая маска подсети
- `-g, --gateway` - Новый шлюз
- `-n, --dns` - Новые DNS серверы (через запятую)
- `--skip-network` - Пропустить настройку сети
- `-v, --verbose` - Подробный вывод
- `--dry-run` - Показать что будет выполнено без выполнения

### 4. 📈 Инкрементные бэкапы

```bash
# Полный бэкап
./incremental_backup.sh -h 192.168.1.100 -t full -k ~/.ssh/backup_key

# Инкрементный бэкап
./incremental_backup.sh -h 192.168.1.100 -t incremental -k ~/.ssh/backup_key

# Дифференциальный бэкап
./incremental_backup.sh -h 192.168.1.100 -t differential -k ~/.ssh/backup_key

# Бэкап с пользовательскими исключениями
./incremental_backup.sh -h 192.168.1.100 -t full -e custom_excludes.txt

# Бэкап с длительным хранением
./incremental_backup.sh -h 192.168.1.100 -t full -r 90

# Бэкап с пользовательским сжатием
./incremental_backup.sh -h 192.168.1.100 -t full -c xz -k ~/.ssh/backup_key
```

**Опции инкрементных бэкапов:**
- `-h, --host` - IP адрес или hostname удаленного сервера
- `-u, --user` - Пользователь для SSH (по умолчанию: root)
- `-p, --port` - SSH порт (по умолчанию: 22)
- `-k, --key` - Путь к SSH ключу
- `-d, --dir` - Директория для сохранения бэкапов
- `-t, --type` - Тип бэкапа: full, incremental, differential
- `-r, --retention` - Количество дней хранения бэкапов
- `-e, --exclude` - Файл с исключениями
- `-c, --compression` - Тип сжатия: gzip, bzip2, xz
- `-v, --verbose` - Подробный вывод
- `--dry-run` - Показать что будет выполнено без выполнения

### 5. 🌐 Изменение сетевых настроек

```bash
# Изменение только hostname
./network_config.sh -H newserver

# Изменение IP и hostname
./network_config.sh -H webserver -i 192.168.1.100

# Полная настройка сети
./network_config.sh -H dbserver -i 10.0.0.50 -m 255.255.255.0 \
                    -g 10.0.0.1 -n 8.8.8.8,8.8.4.4

# Тестовый запуск
./network_config.sh -H testserver -i 192.168.1.200 --dry-run

# Настройка с пользовательским интерфейсом
./network_config.sh -H webserver -i 192.168.1.100 -I eth1
```

**Опции настройки сети:**
- `-H, --hostname` - Новый hostname
- `-i, --ip` - Новый IP адрес
- `-m, --netmask` - Новая маска подсети (по умолчанию: 255.255.255.0)
- `-g, --gateway` - Новый шлюз
- `-n, --dns` - Новые DNS серверы через запятую (по умолчанию: 8.8.8.8,8.8.4.4)
- `-I, --interface` - Сетевой интерфейс (автоопределение если не указан)
- `-v, --verbose` - Подробный вывод
- `--dry-run` - Показать что будет выполнено без выполнения

### 6. 🤖 Автоматизация бэкапов

```bash
# Проверка системы
./backup_automation.sh --mode check -h 192.168.1.100 -k ~/.ssh/backup_key

# Создание бэкапа с проверкой
./backup_automation.sh --mode backup -h 192.168.1.100 -k ~/.ssh/backup_key

# Полный цикл: проверка -> бэкап -> проверка
./backup_automation.sh --mode full-cycle -h 192.168.1.100 -k ~/.ssh/backup_key

# Восстановление из конфигурации
./backup_automation.sh --mode restore -h 192.168.1.200 -f restore.conf
```

**Режимы автоматизации:**
- `--mode check` - Только проверка системы
- `--mode backup` - Проверка + создание бэкапа
- `--mode restore` - Восстановление системы
- `--mode full-cycle` - Полный цикл проверки и бэкапа

### 7. 🔧 Управление системой

```bash
# Установка в пользовательскую директорию
make install

# Установка в системную директорию (требует root)
sudo make install-system

# Проверка статуса установки
make status

# Тестирование скриптов
make test

# Очистка временных файлов
make clean

# Удаление системы
make uninstall
```

**Доступные команды make:**
- `install` - Установка в пользовательскую директорию
- `install-system` - Установка в системную директорию
- `install-user` - Установка для конкретного пользователя
- `install-dev` - Установка для разработки
- `status` - Проверка статуса установки
- `test` - Тестирование скриптов
- `lint` - Проверка кода с shellcheck
- `format` - Форматирование кода
- `clean` - Очистка временных файлов
- `uninstall` - Удаление системы
- `uninstall-force` - Принудительное удаление
```

## 📊 Структура бэкапов

### Полные бэкапы (backup_system.sh)
```
backups/
├── system_backup_20231201_120000.img.gz
├── system_backup_20231201_120000.img.gz.sha256
└── system_backup_20231201_120000.meta
```

### Инкрементные бэкапы (incremental_backup.sh)
```
incremental_backups/
├── full/
│   ├── full_backup_20231201_120000.tar.gz
│   └── full_backup_20231201_120000.tar.gz.sha256
├── incremental/
│   ├── incremental_backup_20231202_120000.tar.gz
│   └── incremental_backup_20231202_120000.tar.gz.sha256
├── differential/
│   ├── differential_backup_20231203_120000.tar.gz
│   └── differential_backup_20231203_120000.tar.gz.sha256
└── metadata/
    ├── last_full_backup
    └── *.meta
```

## 🎯 Практические примеры

### Пример 1: Миграция веб-сервера

**Задача**: Перенести веб-сервер с IP 192.168.1.100 на новый сервер с IP 192.168.1.200

```bash
# 1. Создание бэкапа исходного сервера
./backup_system.sh -h 192.168.1.100 -k ~/.ssh/backup_key -d ./migration -c xz -v

# 2. Создание конфигурации для нового сервера
cat > restore.conf << 'EOF'
BACKUP_FILE="./migration/system_backup_20231201_120000.img.gz"
TARGET_DEVICE="/dev/sda"
NEW_HOSTNAME="webserver-new"
NEW_IP="192.168.1.200"
NEW_NETMASK="255.255.255.0"
NEW_GATEWAY="192.168.1.1"
NEW_DNS="8.8.8.8,8.8.4.4"
EOF

# 3. Восстановление на новый сервер
./restore_system.sh -b ./migration/system_backup_20231201_120000.img.gz \
                    -t 192.168.1.200 -d /dev/sda -f restore.conf
```

### Пример 2: Регулярные бэкапы продакшн сервера

**Задача**: Настроить ежедневные инкрементные бэкапы с еженедельными полными

```bash
# 1. Первый полный бэкап
./incremental_backup.sh -h prod-server.example.com -t full -k ~/.ssh/prod_key

# 2. Создание cron заданий
crontab -e

# Добавить следующие строки:
# Ежедневный инкрементный бэкап в 2:00
0 2 * * * /usr/local/bin/incremental_backup.sh -h prod-server.example.com -t incremental -k ~/.ssh/prod_key

# Еженедельный полный бэкап в 3:00 по воскресеньям
0 3 * * 0 /usr/local/bin/incremental_backup.sh -h prod-server.example.com -t full -k ~/.ssh/prod_key

# Ежемесячная очистка старых бэкапов
0 4 1 * * find /backups -name "*.tar.*" -mtime +90 -delete
```

### Пример 3: Восстановление после сбоя

**Задача**: Восстановить сервер после критического сбоя

```bash
# 1. Проверка доступных бэкапов
ls -la ./backups/
cat ./backups/*.meta | grep -E "(TIMESTAMP|HOSTNAME|BACKUP_DATE)"

# 2. Выбор подходящего бэкапа (например, последний стабильный)
BACKUP_FILE="./backups/system_backup_20231130_120000.img.gz"

# 3. Проверка целостности
cd ./backups
sha256sum -c system_backup_20231130_120000.img.gz.sha256

# 4. Восстановление с сохранением текущих сетевых настроек
./restore_system.sh -b $BACKUP_FILE -t 192.168.1.100 -d /dev/sda --skip-network

# 5. Проверка восстановленной системы
./system_check.sh -h 192.168.1.100 -k ~/.ssh/backup_key
```

### Пример 4: Клонирование сервера для тестирования

**Задача**: Создать тестовую копию продакшн сервера

```bash
# 1. Создание бэкапа продакшн сервера
./backup_system.sh -h prod-server.example.com -k ~/.ssh/prod_key -d ./cloning

# 2. Создание конфигурации для тестового сервера
cat > test-restore.conf << 'EOF'
BACKUP_FILE="./cloning/system_backup_20231201_120000.img.gz"
TARGET_DEVICE="/dev/sda"
NEW_HOSTNAME="test-server"
NEW_IP="192.168.2.100"
NEW_NETMASK="255.255.255.0"
NEW_GATEWAY="192.168.2.1"
NEW_DNS="8.8.8.8,8.8.4.4"
EOF

# 3. Восстановление на тестовый сервер
./restore_system.sh -b ./cloning/system_backup_20231201_120000.img.gz \
                    -t 192.168.2.100 -d /dev/sda -f test-restore.conf

# 4. Проверка тестового сервера
./system_check.sh -h 192.168.2.100 -k ~/.ssh/test_key
```

### Инкрементные бэкапы (incremental_backup.sh)
```
incremental_backups/
├── full/
│   ├── full_backup_20231201_120000.tar.gz
│   └── full_backup_20231201_120000.tar.gz.sha256
├── incremental/
│   ├── incremental_backup_20231202_120000.tar.gz
│   └── incremental_backup_20231202_120000.tar.gz.sha256
├── differential/
│   ├── differential_backup_20231203_120000.tar.gz
│   └── differential_backup_20231203_120000.tar.gz.sha256
└── metadata/
    ├── last_full_backup
    └── *.meta
```

## 📋 Метаданные бэкапов

Каждый бэкап содержит подробные метаданные с информацией о:

### Основная информация:
- **TIMESTAMP** - Время создания бэкапа
- **BACKUP_TYPE** - Тип бэкапа (full, incremental, differential)
- **HOSTNAME** - Имя исходного сервера
- **USER** - Пользователь, создавший бэкап
- **BACKUP_DATE** - Дата и время создания
- **COMPRESSION** - Тип сжатия

### Системная информация:
- **Версия ядра** - uname -a
- **Информация о дисках** - lsblk вывод
- **Информация о разделах** - Монтированные файловые системы
- **Сетевые настройки** - IP адреса и интерфейсы
- **Размер диска** - Общий и использованный объем

### Пример метаданных:
```bash
# Просмотр метаданных бэкапа
cat ./backups/system_backup_20231201_120000.meta

# Поиск по метаданным
grep "HOSTNAME" ./backups/*.meta
grep "BACKUP_DATE" ./backups/*.meta | sort
```

## 🛡️ Безопасность

### Аутентификация и доступ:
- **SSH ключи** - Все скрипты поддерживают SSH ключи для безопасного доступа
- **Права доступа** - Проверка прав root на удаленном сервере
- **Безопасные соединения** - Использование SSH для всех операций

### Целостность данных:
- **Контрольные суммы** - SHA256 для проверки целостности бэкапов
- **Верификация** - Автоматическая проверка контрольных сумм при восстановлении
- **Метаданные** - Подробная информация о каждом бэкапе

### Защита данных:
- **Резервные копии** - Автоматическое создание резервных копий конфигурационных файлов
- **Логирование** - Подробные логи всех операций с временными метками
- **Изоляция** - Каждый бэкап изолирован и не влияет на другие

### Рекомендации по безопасности:
```bash
# Использование отдельных SSH ключей для бэкапов
ssh-keygen -t rsa -b 4096 -f ~/.ssh/backup_key -C "backup-system"

# Ограничение прав SSH ключа на сервере
# В ~/.ssh/authorized_keys добавить:
command="/usr/local/bin/backup-command" ssh-rsa AAAAB3NzaC1yc2E...

# Регулярная ротация ключей
# Создавайте новые ключи каждые 3-6 месяцев
```

## 🤖 Автоматизация

### Cron для регулярных бэкапов

```bash
# Ежедневный полный бэкап в 2:00
0 2 * * * /usr/local/bin/backup_system.sh -h 192.168.1.100 -d /mnt/backups -k ~/.ssh/backup_key

# Ежедневный инкрементный бэкап в 3:00
0 3 * * * /usr/local/bin/incremental_backup.sh -h 192.168.1.100 -t incremental -k ~/.ssh/backup_key

# Еженедельный дифференциальный бэкап в 4:00 по воскресеньям
0 4 * * 0 /usr/local/bin/incremental_backup.sh -h 192.168.1.100 -t differential -k ~/.ssh/backup_key

# Ежемесячная очистка старых бэкапов в 5:00 первого числа месяца
0 5 1 * * find /mnt/backups -name "*.tar.*" -mtime +90 -delete
```

### Systemd таймеры

```bash
# Включение и запуск таймера
sudo systemctl enable backup-system.timer
sudo systemctl start backup-system.timer

# Проверка статуса
sudo systemctl status backup-system.timer
sudo systemctl list-timers backup-system.timer

# Ручной запуск бэкапа
sudo systemctl start backup-system.service
```

### Автоматизация через Makefile

```bash
# Установка cron заданий
make install-cron

# Создание systemd сервисов
make install-systemd

# Настройка автоматических бэкапов
make setup-automation
```

### Мониторинг автоматических бэкапов

```bash
# Проверка последних бэкапов
find /mnt/backups -name "*.meta" -exec cat {} \; | grep -E "(TIMESTAMP|BACKUP_DATE)" | sort -r

# Проверка размера бэкапов
du -sh /mnt/backups/*/

# Проверка логов автоматизации
tail -f /var/log/backup-system/backup-system.log
```

## 📊 Мониторинг и логирование

### Логирование операций

Все скрипты создают подробные логи с временными метками. Рекомендуется настроить ротацию логов:

```bash
# Добавить в /etc/logrotate.d/backup-scripts
/path/to/backups/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

### Мониторинг бэкапов

```bash
# Проверка статуса последних бэкапов
./backup_automation.sh --mode check -h 192.168.1.100 -k ~/.ssh/backup_key

# Анализ размера и количества бэкапов
du -sh ./backups/*/ | sort -h
ls -la ./backups/*/ | wc -l

# Проверка целостности всех бэкапов
find ./backups -name "*.sha256" -exec sha256sum -c {} \;
```

### Алерты и уведомления

```bash
# Настройка email уведомлений (требует mailutils)
echo "Бэкап завершен успешно" | mail -s "Backup Status" admin@example.com

# Интеграция с системой мониторинга (например, Nagios)
# Создать скрипт проверки:
cat > check_backup_status.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/mnt/backups"
LAST_BACKUP=$(find $BACKUP_DIR -name "*.meta" -mtime -1 | head -1)

if [[ -n "$LAST_BACKUP" ]]; then
    echo "OK: Бэкап создан в последние 24 часа"
    exit 0
else
    echo "CRITICAL: Бэкап не создавался более 24 часов"
    exit 2
fi
EOF
```

### Дашборд мониторинга

```bash
# Создание простого дашборда
cat > backup_dashboard.sh << 'EOF'
#!/bin/bash
echo "=== ДАШБОРД СИСТЕМЫ БЭКАПОВ ==="
echo "Время: $(date)"
echo ""

echo "📊 Статистика бэкапов:"
echo "Полные бэкапы: $(find ./backups -name "*full*" | wc -l)"
echo "Инкрементные: $(find ./backups -name "*incremental*" | wc -l)"
echo "Дифференциальные: $(find ./backups -name "*differential*" | wc -l)"
echo ""

echo "💾 Размер бэкапов:"
du -sh ./backups/*/ 2>/dev/null | sort -h
echo ""

echo "🕒 Последние бэкапы:"
find ./backups -name "*.meta" -exec cat {} \; | grep -E "(TIMESTAMP|BACKUP_DATE)" | sort -r | head -5
EOF

chmod +x backup_dashboard.sh
```

## 🔧 Устранение неполадок

### Частые проблемы

#### 1. Ошибка SSH соединения
**Симптомы**: `ssh: connect to host 192.168.1.100 port 22: Connection refused`

**Решение**:
```bash
# Проверка доступности сервера
ping -c 3 192.168.1.100

# Проверка SSH порта
telnet 192.168.1.100 22

# Проверка SSH ключей
ssh-keygen -l -f ~/.ssh/backup_key
ssh -i ~/.ssh/backup_key -v root@192.168.1.100

# Проверка настроек SSH сервера
ssh root@192.168.1.100 "systemctl status sshd"
```

#### 2. Недостаточно места на диске
**Симптомы**: `No space left on device`

**Решение**:
```bash
# Проверка свободного места
df -h

# Очистка временных файлов
rm -rf /tmp/*
rm -rf /var/tmp/*

# Использование сжатия xz для экономии места
./backup_system.sh -h 192.168.1.100 -c xz -k ~/.ssh/backup_key

# Очистка старых бэкапов
find ./backups -name "*.img.*" -mtime +30 -delete
```

#### 3. Ошибки при восстановлении
**Симптомы**: `dd: failed to open '/dev/sda': Permission denied`

**Решение**:
```bash
# Проверка прав доступа
ls -la /dev/sda

# Проверка целостности файла бэкапа
sha256sum -c backup.img.gz.sha256

# Тестовый запуск без выполнения
./restore_system.sh -b backup.img.gz -t 192.168.1.100 -d /dev/sda --dry-run

# Проверка устройства
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

#### 4. Проблемы с сетевыми настройками
**Симптомы**: Сервер недоступен после восстановления

**Решение**:
```bash
# Восстановление без изменения сети
./restore_system.sh -b backup.img.gz -t 192.168.1.100 -d /dev/sda --skip-network

# Ручная настройка сети после восстановления
./network_config.sh -H webserver -i 192.168.1.100 -g 192.168.1.1

# Проверка сетевых настроек
ssh root@192.168.1.100 "ip addr show"
ssh root@192.168.1.100 "cat /etc/hostname"
```

### Диагностика проблем

#### Проверка логов
```bash
# Просмотр логов скриптов
tail -f /var/log/backup-system/backup-system.log

# Просмотр systemd логов
journalctl -u backup-system.service -f

# Просмотр SSH логов
tail -f /var/log/auth.log | grep ssh
```

#### Проверка целостности
```bash
# Проверка контрольной суммы
cd /path/to/backups
sha256sum -c *.sha256

# Проверка метаданных
cat *.meta

# Проверка размера файлов
ls -lah *.img.*
```

#### Тестирование соединения
```bash
# Тест SSH соединения
ssh -i ~/.ssh/backup_key -o ConnectTimeout=10 root@192.168.1.100 "echo 'SSH OK'"

# Тест SCP соединения
scp -i ~/.ssh/backup_key -o ConnectTimeout=10 /tmp/test.txt root@192.168.1.100:/tmp/

# Тест выполнения команд
ssh -i ~/.ssh/backup_key root@192.168.1.100 "dd --version"
```

### Восстановление после критических ошибок

#### Если бэкап поврежден
```bash
# Попытка восстановления частичных данных
gunzip -t backup.img.gz
xz -t backup.img.xz

# Использование предыдущего бэкапа
ls -t ./backups/*.img.* | head -2

# Создание нового бэкапа
./backup_system.sh -h 192.168.1.100 -k ~/.ssh/backup_key -v
```

#### Если система не загружается после восстановления
```bash
# Загрузка с Live CD/USB
# Монтирование восстановленной системы
mount /dev/sda1 /mnt
chroot /mnt

# Проверка и исправление загрузчика
grub-install /dev/sda
update-grub
```

## 🐧 Поддерживаемые дистрибутивы

### Полная поддержка:
- **Debian/Ubuntu** - Нативные сетевые настройки, systemd, apt
- **RHEL/CentOS** - NetworkManager, systemd, yum/dnf
- **Fedora** - NetworkManager, systemd, dnf

### Базовая поддержка:
- **Arch Linux** - systemd-networkd, pacman
- **openSUSE** - systemd-networkd, zypper
- **Gentoo** - systemd-networkd, emerge
- **Slackware** - Ручная настройка сети

### Проверка совместимости:
```bash
# Определение дистрибутива
cat /etc/os-release

# Проверка сетевого менеджера
systemctl status NetworkManager
systemctl status systemd-networkd

# Проверка доступных утилит
which ip
which systemctl
which hostnamectl
```

## 📚 Дополнительные ресурсы

### Полезные ссылки:
- [SSH ключи и безопасность](https://www.ssh.com/academy/ssh/key)
- [Systemd таймеры](https://systemd.io/TIMERS/)
- [Cron задачи](https://crontab.guru/)
- [DD команда](https://man7.org/linux/man-pages/man1/dd.1.html)

### Связанные инструменты:
- **rsync** - Для синхронизации файлов
- **tar** - Для архивирования
- **dd** - Для создания образов дисков
- **ssh/scp** - Для удаленного доступа

## 🤝 Вклад в проект

### Сообщение об ошибках:
1. Проверьте существующие issues
2. Создайте новый issue с подробным описанием
3. Приложите логи и конфигурацию
4. Укажите версию системы и дистрибутив

### Предложения по улучшению:
1. Опишите предлагаемую функциональность
2. Объясните, как это улучшит систему
3. Предложите способ реализации

## 📄 Лицензия

Данные скрипты предоставляются "как есть" без каких-либо гарантий. Используйте на свой страх и риск.

## 🆘 Поддержка

### При возникновении проблем:

#### 1. Самодиагностика:
```bash
# Проверка логов выполнения
tail -f /var/log/backup-system/backup-system.log

# Проверка параметров
./script_name.sh --help

# Подробный вывод
./script_name.sh --verbose

# Тестовый запуск
./script_name.sh --dry-run
```

#### 2. Проверка системы:
```bash
# Проверка SSH соединения
ssh -i ~/.ssh/backup_key root@server "echo 'Connection OK'"

# Проверка прав доступа
ls -la /dev/sda
id -u

# Проверка свободного места
df -h
```

#### 3. Обращение за помощью:
- **GitHub Issues** - для багов и предложений
- **Документация** - подробные инструкции
- **Примеры** - готовые сценарии использования
- **Логи** - для диагностики проблем

### Контакты:
- **Issues**: [GitHub Issues](https://github.com/Al1kOs/backup_script/issues)
- **Wiki**: [Документация](https://github.com/Al1kOs/backup_script/wiki)
- **Discussions**: [Обсуждения](https://github.com/Al1kOs/backup_script/discussions)

---

## 🎉 Заключение

Система бэкапа и восстановления Linux предоставляет мощный и гибкий инструмент для управления резервными копиями ваших серверов. С правильной настройкой и автоматизацией, вы можете обеспечить надежную защиту данных и быстрое восстановление в случае необходимости.

**Ключевые преимущества:**
- ✅ **Простота использования** - понятные команды и параметры
- ✅ **Гибкость** - поддержка различных типов бэкапов
- ✅ **Безопасность** - SSH ключи и контрольные суммы
- ✅ **Автоматизация** - cron и systemd интеграция
- ✅ **Мониторинг** - логирование и дашборды
- ✅ **Восстановление** - автоматическая настройка сети

**Начните прямо сейчас:**
```bash
# Быстрая установка
make install

# Первый бэкап
./backup_system.sh -h YOUR_SERVER_IP -k ~/.ssh/backup_key

# Автоматизация
make setup-automation
```


**Удачи в использовании системы бэкапа! 🚀** 


