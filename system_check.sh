#!/bin/bash

# Скрипт для проверки системы перед созданием бэкапа
# Проверяет доступное место, права доступа, сетевые настройки

set -e

# Конфигурация
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SSH_KEY=""
VERBOSE=false
MIN_DISK_SPACE_GB=10
MIN_RAM_GB=1

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -h, --host HOST        IP адрес или hostname удаленного сервера
    -u, --user USER        Пользователь для SSH (по умолчанию: root)
    -p, --port PORT        SSH порт (по умолчанию: 22)
    -k, --key KEY          Путь к SSH ключу
    -d, --disk-space GB    Минимальное свободное место в GB (по умолчанию: 10)
    -r, --ram GB           Минимальный объем RAM в GB (по умолчанию: 1)
    -v, --verbose          Подробный вывод
    --help                 Показать эту справку

Примеры:
    $0 -h 192.168.1.100 -d 20 -r 2
    $0 -h server.example.com -k ~/.ssh/id_rsa -v
EOF
}

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
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
        -d|--disk-space)
            MIN_DISK_SPACE_GB="$2"
            shift 2
            ;;
        -r|--ram)
            MIN_RAM_GB="$2"
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
done

# Проверка обязательных параметров
if [[ -z "$REMOTE_HOST" ]]; then
    echo "Ошибка: Не указан удаленный хост"
    show_help
    exit 1
fi

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция для выполнения команд на удаленном сервере
remote_exec() {
    local cmd="$1"
    local ssh_opts=""
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="-i $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        ssh $ssh_opts -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "$cmd"
    else
        ssh $ssh_opts -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "$cmd" 2>/dev/null
    fi
}

# Проверка SSH соединения
check_ssh_connection() {
    log "Проверка SSH соединения..."
    
    if remote_exec "echo 'SSH соединение установлено'" > /dev/null 2>&1; then
        log "✓ SSH соединение успешно установлено"
        return 0
    else
        log "✗ Ошибка SSH соединения"
        return 1
    fi
}

# Проверка прав доступа
check_permissions() {
    log "Проверка прав доступа..."
    
    # Проверка прав root
    if remote_exec "id -u" | grep -q "^0$"; then
        log "✓ Пользователь имеет права root"
    else
        log "✗ Пользователь не имеет прав root"
        return 1
    fi
    
    # Проверка доступа к /dev
    if remote_exec "ls /dev/sda" > /dev/null 2>&1; then
        log "✓ Доступ к блочным устройствам"
    else
        log "✗ Нет доступа к блочным устройствам"
        return 1
    fi
    
    return 0
}

# Проверка доступного места на диске
check_disk_space() {
    log "Проверка доступного места на диске..."
    
    local available_gb=$(remote_exec "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'")
    local total_gb=$(remote_exec "df -BG / | tail -1 | awk '{print \$2}' | sed 's/G//'")
    local used_gb=$(remote_exec "df -BG / | tail -1 | awk '{print \$3}' | sed 's/G//'")
    
    log "Общий объем диска: ${total_gb}GB"
    log "Использовано: ${used_gb}GB"
    log "Доступно: ${available_gb}GB"
    
    if [[ "$available_gb" -ge "$MIN_DISK_SPACE_GB" ]]; then
        log "✓ Достаточно свободного места (${available_gb}GB >= ${MIN_DISK_SPACE_GB}GB)"
        return 0
    else
        log "✗ Недостаточно свободного места (${available_gb}GB < ${MIN_DISK_SPACE_GB}GB)"
        return 1
    fi
}

# Проверка объема RAM
check_ram() {
    log "Проверка объема RAM..."
    
    local total_ram_kb=$(remote_exec "grep MemTotal /proc/meminfo | awk '{print \$2}'")
    local total_ram_gb=$((total_ram_kb / 1024 / 1024))
    
    log "Общий объем RAM: ${total_ram_gb}GB"
    
    if [[ "$total_ram_gb" -ge "$MIN_RAM_GB" ]]; then
        log "✓ Достаточно RAM (${total_ram_gb}GB >= ${MIN_RAM_GB}GB)"
        return 0
    else
        log "✗ Недостаточно RAM (${total_ram_gb}GB < ${MIN_RAM_GB}GB)"
        return 1
    fi
}

