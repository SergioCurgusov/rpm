#!/bin/bash
#доустанавливаем пакеты:

yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano lynx

#загружаем и распаковывем исходники:

mkdir /root/rpm && cd /root/rpm
yumdownloader --source nginx
rpm -Uvh nginx*.src.rpm

#Пишет:
#warning: group mock does not exist - using root
#warning: user mockbuild does not exist - using root

#Как я понял. пакет был рассчитан на пользователя mockbuild из группы mock. Их нет. И был использован root

#доустановим ещё зависимости:
yum-builddep nginx -y

#скачиваем исходный код ngx_brotli и собираем:

cd /root
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out

cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..

cmake --build . --config Release -j 2 --target brotlienc

#добавляем --add-module=/root/ngx_brotli \ в /root/rpmbuild/SPECS/nginx.spec
sed -i '/'with-debug'/a \ \ \ \ --add-module=/root/ngx_brotli \\' /root/rpmbuild/SPECS/nginx.spec


cd /root/rpmbuild/SPECS/
rpmbuild -ba nginx.spec -D 'debug_package %{nil}'

#Копируем пакеты в общий каталог
cp /root/rpmbuild/RPMS/noarch/* /root/rpmbuild/RPMS/x86_64/

#Переходим в каталог:
cd /root/rpmbuild/RPMS/x86_64

#устанавливаем пакеты:
yum localinstall *.rpm -y

#запускаем сервис:
systemctl start nginx

#------------------------------------

#создаём каталог:
mkdir /usr/share/nginx/html/repo

#Копируем туда файлы пакетов:
cp /root/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/

#Инициализируем репозиторий:
createrepo /usr/share/nginx/html/repo/

#В файл конфигурации /etc/nginx/nginx.conf в блок server добавляем:

TEMPVAR=$(cat /etc/nginx/nginx.conf | grep -n "error_page 500 502 503 504" | grep -v \# | awk '{print $1}')
TEMPVAR="${TEMPVAR::-1}"
TEMPVAR=$(($TEMPVAR+2))
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx.conf
sed -i $TEMPVAR'a\        autoindex on;' /etc/nginx/nginx.conf
sed -i $TEMPVAR'a\        index index.html index.htm;' /etc/nginx/nginx.conf
sed -i $TEMPVAR'a\ ' /etc/nginx/nginx.conf

#перезапускаем nginx:
nginx -s reload

#Добавляем репозиторий:
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

# Добавим пакет:
cd /usr/share/nginx/html/repo/
wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm

# Обновим список пакетов в репозитории:
createrepo /usr/share/nginx/html/repo/
yum makecache

#Установим:
yum install -y percona-release