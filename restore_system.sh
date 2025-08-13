#!/bin/bash

# Скрипт для восстановления Linux системы из бэкапа
# Поддерживает изменение IP, hostname и других сетевых настроек

set -e

# Конфигурация
BACKUP_FILE=""
TARGET_HOST=""
TARGET_USER="root"
TARGET_PORT="22"
SSH_KEY=""
TARGET_DEVICE=""
NEW_HOSTNAME=""
NEW_IP=""
NEW_NETMASK=""
NEW_GATEWAY=""
NEW_DNS=""
VERBOSE=false
DRY_RUN=false
SKIP_NETWORK_CONFIG=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Обязательные опции:
    -b, --backup FILE      Путь к файлу бэкапа (.img.gz, .img.bz2, .img.xz)
    -t, --target HOST      IP адрес или hostname целевого сервера
    -d, --device DEVICE    Целевое устройство для восстановления (например: /dev/sda)

Опции восстановления:
    -u, --user USER        Пользователь для SSH (по умолчанию: root)
    -p, --port PORT        SSH порт (по умолчанию: 22)
    -k, --key KEY          Путь к SSH ключу

Опции сетевой конфигурации:
    -H, --hostname NAME    Новый hostname
    -i, --ip IP            Новый IP адрес
    -m, --netmask MASK     Новая маска подсети
    -g, --gateway GW       Новый шлюз
    -n, --dns DNS          Новые DNS серверы (через запятую)
    --skip-network         Пропустить настройку сети

Другие опции:
    -v, --verbose          Подробный вывод
    --dry-run              Показать что будет выполнено без выполнения
    --help                 Показать эту справку

Примеры:
    $0 -b ./backups/system_backup_20231201_120000.img.gz -t 192.168.1.100 -d /dev/sda
    $0 -b backup.img.gz -t server.example.com -d /dev/sda -H newserver -i 192.168.1.200
EOF
}

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET_HOST="$2"
            shift 2
            ;;
        -d|--device)
            TARGET_DEVICE="$2"
            shift 2
            ;;
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        -p|--port)
            TARGET_PORT="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -H|--hostname)
            NEW_HOSTNAME="$2"
            shift 2
            ;;
        -i|--ip)
            NEW_IP="$2"
            shift 2
            ;;
        -m|--netmask)
            NEW_NETMASK="$2"
            shift 2
            ;;
        -g|--gateway)
            NEW_GATEWAY="$2"
            shift 2
            ;;
        -n|--dns)
            NEW_DNS="$2"
            shift 2
            ;;
        --skip-network)
            SKIP_NETWORK_CONFIG=true
            shift
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

# Проверка обязательных параметров
if [[ -z "$BACKUP_FILE" ]]; then
    echo "Ошибка: Не указан файл бэкапа"
    show_help
    exit 1
fi

if [[ -z "$TARGET_HOST" ]]; then
    echo "Ошибка: Не указан целевой хост"
    show_help
    exit 1
fi

if [[ -z "$TARGET_DEVICE" ]]; then
    echo "Ошибка: Не указано целевое устройство"
    show_help
    exit 1
fi

# Проверка существования файла бэкапа
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Ошибка: Файл бэкапа не найден: $BACKUP_FILE"
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
        ssh $ssh_opts -p "$TARGET_PORT" "$TARGET_USER@$TARGET_HOST" "$cmd"
    else
        ssh $ssh_opts -p "$TARGET_PORT" "$TARGET_USER@$TARGET_HOST" "$cmd" 2>/dev/null
    fi
}

# Функция для копирования файлов на удаленный сервер
remote_copy() {
    local src="$1"
    local dst="$2"
    local scp_opts=""
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_opts="-i $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        scp $scp_opts -P "$TARGET_PORT" "$src" "$TARGET_USER@$TARGET_HOST:$dst"
    else
        scp $scp_opts -P "$TARGET_PORT" "$src" "$TARGET_USER@$TARGET_HOST:$dst" 2>/dev/null
    fi
}

# Определение типа сжатия и распаковка
get_compression_type() {
    local file="$1"
    case "$file" in
        *.gz) echo "gzip" ;;
        *.bz2) echo "bzip2" ;;
        *.xz) echo "xz" ;;
        *) echo "none" ;;
    esac
}

# Проверка контрольной суммы
verify_backup() {
    local backup_file="$1"
    local sha256_file="${backup_file}.sha256"
    
    if [[ -f "$sha256_file" ]]; then
        log "Проверка контрольной суммы..."
        if [[ "$DRY_RUN" == false ]]; then
            cd "$(dirname "$backup_file")"
            if sha256sum -c "$(basename "$sha256_file")"; then
                log "Контрольная сумма проверена успешно"
            else
                echo "Ошибка: Контрольная сумма не совпадает"
                exit 1
            fi
        else
            log "DRY RUN: Проверка контрольной суммы"
        fi
    else
        log "Файл контрольной суммы не найден, пропускаем проверку"
    fi
}

