#!/bin/bash

# Скрипт для изменения сетевых настроек при восстановлении бэкапов
# Поддерживает различные дистрибутивы Linux

set -e

# Конфигурация
NEW_HOSTNAME=""
NEW_IP=""
NEW_NETMASK="255.255.255.0"
NEW_GATEWAY=""
NEW_DNS="8.8.8.8,8.8.4.4"
INTERFACE=""
VERBOSE=false
DRY_RUN=false

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [опции]

Опции:
    -H, --hostname NAME    Новый hostname
    -i, --ip IP            Новый IP адрес
    -m, --netmask MASK     Новая маска подсети (по умолчанию: 255.255.255.0)
    -g, --gateway GW       Новый шлюз
    -n, --dns DNS          Новые DNS серверы через запятую (по умолчанию: 8.8.8.8,8.8.4.4)
    -I, --interface IFACE  Сетевой интерфейс (автоопределение если не указан)
    -v, --verbose          Подробный вывод
    --dry-run              Показать что будет выполнено без выполнения
    --help                 Показать эту справку

Примеры:
    $0 -H newserver -i 192.168.1.200
    $0 -H webserver -i 10.0.0.100 -g 10.0.0.1 -n 1.1.1.1,1.0.0.1
EOF
}

# Парсинг аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
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
        -I|--interface)
            INTERFACE="$2"
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
if [[ -z "$NEW_HOSTNAME" && -z "$NEW_IP" ]]; then
    echo "Ошибка: Не указан ни hostname, ни IP адрес"
    show_help
    exit 1
fi

# Функция для логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Определение типа дистрибутива
detect_distro() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    elif [[ -f /etc/SuSE-release ]]; then
        echo "suse"
    else
        echo "unknown"
    fi
}

# Определение основного сетевого интерфейса
detect_interface() {
    if [[ -n "$INTERFACE" ]]; then
        echo "$INTERFACE"
        return
    fi
    
    # Попытка определить интерфейс по маршруту по умолчанию
    local default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$default_interface" ]]; then
        echo "$default_interface"
        return
    fi
    
    # Поиск первого доступного интерфейса
    local first_interface=$(ls /sys/class/net/ | grep -E '^(eth|en|ens|eno|wlan|wlp)' | head -1)
    if [[ -n "$first_interface" ]]; then
        echo "$first_interface"
        return
    fi
    
    echo "eth0"  # fallback
}

# Изменение hostname
configure_hostname() {
    if [[ -z "$NEW_HOSTNAME" ]]; then
        return
    fi
    
    log "Изменение hostname на: $NEW_HOSTNAME"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Обновление /etc/hostname
        echo "$NEW_HOSTNAME" > /etc/hostname
        
        # Обновление /etc/hosts
        if [[ -f /etc/hosts ]]; then
            # Создание резервной копии
            cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
            
            # Обновление записи 127.0.1.1
            if grep -q "127.0.1.1" /etc/hosts; then
                sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
            else
                echo "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
            fi
            
            # Обновление записи 127.0.0.1 если есть
            if grep -q "127.0.0.1.*localhost" /etc/hosts; then
                sed -i "s/127.0.0.1.*localhost/127.0.0.1\tlocalhost\t$NEW_HOSTNAME/" /etc/hosts
            fi
        fi
        
        log "Hostname изменен на: $NEW_HOSTNAME"
    else
        log "DRY RUN: Изменение hostname на: $NEW_HOSTNAME"
    fi
}

# Настройка сети для Debian/Ubuntu
configure_network_debian() {
    local interface="$1"
    local config_file="/etc/network/interfaces.d/restore_backup"
    
    log "Настройка сети для Debian/Ubuntu на интерфейсе: $interface"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание конфигурации
        cat > "$config_file" << EOF
# Конфигурация сети для восстановленного бэкапа
auto $interface
iface $interface inet static
    address $NEW_IP
    netmask $NEW_NETMASK
EOF
        
        # Добавление шлюза если указан
        if [[ -n "$NEW_GATEWAY" ]]; then
            echo "    gateway $NEW_GATEWAY" >> "$config_file"
        fi
        
        # Добавление DNS если указан
        if [[ -n "$NEW_DNS" ]]; then
            # Замена запятых на пробелы для dns-nameservers
            local dns_servers=$(echo "$NEW_DNS" | tr ',' ' ')
            echo "    dns-nameservers $dns_servers" >> "$config_file"
        fi
        
        log "Конфигурация сети создана: $config_file"
    else
        log "DRY RUN: Создание конфигурации сети в $config_file"
    fi
}

