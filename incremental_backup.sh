#!/bin/bash

# Скрипт для инкрементных бэкапов Linux системы через SSH
# Использует rsync для инкрементных бэкапов и tar для архивирования

set -e

# Конфигурация
REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_PORT="22"
SSH_KEY=""
BACKUP_DIR="./incremental_backups"
BACKUP_TYPE="full"  # full, incremental, differential
RETENTION_DAYS=30
EXCLUDE_FILE=""
VERBOSE=false
DRY_RUN=false
COMPRESSION="gzip"

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -h, --host HOST        IP адрес или hostname удаленного сервера
    -u, --user USER        Пользователь для SSH (по умолчанию: root)
    -p, --port PORT        SSH порт (по умолчанию: 22)
    -k, --key KEY          Путь к SSH ключу
    -d, --dir DIR          Директория для сохранения бэкапов (по умолчанию: ./incremental_backups)
    -t, --type TYPE        Тип бэкапа: full, incremental, differential (по умолчанию: full)
    -r, --retention DAYS   Количество дней хранения бэкапов (по умолчанию: 30)
    -e, --exclude FILE     Файл с исключениями
    -c, --compression TYPE Тип сжатия: gzip, bzip2, xz (по умолчанию: gzip)
    -v, --verbose          Подробный вывод
    --dry-run              Показать что будет выполнено без выполнения
    --help                 Показать эту справку

Примеры:
    $0 -h 192.168.1.100 -t full -r 60
    $0 -h server.example.com -t incremental -e excludes.txt
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
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_FILE="$2"
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

# Проверка типа бэкапа
case $BACKUP_TYPE in
    full|incremental|differential)
        ;;
    *)
        echo "Ошибка: Неверный тип бэкапа: $BACKUP_TYPE"
        echo "Допустимые типы: full, incremental, differential"
        exit 1
        ;;
esac

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

# Создание директорий для бэкапов
create_backup_dirs() {
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$BACKUP_DIR"
        mkdir -p "$BACKUP_DIR/full"
        mkdir -p "$BACKUP_DIR/incremental"
        mkdir -p "$BACKUP_DIR/differential"
        mkdir -p "$BACKUP_DIR/metadata"
    fi
}

# Получение информации о системе
get_system_info() {
    log "Получение информации о системе..."
    if [[ "$DRY_RUN" == false ]]; then
        SYSTEM_INFO=$(remote_exec "cat /etc/os-release | grep -E '^(NAME|VERSION)' | head -2")
        DISK_INFO=$(remote_exec "df -h /")
        PARTITION_INFO=$(remote_exec "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E '^(sd|hd|nvme)'")
        
        echo "Информация о системе:"
        echo "$SYSTEM_INFO"
        echo "Информация о диске:"
        echo "$DISK_INFO"
        echo "Информация о разделах:"
        echo "$PARTITION_INFO"
    fi
}

