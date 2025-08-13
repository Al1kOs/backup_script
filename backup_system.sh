#!/bin/bash

# Скрипт для бэкапа Linux системы через SSH
# Использует dd для создания образа диска и архиватор для сжатия

set -e

# Конфигурация
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SSH_KEY=""
BACKUP_DIR="./backups"
COMPRESSION="gzip"  # gzip, bzip2, xz
VERBOSE=false
DRY_RUN=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -h, --host HOST        IP адрес или hostname удаленного сервера
    -u, --user USER        Пользователь для SSH (по умолчанию: root)
    -p, --port PORT        SSH порт (по умолчанию: 22)
    -k, --key KEY          Путь к SSH ключу
    -d, --dir DIR          Директория для сохранения бэкапов (по умолчанию: ./backups)
    -c, --compression TYPE Тип сжатия: gzip, bzip2, xz (по умолчанию: gzip)
    -v, --verbose          Подробный вывод
    --dry-run              Показать что будет выполнено без выполнения
    --help                 Показать эту справку

Примеры:
    $0 -h 192.168.1.100 -u admin -k ~/.ssh/id_rsa
    $0 -h server.example.com -d /mnt/backups -c xz
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
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--compression)
            COMPRESSION="$2"
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

# Функция для копирования файлов с удаленного сервера
remote_copy() {
    local src="$1"
    local dst="$2"
    local scp_opts=""
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_opts="-i $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        scp $scp_opts -P "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$src" "$dst"
    else
        scp $scp_opts -P "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST:$src" "$dst" 2>/dev/null
    fi
}

# Создание директории для бэкапов
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$BACKUP_DIR"
fi

# Получение информации о системе
log "Получение информации о системе..."
if [[ "$DRY_RUN" == false ]]; then
    SYSTEM_INFO=$(remote_exec "cat /etc/os-release | grep -E '^(NAME|VERSION)' | head -2")
    DISK_INFO=$(remote_exec "lsblk -d -o NAME,SIZE,TYPE | grep disk")
    PARTITION_INFO=$(remote_exec "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E '^(sd|hd|nvme)'")
    
    echo "Информация о системе:"
    echo "$SYSTEM_INFO"
    echo "Информация о дисках:"
    echo "$DISK_INFO"
    echo "Информация о разделах:"
    echo "$PARTITION_INFO"
fi

# Определение корневого раздела
log "Определение корневого раздела..."
if [[ "$DRY_RUN" == false ]]; then
    ROOT_DEVICE=$(remote_exec "df / | tail -1 | awk '{print \$1}'")
    ROOT_SIZE=$(remote_exec "df / | tail -1 | awk '{print \$2}'")
    log "Корневой раздел: $ROOT_DEVICE (размер: $ROOT_SIZE блоков)"
fi

# Создание метаданных бэкапа
BACKUP_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_NAME="system_backup_${BACKUP_TIMESTAMP}"
META_FILE="$BACKUP_DIR/${BACKUP_NAME}.meta"

if [[ "$DRY_RUN" == false ]]; then
    cat > "$META_FILE" << EOF
# Метаданные бэкапа системы
TIMESTAMP=$BACKUP_TIMESTAMP
HOSTNAME=$REMOTE_HOST
USER=$REMOTE_USER
ROOT_DEVICE=$ROOT_DEVICE
ROOT_SIZE=$ROOT_SIZE
COMPRESSION=$COMPRESSION
BACKUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Информация о системе
$(remote_exec "uname -a")

# Информация о дисках
$(remote_exec "lsblk -d -o NAME,SIZE,TYPE | grep disk")

# Информация о разделах
$(remote_exec "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E '^(sd|hd|nvme)'")

# Сетевые настройки
$(remote_exec "ip addr show | grep -E 'inet ' | grep -v '127.0.0.1'")

# Монтированные файловые системы
$(remote_exec "mount | grep -E '^(/dev|/sys|/proc)'")
EOF
fi

# Создание бэкапа с помощью dd
log "Создание образа системы с помощью dd..."
if [[ "$DRY_RUN" == false ]]; then
    # Создание временного файла на удаленном сервере
    TEMP_IMAGE="/tmp/${BACKUP_NAME}.img"
    
    log "Создание образа диска..."
    remote_exec "dd if=$ROOT_DEVICE of=$TEMP_IMAGE bs=4M status=progress"
    
    # Копирование образа локально
    log "Копирование образа локально..."
    remote_copy "$TEMP_IMAGE" "$BACKUP_DIR/"
    
    # Удаление временного файла
    remote_exec "rm -f $TEMP_IMAGE"
    
    # Сжатие образа
    log "Сжатие образа..."
    case $COMPRESSION in
        gzip)
            gzip "$BACKUP_DIR/${BACKUP_NAME}.img"
            ;;
        bzip2)
            bzip2 "$BACKUP_DIR/${BACKUP_NAME}.img"
            ;;
        xz)
            xz "$BACKUP_DIR/${BACKUP_NAME}.img"
            ;;
        *)
            echo "Неизвестный тип сжатия: $COMPRESSION"
            exit 1
            ;;
    esac
    
    # Создание контрольной суммы
    log "Создание контрольной суммы..."
    cd "$BACKUP_DIR"
    sha256sum "${BACKUP_NAME}.img.${COMPRESSION}" > "${BACKUP_NAME}.img.${COMPRESSION}.sha256"
    
    log "Бэкап завершен: $BACKUP_DIR/${BACKUP_NAME}.img.${COMPRESSION}"
    log "Размер файла: $(du -h "${BACKUP_NAME}.img.${COMPRESSION}" | cut -f1)"
else
    log "DRY RUN: Был бы создан бэкап $BACKUP_NAME"
    log "DRY RUN: Использовался бы раздел $ROOT_DEVICE"
    log "DRY RUN: Сжатие: $COMPRESSION"
fi

log "Бэкап системы завершен успешно!" 