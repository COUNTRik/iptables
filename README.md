# Работа с iptables

Выполним несколько сценариев для работы с *iptables*. Для начала запустим стенд *vagrant up* (запуск машин и установка необходимых пакетов). Заранее сгенерируем ssh ключ на *centralRouter* и добавим его на *inetRouter* в файл *authorized_keys* для тестирования ssh. И выполним два *playbook*: *route.yml* (прописывает необходимые статические маршруты) и *iptables.yml* (прописывает наши правила iptables). 


## Реализация knock для доступа по ssh

На основе этого [материала](http://virtualpath.blogspot.com/2011/04/iptables-mail-http.html) реализуем под свои нужды.

Рассмотрим секцию правил для *inetRouter*.

	- name: inetRouter iptables
	  hosts: inetRouter
	  become: true
	  tasks:

Очищаем все цепочки iptables и таблицу nat

    - name: remove INPUT
      shell: iptables -F INPUT
    - name: remove OUTPUT
      shell: iptables -F OUTPUT
    - name: remove FORWARD
      shell: iptables -F FORWARD
    - name: remove NAT
      shell: iptables -F -t nat
    - name: remove other CHAINS
      shell: iptables -X


Добавляем правило маскарадинга для доступа в интернет локальным машинам

    - name: add iptables MASQUERADE
      shell: iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

Для открытия SSH порта 22 необходимо отправить icmp пакет необходимого размера. Размер пакета: icmp 114 байт (случайные данные)+8 байт (icmp заголовок)+ 20 байт (ip заголовок). Итого: 142 байта

Если пришёл icmp пакет длиной не 142 байт, то добавляем его ip в таблицу BLOCK для блокировки

    - name: add iptables BLOCK
      shell: iptables -A INPUT -p icmp --icmp-type echo-request -m length ! --length 142 -m recent --name BLOCK --set

Если пришел icmp пакет длиной 142 байт и временем жизни более ttl 65, то добавляем его ip в таблицу OPEN

    - name: add iptables OPEN
      shell: iptables -A INPUT -p icmp --icmp-type echo-request -m length   --length 142 -m ttl --ttl-gt 65 -m recent --name OPEN  --set

Разрешаем доступ к порту SSH 22 для ip из таблицы OPEN в течении 30 секунд после добавления в таблицу

    - name: add iptables ACCEPT for OPEN
      shell: iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --name OPEN  --rcheck --seconds 30 -j ACCEPT

Блокируем доступ к порту SSH 22 для ip из таблицы BLOCK в течении 60 секунд после добавления в таблицу

    - name: add iptables DROP for BLOCK
      shell: iptables -A INPUT -p tcp --dport 22 -m recent --name BLOCK --rcheck --seconds 60 -j DROP

Блокируем все остальные соединения к порту SSH 22 (здесь блокируем соединения только с интефейса *eth1* для того чтобы могли работать vagrant и ansible).

	- name: add iptables DROP for dport 22
	  shell: iptables -A INPUT -i eth1 -p tcp --dport 22 -j DROP

Проверяем наши правила

	[root@centralRouter ~]# ssh root@192.168.255.1
	ssh: connect to host 192.168.255.1 port 22: Connection timed out
	[root@centralRouter ~]# ping -c 1 -s 114 -t 89 192.168.255.1
	PING 192.168.255.1 (192.168.255.1) 114(142) bytes of data.
	122 bytes from 192.168.255.1: icmp_seq=1 ttl=64 time=0.734 ms

	--- 192.168.255.1 ping statistics ---
	1 packets transmitted, 1 received, 0% packet loss, time 0ms
	rtt min/avg/max/mdev = 0.734/0.734/0.734/0.000 ms
	[root@centralRouter ~]# ssh root@192.168.255.1
	Last login: Mon Nov 30 12:17:40 2020 from 192.168.255.3
	[root@inetRouter ~]# uname -r
	3.10.0-1127.el7.x86_64
	[root@inetRouter ~]# hostnamectl
	   Static hostname: inetRouter
	         Icon name: computer-vm
	           Chassis: vm
	        Machine ID: 3210b435cd0e8b40b35f6f5f9096b322
	           Boot ID: 1ca117430aae4a06bd56424fbf0c465f
	    Virtualization: kvm
	  Operating System: CentOS Linux 7 (Core)
	       CPE OS Name: cpe:/o:centos:centos:7
	            Kernel: Linux 3.10.0-1127.el7.x86_64
	      Architecture: x86-64

## Пробросить порт 80 веб сервера nginx на порт 8080 маршрутизатора inet2router

Примечание: в *centralRouter* прописан статический маршрут специально для внешнего интерфейса eth1 *inet2Router* с ip 172.28.128.3

	- name: add route centralRouter for inet2 networks
	  shell: ip route add 172.28.128.0/28 via 192.168.255.2 dev eth1

Рассмотрим секцию правил для *inet2Router*.

	- name: inet2Router iptables
	  hosts: inet2Router
	  become: true
	  tasks:

Очищаем все цепочки iptables и таблицу nat

    - name: remove INPUT
      shell: iptables -F INPUT
    - name: remove OUTPUT
      shell: iptables -F OUTPUT
    - name: remove FORWARD
      shell: iptables -F FORWARD
    - name: remove NAT
      shell: iptables -F -t nat
    - name: remove other CHAINS
      shell: iptables -X

Все пакеты приходящие с интерфейса eth2 с назначением 172.28.128.3:8080 меняют путь назначения на локальный 192.168.3.2:80 

    - name: add iptables PREROUTING DNAT 
      shell: iptables -t nat -A PREROUTING -i eth2 --dst 172.28.128.3 -p tcp --dport 8080 -j DNAT --to-destination 192.168.3.2:80

Проверяем наши правила:

	countrik$ curl http://172.28.128.3:8080
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	<html>
	<head>
	  <title>Welcome to CentOS</title>
	  <style rel="stylesheet" type="text/css"> 