# Проверка необходимых утилит
check_utilities() {
    log "Проверка необходимых утилит..."
    
    local missing_utils=""
    
    # Проверка dd
    if ! remote_exec "which dd" > /dev/null 2>&1; then
        missing_utils="$missing_utils dd"
    fi
    
    # Проверка lsblk
    if ! remote_exec "which lsblk" > /dev/null 2>&1; then
        missing_utils="$missing_utils lsblk"
    fi
    
    # Проверка df
    if ! remote_exec "which df" > /dev/null 2>&1; then
        missing_utils="$missing_utils df"
    fi
    
    # Проверка mount
    if ! remote_exec "which mount" > /dev/null 2>&1; then
        missing_utils="$missing_utils mount"
    fi
    
    if [[ -z "$missing_utils" ]]; then
        log "✓ Все необходимые утилиты доступны"
        return 0
    else
        log "✗ Отсутствуют утилиты: $missing_utils"
        return 1
    fi
}

# Проверка сетевых настроек
check_network() {
    log "Проверка сетевых настроек..."
    
    # Проверка доступности интернет
    if remote_exec "ping -c 1 8.8.8.8" > /dev/null 2>&1; then
        log "✓ Интернет доступен"
    else
        log "⚠ Интернет недоступен (может быть нормально для внутренних серверов)"
    fi
    
    # Проверка DNS
    if remote_exec "nslookup google.com" > /dev/null 2>&1; then
        log "✓ DNS работает"
    else
        log "⚠ DNS не работает"
    fi
    
    # Информация о сетевых интерфейсах
    log "Сетевые интерфейсы:"
    remote_exec "ip addr show | grep -E '^[0-9]+:' | awk '{print \$2}' | sed 's/://'" | while read interface; do
        local ip=$(remote_exec "ip addr show $interface | grep -E 'inet ' | awk '{print \$2}' | head -1")
        if [[ -n "$ip" ]]; then
            log "  $interface: $ip"
        fi
    done
    
    return 0
}

# Проверка системы
check_system_info() {
    log "Проверка информации о системе..."
    
    # Информация о дистрибутиве
    local distro_info=$(remote_exec "cat /etc/os-release | grep -E '^(NAME|VERSION)' | head -2")
    log "Дистрибутив:"
    echo "$distro_info" | while read line; do
        log "  $line"
    done
    
    # Информация о ядре
    local kernel_info=$(remote_exec "uname -r")
    log "Версия ядра: $kernel_info"
    
    # Информация об архитектуре
    local arch_info=$(remote_exec "uname -m")
    log "Архитектура: $arch_info"
    
    # Время работы системы
    local uptime_info=$(remote_exec "uptime -p")
    log "Время работы: $uptime_info"
    
    return 0
}

# Проверка процессов
check_processes() {
    log "Проверка критических процессов..."
    
    local critical_services=("sshd" "systemd" "init")
    local missing_services=""
    
    for service in "${critical_services[@]}"; do
        if remote_exec "pgrep $service" > /dev/null 2>&1; then
            log "✓ Сервис $service работает"
        else
            log "✗ Сервис $service не работает"
            missing_services="$missing_services $service"
        fi
    done
    
    if [[ -n "$missing_services" ]]; then
        log "⚠ Отсутствуют критические сервисы: $missing_services"
        return 1
    fi
    
    return 0
}

# Основная функция проверки
main() {
    log "Начинаем проверку системы $REMOTE_HOST..."
    
    local exit_code=0
    
    # Проверка SSH соединения
    if ! check_ssh_connection; then
        exit_code=1
        log "Проверка SSH соединения не пройдена"
    fi
    
    # Проверка прав доступа
    if ! check_permissions; then
        exit_code=1
        log "Проверка прав доступа не пройдена"
    fi
    
    # Проверка места на диске
    if ! check_disk_space; then
        exit_code=1
        log "Проверка места на диске не пройдена"
    fi
    
    # Проверка RAM
    if ! check_ram; then
        exit_code=1
        log "Проверка RAM не пройдена"
    fi
    
    # Проверка утилит
    if ! check_utilities; then
        exit_code=1
        log "Проверка утилит не пройдена"
    fi
    
    # Проверка сети
    check_network
    
    # Проверка информации о системе
    check_system_info
    
    # Проверка процессов
    if ! check_processes; then
        exit_code=1
        log "Проверка процессов не пройдена"
    fi
    
    # Итоговый результат
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log "✓ Все проверки пройдены успешно. Система готова к бэкапу."
    else
        log "✗ Некоторые проверки не пройдены. Рекомендуется исправить проблемы перед созданием бэкапа."
    fi
    
    return $exit_code
}

# Запуск основной функции
main 