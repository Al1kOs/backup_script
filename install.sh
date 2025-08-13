#!/bin/bash

# Скрипт установки и настройки системы бэкапа
# Устанавливает права, создает директории, проверяет зависимости

set -e

# Конфигурация
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/backup-system"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/backup-system"
VERBOSE=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -d, --dir DIR          Директория установки (по умолчанию: $INSTALL_DIR)
    -c, --config DIR       Директория конфигурации (по умолчанию: $CONFIG_DIR)
    -l, --log DIR          Директория логов (по умолчанию: $LOG_DIR)
    -v, --verbose          Подробный вывод
    --help                 Показать эту справку

Примеры:
    $0                    # Установка в стандартные директории
    $0 -d /opt/backup     # Установка в пользовательскую директорию
EOF
}

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_DIR="$2"
            shift 2
            ;;
        -l|--log)
            LOG_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
    ;;
esac

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Ошибка: Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    local missing_deps=""
    
    # Проверка bash
    if ! command -v bash > /dev/null 2>&1; then
        missing_deps="$missing_deps bash"
    fi
    
    # Проверка ssh
    if ! command -v ssh > /dev/null 2>&1; then
        missing_deps="$missing_deps openssh-client"
    fi
    
    # Проверка scp
    if ! command -v scp > /dev/null 2>&1; then
        missing_deps="$missing_deps openssh-client"
    fi
    
    # Проверка tar
    if ! command -v tar > /dev/null 2>&1; then
        missing_deps="$missing_deps tar"
    fi
    
    # Проверка gzip
    if ! command -v gzip > /dev/null 2>&1; then
        missing_deps="$missing_deps gzip"
    fi
    
    # Проверка sha256sum
    if ! command -v sha256sum > /dev/null 2>&1; then
        missing_deps="$missing_deps coreutils"
    fi
    
    if [[ -n "$missing_deps" ]]; then
        log "✗ Отсутствуют зависимости: $missing_deps"
        log "Установите их с помощью менеджера пакетов вашего дистрибутива"
        return 1
    else
        log "✓ Все зависимости доступны"
        return 0
    fi
}

# Создание директорий
create_directories() {
    log "Создание директорий..."
    
    # Директория установки
    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        log "Создана директория: $INSTALL_DIR"
    fi
    
    # Директория конфигурации
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR"
        log "Создана директория: $CONFIG_DIR"
    fi
    
    # Директория логов
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        log "Создана директория: $LOG_DIR"
    fi
    
    # Директория для бэкапов
    local backup_dir="$CONFIG_DIR/backups"
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
        log "Создана директория: $backup_dir"
    fi
}

