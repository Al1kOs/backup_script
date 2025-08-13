#!/bin/bash

# Скрипт удаления системы бэкапа
# Удаляет все установленные компоненты

set -e

# Конфигурация
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/backup-system"
SERVICE_DIR="/etc/systemd/system"
LOG_DIR="/var/log/backup-system"
VERBOSE=false
FORCE=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -d, --dir DIR          Директория установки (по умолчанию: $INSTALL_DIR)
    -c, --config DIR       Директория конфигурации (по умолчанию: $CONFIG_DIR)
    -l, --log DIR          Директория логов (по умолчанию: $LOG_DIR)
    -f, --force            Принудительное удаление без подтверждения
    -v, --verbose          Подробный вывод
    --help                 Показать эту справку

Примеры:
    $0                    # Удаление с подтверждением
    $0 -f                 # Принудительное удаление
    $0 -d /opt/backup     # Удаление из пользовательской директории
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
        -f|--force)
            FORCE=true
            shift
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
done

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

# Подтверждение удаления
confirm_uninstall() {
    if [[ "$FORCE" == true ]]; then
        return 0
    fi
    
    echo ""
    echo "ВНИМАНИЕ: Вы собираетесь удалить систему бэкапа!"
    echo ""
    echo "Будут удалены:"
    echo "  - Скрипты из: $INSTALL_DIR"
    echo "  - Конфигурация из: $CONFIG_DIR"
    echo "  - Логи из: $LOG_DIR"
    echo "  - Systemd сервисы"
    echo "  - Cron задания"
    echo "  - Пользователь backup"
    echo ""
    echo "ВСЕ БЭКАПЫ БУДУТ УДАЛЕНЫ!"
    echo ""
    
    read -p "Вы уверены, что хотите продолжить? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo "Удаление отменено"
        exit 0
    fi
    
    echo ""
    read -p "Введите 'DELETE' для подтверждения: " delete_confirm
    
    if [[ "$delete_confirm" != "DELETE" ]]; then
        echo "Удаление отменено"
        exit 0
    fi
}

# Остановка и удаление systemd сервисов
remove_systemd_services() {
    log "Удаление systemd сервисов..."
    
    local service_file="$SERVICE_DIR/backup-system.service"
    local timer_file="$SERVICE_DIR/backup-system.timer"
    
    # Остановка таймера
    if systemctl is-active --quiet backup-system.timer; then
        systemctl stop backup-system.timer
        log "Остановлен таймер: backup-system.timer"
    fi
    
    # Отключение таймера
    if systemctl is-enabled --quiet backup-system.timer; then
        systemctl disable backup-system.timer
        log "Отключен таймер: backup-system.timer"
    fi
    
    # Удаление файлов сервисов
    if [[ -f "$service_file" ]]; then
        rm -f "$service_file"
        log "Удален сервис: $service_file"
    fi
    
    if [[ -f "$timer_file" ]]; then
        rm -f "$timer_file"
        log "Удален таймер: $timer_file"
    fi
    
    # Перезагрузка systemd
    systemctl daemon-reload
    log "Systemd перезагружен"
}

# Удаление cron заданий
remove_cron_jobs() {
    log "Удаление cron заданий..."
    
    # Создание временного файла без заданий бэкапа
    local temp_cron="/tmp/backup-cron-temp"
    local current_cron="/tmp/backup-cron-current"
    
    # Экспорт текущих cron заданий
    crontab -l > "$current_cron" 2>/dev/null || true
    
    # Удаление заданий, связанных с бэкапом
    if [[ -f "$current_cron" ]]; then
        grep -v "backup-system\|backup_automation" "$current_cron" > "$temp_cron" 2>/dev/null || true
        
        # Установка очищенного crontab
        if [[ -s "$temp_cron" ]]; then
            crontab "$temp_cron"
            log "Cron задания очищены"
        else
            crontab -r
            log "Все cron задания удалены"
        fi
        
        # Очистка временных файлов
        rm -f "$temp_cron" "$current_cron"
    fi
}

# Удаление пользователя backup
remove_backup_user() {
    log "Удаление пользователя backup..."
    
    if id "backup" > /dev/null 2>&1; then
        # Удаление пользователя и его домашней директории
        userdel -r backup 2>/dev/null || userdel backup
        log "Пользователь backup удален"
    else
        log "Пользователь backup не найден"
    fi
}

# Удаление символических ссылок
remove_symlinks() {
    log "Удаление символических ссылок..."
    
    local symlinks=(
        "backup-system"
        "restore-system"
        "incremental-backup"
        "network-config"
        "system-check"
        "backup-automation"
    )
    
    for symlink in "${symlinks[@]}"; do
        if [[ -L "$INSTALL_DIR/$symlink" ]]; then
            rm -f "$INSTALL_DIR/$symlink"
            log "Удалена символическая ссылка: $symlink"
        fi
    done
}

# Удаление скриптов
remove_scripts() {
    log "Удаление скриптов..."
    
    local scripts=(
        "backup_system.sh"
        "restore_system.sh"
        "incremental_backup.sh"
        "network_config.sh"
        "system_check.sh"
        "backup_automation.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$INSTALL_DIR/$script" ]]; then
            rm -f "$INSTALL_DIR/$script"
            log "Удален скрипт: $script"
        fi
    done
}