# Восстановление системы
restore_system() {
    local backup_file="$1"
    local compression_type=$(get_compression_type "$backup_file")
    
    log "Начинаем восстановление системы..."
    log "Файл бэкапа: $backup_file"
    log "Тип сжатия: $compression_type"
    log "Целевое устройство: $TARGET_DEVICE"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Копирование файла бэкапа на целевой сервер
        log "Копирование файла бэкапа на целевой сервер..."
        remote_copy "$backup_file" "/tmp/"
        
        # Распаковка и восстановление
        log "Распаковка и восстановление образа..."
        case $compression_type in
            gzip)
                remote_exec "gunzip -c /tmp/$(basename "$backup_file") | dd of=$TARGET_DEVICE bs=4M status=progress"
                ;;
            bzip2)
                remote_exec "bunzip2 -c /tmp/$(basename "$backup_file") | dd of=$TARGET_DEVICE bs=4M status=progress"
                ;;
            xz)
                remote_exec "unxz -c /tmp/$(basename "$backup_file") | dd of=$TARGET_DEVICE bs=4M status=progress"
                ;;
            none)
                remote_exec "dd if=/tmp/$(basename "$backup_file") of=$TARGET_DEVICE bs=4M status=progress"
                ;;
        esac
        
        # Синхронизация диска
        log "Синхронизация диска..."
        remote_exec "sync"
        
        # Очистка временных файлов
        remote_exec "rm -f /tmp/$(basename "$backup_file")"
        
        log "Восстановление образа завершено"
    else
        log "DRY RUN: Восстановление образа $backup_file на $TARGET_DEVICE"
    fi
}

# Настройка сети
configure_network() {
    if [[ "$SKIP_NETWORK_CONFIG" == true ]]; then
        log "Пропускаем настройку сети"
        return
    fi
    
    if [[ -z "$NEW_HOSTNAME" && -z "$NEW_IP" ]]; then
        log "Новые сетевые настройки не указаны, пропускаем настройку"
        return
    fi
    
    log "Настройка сетевых параметров..."
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание скрипта для настройки сети
        cat > /tmp/network_config.sh << 'EOF'
#!/bin/bash
set -e

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Изменение hostname
if [[ -n "$NEW_HOSTNAME" ]]; then
    log "Изменение hostname на: $NEW_HOSTNAME"
    echo "$NEW_HOSTNAME" > /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
fi

# Определение основного сетевого интерфейса
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -z "$MAIN_INTERFACE" ]]; then
    MAIN_INTERFACE=$(ls /sys/class/net/ | grep -E '^(eth|en|ens|eno)' | head -1)
fi

if [[ -n "$MAIN_INTERFACE" ]]; then
    log "Основной интерфейс: $MAIN_INTERFACE"
    
    # Настройка IP адреса
    if [[ -n "$NEW_IP" ]]; then
        log "Настройка IP адреса: $NEW_IP"
        
        # Определение типа дистрибутива
        if [[ -f /etc/debian_version ]]; then
            # Debian/Ubuntu
            cat > /etc/network/interfaces.d/restore_backup << EOF
auto $MAIN_INTERFACE
iface $MAIN_INTERFACE inet static
    address $NEW_IP
    netmask ${NEW_NETMASK:-255.255.255.0}
    gateway ${NEW_GATEWAY}
    dns-nameservers ${NEW_DNS:-8.8.8.8 8.8.4.4}
EOF
        elif [[ -f /etc/redhat-release ]]; then
            # RHEL/CentOS
            cat > /etc/sysconfig/network-scripts/ifcfg-$MAIN_INTERFACE << EOF
DEVICE=$MAIN_INTERFACE
BOOTPROTO=static
ONBOOT=yes
IPADDR=$NEW_IP
NETMASK=${NEW_NETMASK:-255.255.255.0}
GATEWAY=${NEW_GATEWAY}
DNS1=${NEW_DNS:-8.8.8.8}
DNS2=8.8.4.4
EOF
        elif [[ -f /etc/systemd/system.conf ]]; then
            # Systemd-based
            cat > /etc/systemd/network/restore_backup.network << EOF
[Match]
Name=$MAIN_INTERFACE

[Network]
Address=$NEW_IP/${NEW_NETMASK:-24}
Gateway=${NEW_GATEWAY}
DNS=${NEW_DNS:-8.8.8.8}
EOF
        fi
    fi
else
    log "Не удалось определить основной сетевой интерфейс"
fi

log "Сетевая конфигурация завершена"
EOF
        
        # Копирование скрипта на целевой сервер
        remote_copy "/tmp/network_config.sh" "/tmp/"
        
        # Выполнение скрипта
        remote_exec "chmod +x /tmp/network_config.sh"
        remote_exec "NEW_HOSTNAME='$NEW_HOSTNAME' NEW_IP='$NEW_IP' NEW_NETMASK='$NEW_NETMASK' NEW_GATEWAY='$NEW_GATEWAY' NEW_DNS='$NEW_DNS' /tmp/network_config.sh"
        
        # Очистка
        remote_exec "rm -f /tmp/network_config.sh"
        rm -f /tmp/network_config.sh
        
        log "Сетевые настройки применены"
    else
        log "DRY RUN: Настройка сети"
        if [[ -n "$NEW_HOSTNAME" ]]; then
            log "DRY RUN: Новый hostname: $NEW_HOSTNAME"
        fi
        if [[ -n "$NEW_IP" ]]; then
            log "DRY RUN: Новый IP: $NEW_IP"
        fi
    fi
}

# Основная функция
main() {
    log "Начинаем процесс восстановления системы..."
    
    # Проверка контрольной суммы
    verify_backup "$BACKUP_FILE"
    
    # Восстановление системы
    restore_system "$BACKUP_FILE"
    
    # Настройка сети
    configure_network
    
    log "Восстановление системы завершено успешно!"
    log "Не забудьте перезагрузить систему для применения изменений"
}

# Запуск основной функции
main 