# Создание файла исключений по умолчанию
create_default_excludes() {
    if [[ -z "$EXCLUDE_FILE" ]]; then
        EXCLUDE_FILE="/tmp/default_excludes.txt"
        cat > "$EXCLUDE_FILE" << 'EOF'
# Стандартные исключения для бэкапа Linux системы
/proc/*
/sys/*
/dev/*
/tmp/*
/var/tmp/*
/var/cache/*
/var/log/*
/run/*
/mnt/*
/media/*
/lost+found
*.swp
*.tmp
*.log
.DS_Store
Thumbs.db
EOF
    fi
}

# Определение последнего полного бэкапа
get_last_full_backup() {
    local full_dir="$BACKUP_DIR/full"
    if [[ -d "$full_dir" ]]; then
        ls -t "$full_dir"/*.tar.* 2>/dev/null | head -1
    else
        echo ""
    fi
}

# Создание полного бэкапа
create_full_backup() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="full_backup_${timestamp}"
    local backup_file="$BACKUP_DIR/full/${backup_name}.tar"
    local metadata_file="$BACKUP_DIR/metadata/${backup_name}.meta"
    
    log "Создание полного бэкапа: $backup_name"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание метаданных
        cat > "$metadata_file" << EOF
TIMESTAMP=$timestamp
BACKUP_TYPE=full
HOSTNAME=$REMOTE_HOST
USER=$REMOTE_USER
BACKUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
COMPRESSION=$COMPRESSION
EOF
        
        # Создание бэкапа с помощью rsync и tar
        log "Создание архива системы..."
        rsync_opts=""
        if [[ -n "$SSH_KEY" ]]; then
            rsync_opts="-e 'ssh -i $SSH_KEY -p $REMOTE_PORT'"
        else
            rsync_opts="-e 'ssh -p $REMOTE_PORT'"
        fi
        
        # Создание списка файлов для бэкапа
        remote_exec "find / -type f -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' -not -path '/tmp/*' -not -path '/var/tmp/*' -not -path '/var/cache/*' -not -path '/var/log/*' -not -path '/run/*' -not -path '/mnt/*' -not -path '/media/*' -not -path '/lost+found' 2>/dev/null | head -10000" > /tmp/backup_files.txt
        
        # Создание tar архива
        tar_opts=""
        case $COMPRESSION in
            gzip) tar_opts="-czf" ;;
            bzip2) tar_opts="-cjf" ;;
            xz) tar_opts="-cJf" ;;
        esac
        
        if [[ -n "$EXCLUDE_FILE" && -f "$EXCLUDE_FILE" ]]; then
            tar $tar_opts "$backup_file" -X "$EXCLUDE_FILE" -T /tmp/backup_files.txt
        else
            tar $tar_opts "$backup_file" -T /tmp/backup_files.txt
        fi
        
        # Сжатие архива
        case $COMPRESSION in
            gzip)
                gzip "$backup_file"
                ;;
            bzip2)
                bzip2 "$backup_file"
                ;;
            xz)
                xz "$backup_file"
                ;;
        esac
        
        # Создание контрольной суммы
        cd "$BACKUP_DIR/full"
        sha256sum "${backup_name}.tar.${COMPRESSION}" > "${backup_name}.tar.${COMPRESSION}.sha256"
        
        # Очистка
        rm -f /tmp/backup_files.txt
        
        log "Полный бэкап завершен: ${backup_name}.tar.${COMPRESSION}"
        log "Размер файла: $(du -h "${backup_name}.tar.${COMPRESSION}" | cut -f1)"
        
        # Создание файла с временной меткой для инкрементных бэкапов
        echo "$timestamp" > "$BACKUP_DIR/metadata/last_full_backup"
    else
        log "DRY RUN: Создание полного бэкапа $backup_name"
    fi
}

# Создание инкрементного бэкапа
create_incremental_backup() {
    local last_full=$(cat "$BACKUP_DIR/metadata/last_full_backup" 2>/dev/null || echo "")
    if [[ -z "$last_full" ]]; then
        log "Полный бэкап не найден, создаем полный бэкап..."
        create_full_backup
        return
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="incremental_backup_${timestamp}"
    local backup_file="$BACKUP_DIR/incremental/${backup_name}.tar"
    local metadata_file="$BACKUP_DIR/metadata/${backup_name}.meta"
    
    log "Создание инкрементного бэкапа: $backup_name"
    log "Базовый бэкап: $last_full"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание метаданных
        cat > "$metadata_file" << EOF
TIMESTAMP=$timestamp
BACKUP_TYPE=incremental
BASE_BACKUP=$last_full
HOSTNAME=$REMOTE_HOST
USER=$REMOTE_USER
BACKUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
COMPRESSION=$COMPRESSION
EOF
        
        # Создание инкрементного бэкапа
        log "Создание инкрементного архива..."
        
        # Получение списка измененных файлов
        remote_exec "find / -type f -newer /tmp/backup_timestamp -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' -not -path '/tmp/*' -not -path '/var/tmp/*' -not -path '/var/cache/*' -not -path '/var/log/*' -not -path '/run/*' -not -path '/mnt/*' -not -path '/media/*' -not -path '/lost+found' 2>/dev/null" > /tmp/incremental_files.txt
        
        if [[ -s /tmp/incremental_files.txt ]]; then
            tar_opts=""
            case $COMPRESSION in
                gzip) tar_opts="-czf" ;;
                bzip2) tar_opts="-cjf" ;;
                xz) tar_opts="-cJf" ;;
            esac
            
            if [[ -n "$EXCLUDE_FILE" && -f "$EXCLUDE_FILE" ]]; then
                tar $tar_opts "$backup_file" -X "$EXCLUDE_FILE" -T /tmp/incremental_files.txt
            else
                tar $tar_opts "$backup_file" -T /tmp/incremental_files.txt
            fi
            
            # Сжатие архива
            case $COMPRESSION in
                gzip)
                    gzip "$backup_file"
                    ;;
                bzip2)
                    bzip2 "$backup_file"
                    ;;
                xz)
                    xz "$backup_file"
                    ;;
            esac
            
            # Создание контрольной суммы
            cd "$BACKUP_DIR/incremental"
            sha256sum "${backup_name}.tar.${COMPRESSION}" > "${backup_name}.tar.${COMPRESSION}.sha256"
            
            log "Инкрементный бэкап завершен: ${backup_name}.tar.${COMPRESSION}"
            log "Размер файла: $(du -h "${backup_name}.tar.${COMPRESSION}" | cut -f1)"
        else
            log "Нет измененных файлов для инкрементного бэкапа"
            rm -f "$metadata_file"
        fi
        
        # Очистка
        rm -f /tmp/incremental_files.txt
    else
        log "DRY RUN: Создание инкрементного бэкапа $backup_name"
    fi
}

# Создание дифференциального бэкапа
create_differential_backup() {
    local last_full=$(cat "$BACKUP_DIR/metadata/last_full_backup" 2>/dev/null || echo "")
    if [[ -z "$last_full" ]]; then
        log "Полный бэкап не найден, создаем полный бэкап..."
        create_full_backup
        return
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="differential_backup_${timestamp}"
    local backup_file="$BACKUP_DIR/differential/${backup_name}.tar"
    local metadata_file="$BACKUP_DIR/metadata/${backup_name}.meta"
    
    log "Создание дифференциального бэкапа: $backup_name"
    log "Базовый бэкап: $last_full"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание метаданных
        cat > "$metadata_file" << EOF
TIMESTAMP=$timestamp
BACKUP_TYPE=differential
BASE_BACKUP=$last_full
HOSTNAME=$REMOTE_HOST
USER=$REMOTE_USER
BACKUP_DATE=$(date '+%Y-%m-%d %H:%M:%S')
COMPRESSION=$COMPRESSION
EOF
        
        # Создание дифференциального бэкапа (все изменения с момента полного бэкапа)
        log "Создание дифференциального архива..."
        
        # Получение списка всех файлов, измененных с момента полного бэкапа
        remote_exec "find / -type f -newer /tmp/backup_timestamp -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' -not -path '/tmp/*' -not -path '/var/tmp/*' -not -path '/var/cache/*' -not -path '/var/log/*' -not -path '/run/*' -not -path '/mnt/*' -not -path '/media/*' -not -path '/lost+found' 2>/dev/null" > /tmp/differential_files.txt
        
        if [[ -s /tmp/differential_files.txt ]]; then
            tar_opts=""
            case $COMPRESSION in
                gzip) tar_opts="-czf" ;;
                bzip2) tar_opts="-cjf" ;;
                xz) tar_opts="-cJf" ;;
            esac
            
            if [[ -n "$EXCLUDE_FILE" && -f "$EXCLUDE_FILE" ]]; then
                tar $tar_opts "$backup_file" -X "$EXCLUDE_FILE" -T /tmp/differential_files.txt
            else
                tar $tar_opts "$backup_file" -T /tmp/differential_files.txt
            fi
            
            # Сжатие архива
            case $COMPRESSION in
                gzip)
                    gzip "$backup_file"
                    ;;
                bzip2)
                    bzip2 "$backup_file"
                    ;;
                xz)
                    xz "$backup_file"
                    ;;
            esac
            
            # Создание контрольной суммы
            cd "$BACKUP_DIR/differential"
            sha256sum "${backup_name}.tar.${COMPRESSION}" > "${backup_name}.tar.${COMPRESSION}.sha256"
            
            log "Дифференциальный бэкап завершен: ${backup_name}.tar.${COMPRESSION}"
            log "Размер файла: $(du -h "${backup_name}.tar.${COMPRESSION}" | cut -f1)"
        else
            log "Нет измененных файлов для дифференциального бэкапа"
            rm -f "$metadata_file"
        fi
        
        # Очистка
        rm -f /tmp/differential_files.txt
    else
        log "DRY RUN: Создание дифференциального бэкапа $backup_name"
    fi
}

# Очистка старых бэкапов
cleanup_old_backups() {
    log "Очистка бэкапов старше $RETENTION_DAYS дней..."
    
    if [[ "$DRY_RUN" == false ]]; then
        # Очистка полных бэкапов
        find "$BACKUP_DIR/full" -name "*.tar.*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find "$BACKUP_DIR/full" -name "*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Очистка инкрементных бэкапов
        find "$BACKUP_DIR/incremental" -name "*.tar.*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find "$BACKUP_DIR/incremental" -name "*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Очистка дифференциальных бэкапов
        find "$BACKUP_DIR/differential" -name "*.tar.*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        find "$BACKUP_DIR/differential" -name "*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        # Очистка метаданных
        find "$BACKUP_DIR/metadata" -name "*.meta" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        log "Очистка завершена"
    else
        log "DRY RUN: Очистка бэкапов старше $RETENTION_DAYS дней"
    fi
}

# Основная функция
main() {
    log "Начинаем процесс инкрементного бэкапа..."
    log "Тип бэкапа: $BACKUP_TYPE"
    log "Целевой хост: $REMOTE_HOST"
    
    # Создание директорий
    create_backup_dirs
    
    # Получение информации о системе
    get_system_info
    
    # Создание файла исключений
    create_default_excludes
    
    # Создание временной метки на удаленном сервере
    if [[ "$DRY_RUN" == false ]]; then
        remote_exec "touch /tmp/backup_timestamp"
    fi
    
    # Создание бэкапа в зависимости от типа
    case $BACKUP_TYPE in
        full)
            create_full_backup
            ;;
        incremental)
            create_incremental_backup
            ;;
        differential)
            create_differential_backup
            ;;
    esac
    
    # Очистка старых бэкапов
    cleanup_old_backups
    
    # Очистка временных файлов
    if [[ "$DRY_RUN" == false ]]; then
        rm -f "$EXCLUDE_FILE"
    fi
    
    log "Инкрементный бэкап завершен успешно!"
}

# Запуск основной функции
main 