# Удаление конфигурационных файлов
remove_configs() {
    log "Удаление конфигурационных файлов..."
    
    if [[ -d "$CONFIG_DIR" ]]; then
        # Создание резервной копии бэкапов (если есть)
        local backup_dir="$CONFIG_DIR/backups"
        if [[ -d "$backup_dir" ]]; then
            local backup_count=$(find "$backup_dir" -name "*.tar.*" -o -name "*.img.*" | wc -l)
            if [[ $backup_count -gt 0 ]]; then
                log "⚠ Найдено $backup_count файлов бэкапа в $backup_dir"
                log "Создание резервной копии..."
                local backup_copy="/tmp/backup-system-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf "$backup_copy" -C "$CONFIG_DIR" .
                log "Резервная копия создана: $backup_copy"
            fi
        fi
        
        # Удаление директории конфигурации
        rm -rf "$CONFIG_DIR"
        log "Удалена директория конфигурации: $CONFIG_DIR"
    fi
}

# Удаление логов
remove_logs() {
    log "Удаление логов..."
    
    if [[ -d "$LOG_DIR" ]]; then
        # Создание резервной копии логов (если есть)
        local log_count=$(find "$LOG_DIR" -name "*.log" | wc -l)
        if [[ $log_count -gt 0 ]]; then
            log "⚠ Найдено $log_count лог файлов в $LOG_DIR"
            log "Создание резервной копии..."
            local log_copy="/tmp/backup-system-logs-$(date +%Y%m%d_%H%M%S).tar.gz"
            tar -czf "$log_copy" -C "$LOG_DIR" .
            log "Резервная копия логов создана: $log_copy"
        fi
        
        # Удаление директории логов
        rm -rf "$LOG_DIR"
        log "Удалена директория логов: $LOG_DIR"
    fi
}

# Удаление logrotate конфигурации
remove_logrotate() {
    log "Удаление logrotate конфигурации..."
    
    local logrotate_file="/etc/logrotate.d/backup-system"
    
    if [[ -f "$logrotate_file" ]]; then
        rm -f "$logrotate_file"
        log "Удален файл logrotate: $logrotate_file"
    fi
}

# Очистка временных файлов
cleanup_temp_files() {
    log "Очистка временных файлов..."
    
    local temp_files=(
        "/tmp/backup-cron"
        "/tmp/backup-cron-temp"
        "/tmp/backup-cron-current"
    )
    
    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file"
            log "Удален временный файл: $temp_file"
        fi
    done
}

# Проверка оставшихся файлов
check_remaining_files() {
    log "Проверка оставшихся файлов..."
    
    local remaining_files=()
    
    # Проверка скриптов
    for script in backup_system restore_system incremental_backup network_config system_check backup_automation; do
        if [[ -f "$INSTALL_DIR/${script}.sh" ]]; then
            remaining_files+=("$INSTALL_DIR/${script}.sh")
        fi
    done
    
    # Проверка символических ссылок
    for symlink in backup-system restore-system incremental-backup network-config system-check backup-automation; do
        if [[ -L "$INSTALL_DIR/$symlink" ]]; then
            remaining_files+=("$INSTALL_DIR/$symlink")
        fi
    done
    
    # Проверка директорий
    if [[ -d "$CONFIG_DIR" ]]; then
        remaining_files+=("$CONFIG_DIR")
    fi
    
    if [[ -d "$LOG_DIR" ]]; then
        remaining_files+=("$LOG_DIR")
    fi
    
    if [[ ${#remaining_files[@]} -gt 0 ]]; then
        log "⚠ Остались следующие файлы/директории:"
        for file in "${remaining_files[@]}"; do
            log "  $file"
        done
        log "Удалите их вручную, если необходимо"
    else
        log "✓ Все файлы системы бэкапа удалены"
    fi
}

# Основная функция
main() {
    log "Начинаем удаление системы бэкапа..."
    
    # Проверка прав root
    check_root
    
    # Подтверждение удаления
    confirm_uninstall
    
    log "Удаление подтверждено. Начинаем процесс..."
    
    # Остановка и удаление systemd сервисов
    remove_systemd_services
    
    # Удаление cron заданий
    remove_cron_jobs
    
    # Удаление пользователя backup
    remove_backup_user
    
    # Удаление символических ссылок
    remove_symlinks
    
    # Удаление скриптов
    remove_scripts
    
    # Удаление конфигурационных файлов
    remove_configs
    
    # Удаление логов
    remove_logs
    
    # Удаление logrotate конфигурации
    remove_logrotate
    
    # Очистка временных файлов
    cleanup_temp_files
    
    # Проверка оставшихся файлов
    check_remaining_files
    
    echo ""
    echo "=========================================="
    echo "Удаление системы бэкапа завершено!"
    echo "=========================================="
    echo ""
    echo "Удаленные компоненты:"
    echo "  - Скрипты из: $INSTALL_DIR"
    echo "  - Конфигурация из: $CONFIG_DIR"
    echo "  - Логи из: $LOG_DIR"
    echo "  - Systemd сервисы"
    echo "  - Cron задания"
    echo "  - Пользователь backup"
    echo ""
    echo "Резервные копии (если были):"
    echo "  - Бэкапы: /tmp/backup-system-backup-*.tar.gz"
    echo "  - Логи: /tmp/backup-system-logs-*.tar.gz"
    echo ""
    echo "Система бэкапа полностью удалена"
    echo ""
    
    log "Удаление завершено успешно!"
}

# Запуск основной функции
main 