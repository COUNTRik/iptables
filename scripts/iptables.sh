#!/usr/bin/env bash

# 
# Используем политику запретить все (default deny)
# iptables -P INPUT   DROP
# iptables -P OUTPUT  DROP
# iptables -P FORWARD DROP

# Отбрасывать все пакеты, которые не могут быть идентифицированы и поэтому не могут иметь определенного статуса.
iptables -A INPUT -m state --state INVALID -j DROP

# разрешаем прохождение входящих  tcp/udp-пакетов принадлежащих к уже установленым соединениям
iptables -A INPUT -p tcp -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp -m state --state ESTABLISHED -j ACCEPT

# разрешаем прохождение исходящих tcp/udp-пакетов принадлежащих к уже установленым cоединениям
# iptables -A OUTPUT -p tcp -m state --state ESTABLISHED -j ACCEPT
# iptables -A OUTPUT -p udp -m state --state ESTABLISHED -j ACCEPT

# Разрешаем прохождение любого трафика по интерфейсу обратной петли
# iptables -A INPUT  -i lo -j ACCEPT
# iptables -A OUTPUT -o lo -j ACCEPT

# Разрешаем использовать следующие порты:

# 1. УПРАВЛЕНИЕ СЕРВЕРОМ
# SSH на порте 5681.
# iptables -A INPUT -p tcp --dport 5681 -j ACCEPT
# SSH с port knocking и защитой от bruteforce.Размер пакета:
# icmp 114 байт (случайные данные)+8 байт (icmp заголовок)+ 20 байт (ip заголовок)
# ttl для пакета более 88 сек.

# Если пришёл icmp пакет длиной не 142 байт, то добавляем его ip в таблицу BLOCK для блокировки
iptables -A INPUT -p icmp --icmp-type echo-request -m length ! --length 142 -m recent --name BLOCK --set
# Если пришел icmp пакет длиной 142 байт и временем жизни более 65, то добавляем его ip в таблицу OPEN
iptables -A INPUT -p icmp --icmp-type echo-request -m length   --length 142 -m ttl --ttl-gt 65 -m recent --name OPEN  --set
# Разрешаем доступ к порту SSH (22) для ip из таблицы OPEN в течении 20 секунд после добавления в таблицу
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --name OPEN  --rcheck --seconds 30 -j ACCEPT
# Блокируем доступ к порту SSH (22) для ip из таблицы BLOCK в течении 60 секунд после добавления в таблицу
iptables -A INPUT -p tcp --dport 22 -m recent --name BLOCK --rcheck --seconds 60 -j DROP
iptables -A INPUT -p tcp --dport 22 -j DROP
# ping -c 1 -s 114 -t 89 192.168.255.1

#inet2Router
iptables -t nat -A PREROUTING --dst 172.28.128.3 -p tcp --dport 8080 -j DNAT --to-destination 192.168.3.2:80
iptables -t nat -A POSTROUTING --dst 192.168.3.2 -p tcp --dport 80 -j SNAT --to-source 172.28.128.3:8080
iptables -t nat -A OUTPUT --dst 192.168.3.2 -p tcp --dport 80 -j DNAT 172.28.128.3:8080
