доустанавливаем пакеты:

yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano lynx


загружаем и распаковывем исходники:

mkdir rpm && cd rpm
yumdownloader --source nginx
rpm -Uvh nginx*.src.rpm

Пишет:
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root

Как я понял. пакет был рассчитан на пользователя mockbuild из группы mock. Их нет. И был использован root

доустановим ещё зависимости:
yum-builddep nginx -y

скачиваем исходный код ngx_brotli и собираем:

cd /root
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
cd ngx_brotli/deps/brotli
mkdir out && cd out

cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..

cmake --build . --config Release -j 2 --target brotlienc

добавляем --add-module=/root/ngx_brotli \ в /root/rpmbuild/SPECS/nginx.spec
sed -i '/'with-debug'/a \ \ \ \ --add-module=/root/ngx_brotli \\' /root/rpmbuild/SPECS/nginx.spec


cd /root/rpmbuild/SPECS/
rpmbuild -ba nginx.spec -D 'debug_package %{nil}'

Убедимся, что пакеты создались:
ls -lah /root/rpmbuild/RPMS/x86_64/ /root/rpmbuild/RPMS/noarch/

Копируем пакеты в общий каталог
cp /root/rpmbuild/RPMS/noarch/* /root/rpmbuild/RPMS/x86_64/

Переходим в каталог:
cd /root/rpmbuild/RPMS/x86_64

устанавливаем пакеты:
yum localinstall *.rpm

запускаем сервис:
systemctl start nginx

проверяем:
systemctl status nginx


------------------------------------
Создание репозитория:
------------------------------------

создаём каталог:
mkdir /usr/share/nginx/html/repo

Копируем туда файлы пакетов:
cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/

Проверяем:
ls -lah /usr/share/nginx/html/repo/

Инициализируем репозиторий:
createrepo /usr/share/nginx/html/repo/

В файл конфигурации /etc/nginx/nginx.conf в блок server добавляем:
index index.html index.htm;
autoindex on;

проверяем синтаксис:
nginx -t

перезапускаем nginx:
nginx -s reload

проверим через браузер:
lynx http://localhost/repo/

Добавляем репозиторий:
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

проверяем, какие репозитории подключены и фильтруем по "otus":
yum repolist enabled | grep otus

Добавим пакет:
cd /usr/share/nginx/html/repo/
wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm

проверяем:
ls -la | grep percona

Обновим список пакетов в репозитории:
createrepo /usr/share/nginx/html/repo/
yum makecache
yum list | grep otus

Просмотрим информацию о пакете и проверим, в каком он лежит репозитории:
yum info percona-release

Last metadata expiration check: 0:02:03 ago on Fri Jun 21 21:08:48 2024.
Available Packages
Name         : percona-release
Version      : 1.0
Release      : 27
Architecture : noarch
Size         : 20 k
Source       : percona-release-1.0-27.src.rpm
Repository   : otus
Summary      : Package to install Percona GPG key and YUM repo
License      : GPL-3.0+
Description  : percona-release package contains Percona GPG public keys and Percona repository
             : configuration for YUM

Установим:
yum install -y percona-release

в процессе установки можем увидеть, что устанавливается именно с нашего репозитория


