自动追文
========

将 小说/贴子 导出为txt/html/mobi/epub，支持推送到指定电子邮件地址，支持自动追文

密码采用最简单的bear token模式，以https访问页面

![loadxs.png](loadxs.png)

# 说明

以debian环境为例，需要安装apache2, MariaDB, ansible, exim4, ansible, Novel::Robot等相关工具

xs 目录为web页面代码，使用perl的mojo开发，负责在线写入任务到数据库

snaked 目录负责执行小说下载及更新任务，使用perl的snaked模块

假设:

1) 推送的exim4邮件服务器为 mail.myebookserver.com，推送源邮箱为 kindle@myebookserver.com

2) 在线临时存放小说的服务器为web.myebookserver.com，路径为/var/www/html/ebook，对应的web地址为 http://web.myebookserver.com/ebook/

3) 注意需要在**亚马逊**配置kindle@myebookserver.com为可信来源

## 安装

    apt-get -y install apache2 libapache2-mod-perl2
    apt-get -y install libapache2-mod-php php php-pear php-curl
    apt-get -y install mariadb-server php-mysql
    apt-get -y install imagemagick php-imagick php-gd
    apt-get -y exim4 ansible
    cpanm -n Plack Plack::Handler::Apache2 
    cpanm -n Mojolicious::Lite Mojolicious::Static Mojo::Template 
    cpanm -n Encode::Locale File::Temp File::Slurp Novel::Robot 
    cpanm -n HTTP::Tiny SimpleR::Reshape SimpleDBI::mysql
    cpanm -n snaked

## novel_task 存放即时指定下载的任务

    MariaDB [novel]> desc novel_task;
    +-------+-------------+------+-----+-------------------+-------+
    | Field | Type        | Null | Key | Default           | Extra |
    +-------+-------------+------+-----+-------------------+-------+
    | time  | timestamp   | NO   | MUL | CURRENT_TIMESTAMP |       |
    | rand  | varchar(30) | YES  |     | NULL              |       |
    | task  | text        | YES  |     | NULL              |       |
    | flag  | int(11)     | YES  |     | NULL              |       |
    +-------+-------------+------+-----+-------------------+-------+
    4 rows in set (0.00 sec)

## update_novel 存放每天自动追文的任务

    MariaDB [novel]> desc update_novel;
    +----------+--------------+------+-----+-------------------+-----------------------------+
    | Field    | Type         | Null | Key | Default           | Extra                       |
    +----------+--------------+------+-----+-------------------+-----------------------------+
    | url      | varchar(100) | YES  |     | NULL              |                             |
    | mail     | varchar(100) | YES  |     | NULL              |                             |
    | novel_id | tinyint(4)   | YES  |     | NULL              |                             |
    | note     | varchar(50)  | NO   | PRI |                   |                             |
    | time     | timestamp    | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |
    | writer   | varchar(50)  | YES  |     | NULL              |                             |
    | book     | varchar(50)  | YES  |     | NULL              |                             |
    | site     | varchar(50)  | YES  |     | NULL              |                             |
    +----------+--------------+------+-----+-------------------+-----------------------------+
    8 rows in set (0.00 sec)