# Копирование скриптов
copy_scripts() {
    log "Копирование скриптов..."
    
    local scripts=(
        "backup_system.sh"
        "restore_system.sh"
        "incremental_backup.sh"
        "network_config.sh"
        "system_check.sh"
        "backup_automation.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            cp "$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            log "Скопирован и сделан исполняемым: $script"
        else
            log "⚠ Файл не найден: $script"
        fi
    done
}

# Копирование конфигурационных файлов
copy_configs() {
    log "Копирование конфигурационных файлов..."
    
    # Файл исключений
    if [[ -f "backup_excludes.txt" ]]; then
        cp "backup_excludes.txt" "$CONFIG_DIR/"
        log "Скопирован: backup_excludes.txt"
    fi
    
    # Пример конфигурации восстановления
    if [[ -f "restore.conf.example" ]]; then
        cp "restore.conf.example" "$CONFIG_DIR/restore.conf.example"
        log "Скопирован: restore.conf.example"
    fi
    
    # README
    if [[ -f "README.md" ]]; then
        cp "README.md" "$CONFIG_DIR/"
        log "Скопирован: README.md"
    fi
}

# Создание символических ссылок
create_symlinks() {
    log "Создание символических ссылок..."
    
    local scripts=(
        "backup-system"
        "restore-system"
        "incremental-backup"
        "network-config"
        "system-check"
        "backup-automation"
    )
    
    for script in "${scripts[@]}"; do
        local source_script="${script//-/_}.sh"
        if [[ -f "$INSTALL_DIR/$source_script" ]]; then
            ln -sf "$INSTALL_DIR/$source_script" "$INSTALL_DIR/$script"
            log "Создана символическая ссылка: $script"
        fi
    done
}

# Создание systemd сервиса для автоматических бэкапов
create_systemd_service() {
    log "Создание systemd сервиса..."
    
    local service_file="$SERVICE_DIR/backup-system.service"
    local timer_file="$SERVICE_DIR/backup-system.timer"
    
    # Создание сервиса
    cat > "$service_file" << EOF
[Unit]
Description=Automated System Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/backup_automation.sh --mode backup -h HOSTNAME -u root -d $CONFIG_DIR/backups
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Создание таймера
    cat > "$timer_file" << EOF
[Unit]
Description=Run backup-system.service daily
Requires=backup-system.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    log "Создан systemd сервис: backup-system.service"
    log "Создан systemd таймер: backup-system.timer"
}

# Создание файла конфигурации по умолчанию
create_default_config() {
    log "Создание конфигурации по умолчанию..."
    
    local config_file="$CONFIG_DIR/backup.conf"
    
    cat > "$config_file" << EOF
# Конфигурация по умолчанию для системы бэкапа
# Измените значения под ваши требования

# Основные настройки
DEFAULT_HOST=""
DEFAULT_USER="root"
DEFAULT_PORT="22"
DEFAULT_SSH_KEY=""
DEFAULT_BACKUP_DIR="$CONFIG_DIR/backups"
DEFAULT_COMPRESSION="gzip"

# Настройки инкрементных бэкапов
INCREMENTAL_RETENTION_DAYS=30
INCREMENTAL_SCHEDULE="daily"

# Настройки логирования
LOG_LEVEL="info"
LOG_RETENTION_DAYS=90

# Настройки уведомлений
NOTIFY_ON_SUCCESS=false
NOTIFY_ON_FAILURE=true
NOTIFY_EMAIL=""

# Настройки мониторинга
CHECK_DISK_SPACE_GB=10
CHECK_RAM_GB=1
EOF
    
    log "Создан файл конфигурации: $config_file"
}

# Настройка прав доступа
setup_permissions() {
    log "Настройка прав доступа..."
    
    # Права на директории
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    
    # Права на скрипты
    chmod 755 "$INSTALL_DIR"/*.sh
    
    # Права на конфигурационные файлы
    chmod 644 "$CONFIG_DIR"/*
    
    # Права на лог файлы
    touch "$LOG_DIR/backup-system.log"
    chmod 644 "$LOG_DIR"/*.log
    
    log "Права доступа настроены"
}

# Создание пользователя для бэкапов (опционально)
create_backup_user() {
    log "Создание пользователя для бэкапов..."
    
    if ! id "backup" > /dev/null 2>&1; then
        useradd -r -s /bin/bash -d "$CONFIG_DIR" backup
        usermod -aG sudo backup
        log "Создан пользователь: backup"
    else
        log "Пользователь backup уже существует"
    fi
    
    # Настройка прав для пользователя backup
    chown -R backup:backup "$CONFIG_DIR"
    chown -R backup:backup "$LOG_DIR"
}

# Создание cron заданий
create_cron_jobs() {
    log "Создание cron заданий..."
    
    local cron_file="/tmp/backup-cron"
    
    cat > "$cron_file" << EOF
# Автоматические бэкапы системы
# Ежедневный полный бэкап в 2:00
0 2 * * * $INSTALL_DIR/backup_automation.sh --mode backup -h HOSTNAME -d $CONFIG_DIR/backups >> $LOG_DIR/backup-system.log 2>&1

# Ежедневный инкрементный бэкап в 3:00
0 3 * * * $INSTALL_DIR/backup_automation.sh --mode incremental -h HOSTNAME -t incremental >> $LOG_DIR/backup-system.log 2>&1

# Еженедельная проверка системы в 4:00 по воскресеньям
0 4 * * 0 $INSTALL_DIR/backup_automation.sh --mode check -h HOSTNAME >> $LOG_DIR/backup-system.log 2>&1

# Ежемесячная очистка старых бэкапов в 5:00 первого числа месяца
0 5 1 * * find $CONFIG_DIR/backups -name "*.tar.*" -mtime +30 -delete >> $LOG_DIR/backup-system.log 2>&1
EOF
    
    log "Создан файл cron заданий: $cron_file"
    log "Отредактируйте HOSTNAME и добавьте в crontab: crontab $cron_file"
}

# Создание файла logrotate
create_logrotate() {
    log "Создание конфигурации logrotate..."
    
    local logrotate_file="/etc/logrotate.d/backup-system"
    
    cat > "$logrotate_file" << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF
    
    log "Создан файл logrotate: $logrotate_file"
}

# Вывод информации об установке
show_installation_info() {
    echo ""
    echo "=========================================="
    echo "Установка системы бэкапа завершена!"
    echo "=========================================="
    echo ""
    echo "Установленные компоненты:"
    echo "  Скрипты: $INSTALL_DIR"
    echo "  Конфигурация: $CONFIG_DIR"
    echo "  Логи: $LOG_DIR"
    echo ""
    echo "Доступные команды:"
    echo "  backup-system      - Создание бэкапа"
    echo "  restore-system     - Восстановление системы"
    echo "  incremental-backup - Инкрементные бэкапы"
    echo "  network-config     - Настройка сети"
    echo "  system-check       - Проверка системы"
    echo "  backup-automation  - Автоматизация"
    echo ""
    echo "Следующие шаги:"
    echo "1. Отредактируйте $CONFIG_DIR/backup.conf"
    echo "2. Настройте SSH ключи для удаленных серверов"
    echo "3. Добавьте cron задания: crontab /tmp/backup-cron"
    echo "4. Включите systemd таймер: systemctl enable backup-system.timer"
    echo ""
    echo "Документация: $CONFIG_DIR/README.md"
    echo ""
}

# Основная функция
main() {
    log "Начинаем установку системы бэкапа..."
    
    # Проверка прав root
    check_root
    
    # Проверка зависимостей
    if ! check_dependencies; then
        log "Установка прервана из-за отсутствующих зависимостей"
        exit 1
    fi
    
    # Создание директорий
    create_directories
    
    # Копирование скриптов
    copy_scripts
    
    # Копирование конфигурационных файлов
    copy_configs
    
    # Создание символических ссылок
    create_symlinks
    
    # Создание systemd сервиса
    create_systemd_service
    
    # Создание конфигурации по умолчанию
    create_default_config
    
    # Настройка прав доступа
    setup_permissions
    
    # Создание пользователя для бэкапов
    create_backup_user
    
    # Создание cron заданий
    create_cron_jobs
    
    # Создание logrotate
    create_logrotate
    
    # Вывод информации об установке
    show_installation_info
    
    log "Установка завершена успешно!"
}

# Запуск основной функции
main 