# Настройка сети для RHEL/CentOS
configure_network_redhat() {
    local interface="$1"
    local config_file="/etc/sysconfig/network-scripts/ifcfg-$interface"
    
    log "Настройка сети для RHEL/CentOS на интерфейсе: $interface"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание резервной копии
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
        
        # Создание конфигурации
        cat > "$config_file" << EOF
# Конфигурация сети для восстановленного бэкапа
DEVICE=$interface
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=$NEW_IP
NETMASK=$NEW_NETMASK
EOF
        
        # Добавление шлюза если указан
        if [[ -n "$NEW_GATEWAY" ]]; then
            echo "GATEWAY=$NEW_GATEWAY" >> "$config_file"
        fi
        
        # Добавление DNS если указан
        if [[ -n "$NEW_DNS" ]]; then
            local dns_servers=($(echo "$NEW_DNS" | tr ',' ' '))
            echo "DNS1=${dns_servers[0]}" >> "$config_file"
            if [[ ${#dns_servers[@]} -gt 1 ]]; then
                echo "DNS2=${dns_servers[1]}" >> "$config_file"
            fi
        fi
        
        log "Конфигурация сети создана: $config_file"
    else
        log "DRY RUN: Создание конфигурации сети в $config_file"
    fi
}

# Настройка сети для systemd-networkd
configure_network_systemd() {
    local interface="$1"
    local config_file="/etc/systemd/network/restore_backup.network"
    
    log "Настройка сети для systemd-networkd на интерфейсе: $interface"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Создание конфигурации
        cat > "$config_file" << EOF
# Конфигурация сети для восстановленного бэкапа
[Match]
Name=$interface

[Network]
Address=$NEW_IP/$(ipcalc -m $NEW_IP $NEW_NETMASK | cut -d'/' -f2)
EOF
        
        # Добавление шлюза если указан
        if [[ -n "$NEW_GATEWAY" ]]; then
            echo "Gateway=$NEW_GATEWAY" >> "$config_file"
        fi
        
        # Добавление DNS если указан
        if [[ -n "$NEW_DNS" ]]; then
            local dns_servers=($(echo "$NEW_DNS" | tr ',' ' '))
            echo "DNS=${dns_servers[0]}" >> "$config_file"
        fi
        
        log "Конфигурация сети создана: $config_file"
    else
        log "DRY RUN: Создание конфигурации сети в $config_file"
    fi
}

# Настройка DNS
configure_dns() {
    if [[ -z "$NEW_DNS" ]]; then
        return
    fi
    
    log "Настройка DNS серверов: $NEW_DNS"
    
    if [[ "$DRY_RUN" == false ]]; then
        local dns_servers=($(echo "$NEW_DNS" | tr ',' ' '))
        
        # Настройка resolv.conf
        if [[ -f /etc/resolv.conf ]]; then
            # Создание резервной копии
            cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
            
            # Обновление DNS серверов
            cat > /etc/resolv.conf << EOF
# DNS конфигурация для восстановленного бэкапа
nameserver ${dns_servers[0]}
EOF
            
            # Добавление дополнительных DNS серверов
            for ((i=1; i<${#dns_servers[@]}; i++)); do
                echo "nameserver ${dns_servers[i]}" >> /etc/resolv.conf
            done
            
            log "DNS конфигурация обновлена"
        fi
    else
        log "DRY RUN: Настройка DNS серверов: $NEW_DNS"
    fi
}

# Основная функция
main() {
    log "Начинаем настройку сети для восстановленного бэкапа..."
    
    # Определение дистрибутива
    local distro=$(detect_distro)
    log "Определен дистрибутив: $distro"
    
    # Определение сетевого интерфейса
    local interface=$(detect_interface)
    log "Используемый интерфейс: $interface"
    
    # Изменение hostname
    configure_hostname
    
    # Настройка сети в зависимости от дистрибутива
    case $distro in
        debian)
            configure_network_debian "$interface"
            ;;
        redhat)
            configure_network_redhat "$interface"
            ;;
        arch)
            configure_network_systemd "$interface"
            ;;
        suse)
            configure_network_systemd "$interface"
            ;;
        *)
            log "Неизвестный дистрибутив, используем systemd-networkd"
            configure_network_systemd "$interface"
            ;;
    esac
    
    # Настройка DNS
    configure_dns
    
    log "Настройка сети завершена успешно!"
    log "Не забудьте перезагрузить сетевой сервис или систему"
    
    if [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo "Для применения изменений выполните:"
        case $distro in
            debian)
                echo "  systemctl restart networking"
                ;;
            redhat)
                echo "  systemctl restart network"
                ;;
            *)
                echo "  systemctl restart systemd-networkd"
                ;;
        esac
        echo "  systemctl restart systemd-resolved"
        echo "  hostnamectl set-hostname $NEW_HOSTNAME"
    fi
}

# Запуск основной функции
main 