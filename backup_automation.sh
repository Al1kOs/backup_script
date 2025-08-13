#!/bin/bash

# Скрипт автоматизации для полного цикла бэкапа и восстановления
# Объединяет все функции: проверка, бэкап, восстановление

set -e

# Конфигурация
CONFIG_FILE=""
BACKUP_MODE="backup"  # backup, restore, check, full-cycle
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SSH_KEY=""
BACKUP_DIR="./backups"
COMPRESSION="gzip"
VERBOSE=false
DRY_RUN=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Режимы работы:
    --mode backup        Создание бэкапа (по умолчанию)
    --mode restore      Восстановление из бэкапа
    --mode check        Проверка системы
    --mode full-cycle   Полный цикл: проверка -> бэкап -> проверка

Опции:
    -h, --host HOST        IP адрес или hostname удаленного сервера
    -u, --user USER        Пользователь для SSH (по умолчанию: root)
    -p, --port PORT        SSH порт (по умолчанию: 22)
    -k, --key KEY          Путь к SSH ключу
    -d, --dir DIR          Директория для бэкапов (по умолчанию: ./backups)
    -c, --compression TYPE Тип сжатия: gzip, bzip2, xz (по умолчанию: gzip)
    -f, --config FILE      Файл конфигурации
    -v, --verbose          Подробный вывод
    --dry-run              Показать что будет выполнено без выполнения
    --help                 Показать эту справку

Примеры:
    $0 --mode full-cycle -h 192.168.1.100 -k ~/.ssh/id_rsa
    $0 --mode restore -h server.example.com -f restore.conf
    $0 --mode check -h 192.168.1.100 -v
EOF
}

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            BACKUP_MODE="$2"
            shift 2
            ;;
        -h|--host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -p|--port)
            REMOTE_PORT="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--compression)
            COMPRESSION="$2"
            shift 2
            ;;
        -f|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Проверка режима работы
case $BACKUP_MODE in
    backup|restore|check|full-cycle)
        ;;
    *)
        echo "Ошибка: Неверный режим работы: $BACKUP_MODE"
        echo "Допустимые режимы: backup, restore, check, full-cycle"
        exit 1
        ;;
esac

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Загрузка конфигурации из файла
load_config() {
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        log "Загрузка конфигурации из файла: $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Проверка обязательных параметров
check_required_params() {
    if [[ -z "$REMOTE_HOST" ]]; then
        echo "Ошибка: Не указан удаленный хост"
        show_help
        exit 1
    fi
    
    if [[ "$BACKUP_MODE" == "restore" && -z "$CONFIG_FILE" ]]; then
        echo "Ошибка: Для режима восстановления требуется файл конфигурации"
        show_help
        exit 1
    fi
}

# Выполнение проверки системы
run_system_check() {
    log "Выполнение проверки системы..."
    
    local check_cmd="./system_check.sh -h $REMOTE_HOST -u $REMOTE_USER -p $REMOTE_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        check_cmd="$check_cmd -k $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        check_cmd="$check_cmd -v"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: $check_cmd"
        return 0
    fi
    
    if eval "$check_cmd"; then
        log "✓ Проверка системы пройдена успешно"
        return 0
    else
        log "✗ Проверка системы не пройдена"
        return 1
    fi
}

# Выполнение бэкапа системы
run_backup() {
    log "Выполнение бэкапа системы..."
    
    local backup_cmd="./backup_system.sh -h $REMOTE_HOST -u $REMOTE_USER -p $REMOTE_PORT -d $BACKUP_DIR -c $COMPRESSION"
    
    if [[ -n "$SSH_KEY" ]]; then
        backup_cmd="$backup_cmd -k $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        backup_cmd="$backup_cmd -v"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        backup_cmd="$backup_cmd --dry-run"
    fi
    
    if eval "$backup_cmd"; then
        log "✓ Бэкап системы выполнен успешно"
        return 0
    else
        log "✗ Бэкап системы не выполнен"
        return 1
    fi
}

# Выполнение восстановления системы
run_restore() {
    log "Выполнение восстановления системы..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "✗ Файл конфигурации не найден: $CONFIG_FILE"
        return 1
    fi
    
    # Загрузка параметров восстановления из конфигурации
    source "$CONFIG_FILE"
    
    if [[ -z "$BACKUP_FILE" || -z "$TARGET_DEVICE" ]]; then
        log "✗ В файле конфигурации не указаны обязательные параметры"
        return 1
    fi
    
    local restore_cmd="./restore_system.sh -b $BACKUP_FILE -t $REMOTE_HOST -d $TARGET_DEVICE -u $REMOTE_USER -p $REMOTE_PORT"
    
    if [[ -n "$SSH_KEY" ]]; then
        restore_cmd="$restore_cmd -k $SSH_KEY"
    fi
    
    if [[ -n "$NEW_HOSTNAME" ]]; then
        restore_cmd="$restore_cmd -H $NEW_HOSTNAME"
    fi
    
    if [[ -n "$NEW_IP" ]]; then
        restore_cmd="$restore_cmd -i $NEW_IP"
    fi
    
    if [[ -n "$NEW_NETMASK" ]]; then
        restore_cmd="$restore_cmd -m $NEW_NETMASK"
    fi
    
    if [[ -n "$NEW_GATEWAY" ]]; then
        restore_cmd="$restore_cmd -g $NEW_GATEWAY"
    fi
    
    if [[ -n "$NEW_DNS" ]]; then
        restore_cmd="$restore_cmd -n $NEW_DNS"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        restore_cmd="$restore_cmd -v"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        restore_cmd="$restore_cmd --dry-run"
    fi
    
    if eval "$restore_cmd"; then
        log "✓ Восстановление системы выполнено успешно"
        return 0
    else
        log "✗ Восстановление системы не выполнено"
        return 1
    fi
}

# Создание файла конфигурации для восстановления
create_restore_config() {
    local config_file="$1"
    
    log "Создание файла конфигурации для восстановления: $config_file"
    
    cat > "$config_file" << 'EOF'
# Конфигурация для восстановления системы
# Измените значения под ваши требования

# Файл бэкапа
BACKUP_FILE=""

# Целевое устройство для восстановления
TARGET_DEVICE="/dev/sda"

# Новые сетевые настройки (необязательно)
NEW_HOSTNAME=""
NEW_IP=""
NEW_NETMASK="255.255.255.0"
NEW_GATEWAY=""
NEW_DNS="8.8.8.8,8.8.4.4"

# Дополнительные параметры
SKIP_NETWORK_CONFIG=false
EOF
    
    log "Файл конфигурации создан. Отредактируйте его перед использованием."
}

# Основная функция
main() {
    log "Запуск автоматизации бэкапа/восстановления..."
    log "Режим работы: $BACKUP_MODE"
    log "Целевой хост: $REMOTE_HOST"
    
    # Загрузка конфигурации
    load_config
    
    # Проверка параметров
    check_required_params
    
    case $BACKUP_MODE in
        check)
            run_system_check
            ;;
        backup)
            if run_system_check; then
                run_backup
            else
                log "Проверка системы не пройдена, бэкап отменен"
                exit 1
            fi
            ;;
        restore)
            run_restore
            ;;
        full-cycle)
            log "Выполнение полного цикла..."
            
            # Шаг 1: Проверка системы
            if ! run_system_check; then
                log "Проверка системы не пройдена, цикл прерван"
                exit 1
            fi
            
            # Шаг 2: Создание бэкапа
            if ! run_backup; then
                log "Бэкап не выполнен, цикл прерван"
                exit 1
            fi
            
            # Шаг 3: Повторная проверка системы
            log "Повторная проверка системы после бэкапа..."
            if ! run_system_check; then
                log "⚠ Система изменилась после бэкапа"
            else
                log "✓ Система стабильна после бэкапа"
            fi
            
            log "Полный цикл завершен успешно"
            ;;
    esac
}

# Обработка ошибок
trap 'log "Ошибка в строке $LINENO. Выход."; exit 1' ERR

# Запуск основной функции
main 