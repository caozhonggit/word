# [mycat之读写分离](https://www.cnblogs.com/kiko2014551511/p/11534020.html)

##  

## **一、mycat简介**

MyCat是一个开源的分布式数据库系统，是一个实现了MySQL协议的服务器，前端用户可以把它看作是一个数据库代理，用MySQL客户端工具和命令行访问，而其后端可以用MySQL原生协议与多个MySQL服务器通信，也可以用JDBC协议与大多数主流数据库服务器通信，其核心功能是分表分库，即将一个大表水平分割为N个小表，存储在后端MySQL服务器里或者其他数据库里。

MyCat发展到目前的版本，已经不是一个单纯的MySQL代理了，它的后端可以支持MySQL、SQL Server、Oracle、DB2、PostgreSQL等主流数据库，也支持MongoDB这种新型NoSQL方式的存储，未来还会支持更多类型的存储。而在最终用户看来，无论是那种存储方式，在MyCat里，都是一个传统的数据库表，支持标准的SQL语句进行数据的操作，这样一来，对前端业务系统来说，可以大幅降低开发难度，提升开发速度。

 

## **二、mycat下载安装**

注意：因Mycat是用java开发的，所以需要在实验环境下安装java，官方建议jdk1.7及以上版本

 下载mycat包并安装（http://dl.mycat.io/1.6-RELEASE/Mycat-server-1.6-RELEASE-20161028204710-linux.tar.gz）

 

1、进入/usr/local/目录

```
[root@localhost /]# cd /usr/local/
```

2、创建mycat文件夹

```
[root@localhost local]# mkdir mycat
```

3、进入mycat文件夹

```
[root@localhost local]# cd mycat
```

4、通过wget命令下载mycat安装包

```
[root@localhost mycat]# wget http://dl.mycat.io/1.6-RELEASE/Mycat-server-1.6-RELEASE-20161028204710-linux.tar.gz
```

5、解压mycat安装包

```
[root@localhost mycat]# tar -xf Mycat-server-1.6-RELEASE-20161028204710-linux.tar.gz
```

6、打开/etc/profile文件，配置环境变量

在/etc/profile文件里加上下面两句，vim /etc/profile  

```
export MYCAT_HOME=/usr/local/mycat/mycat

export PATH=$PATH:$MYCAT_HOME/bin
```

7、使配置生效

```
[root@localhost mycat]# source /etc/profile
```

 

此时安装完毕

 

## **三、mycat读写分离配置**

前提：mysql配置好了主从复制  我这里主库ip 192.169.1.9 从库ip 192.169.1.24 

![img](https://github.com/caozhonggit/word/blob/master/mycat1.png)

 

 

 

1、编辑 mycat的配置文件mycat/conf/server.xml

 ![img](https://github.com/caozhonggit/word/blob/master/mycat2.png)

 

 

2、编辑mycat的配置文件mycat/conf/schema.xml

![img](https://github.com/caozhonggit/word/blob/master/mycat3.png)

 到这里，mycat读写分离就已经配置完了

 

注意 dataHost节点的下面三个属性 balance， writeType， switchType

balance

1. balance="0" , 不开启读写分离机制，所有读操作都发送到当前可用的writeHost上。
2. balance="1" , 全部的readHost与stand by writeHost参与select语句的负载均衡，简单的说，当双主双从模式(M1->S1 , M2-S2 , 并且M1与M2互为主备) ，正常情况下，M2,S1,S2都参与select语句的负载均衡。
3. balance="2" , 所有读操作都随机的在writeHost,readHost上分发
4. balance="3" , 所有读请求随机的分发到writeHost对应的readHost上执行，writeHost不负担读压力，注意，balance=3只有在1.4及其以后的版本有，1.3没有

writeType

1. writeType="0" , 所有写操作发送到配置的第一个writeHost ，第一个挂了切到还生存的第二个writeHost，重启启动后以切换后的为准，切换记录在配置文件中：dnindex.properties.
2. writeType="1" , 所有写操作都随机的发送到配置的writeHost, **1.5以后废弃不推荐** 

switchType

1. switchType="-1" , 表示不自动切换
2. switchType="1" , 默认值，自动切换
3. switchType="2" ,基于mysql主从同步状态决定是否切换

 

 

## **四、启动mycat**

进入mycat目录/usr/local/mycat/mycat，执行命令./bin/mycat start 来启动mycat ，启动mycat后，可以执行命令./bin/mycat status 查看是否启动成功

启动完成后用Navicat for MySQL连接mycat，连接成功! (mycat代理数据库端口默认是8066，所以这里客户端连接的是8066端口)

 ![img](https://github.com/caozhonggit/word/blob/master/mycat4.png)

 

## 五、读写分离验证

**1、执行建表语句**

create table c_user(id int not null primary key,name varchar(20))

查看mycat/logs/mycat.log文件：

2018-10-23 02:32:19.926 DEBUG [$_NIOREACTOR-0-RW] (io.mycat.server.NonBlockingSession.releaseConnection(NonBlockingSession.java:341)) - release connection MySQLConnection [id=4, lastTime=1540276339902, user=root, schema=emp1019, old shema=emp1019, borrowed=true, fromSlaveDB=false, threadId=35791, charset=utf8, txIsolation=3, autocommit=true, attachment=dn1{create table c_user(id int not null primary key,name varchar(20))}, respHandler=SingleNodeHandler [node=dn1{create table c_user(id int not null primary key,name varchar(20))}, packetId=1], host=192.169.1.9, port=3306, statusSync=null, writeQueue=0, modifiedSQLExecuted=true]

 从日志可以看到建表语句是在192.169.1.9的数据库(主库)上执行的

**2、执行插入语句**

 insert into c_user values(1,'cc');

 查看mycat/logs/mycat.log文件：

 2018-10-23 02:38:44.973 DEBUG [$_NIOREACTOR-0-RW] (io.mycat.server.NonBlockingSession.releaseConnection(NonBlockingSession.java:341)) - release connection MySQLConnection [id=4, lastTime=1540276724962, user=root, schema=emp1019, old shema=emp1019, borrowed=true, fromSlaveDB=false, threadId=35791, charset=utf8, txIsolation=3, autocommit=true, attachment=dn1{insert into c_user values(1,'cc')}, respHandler=SingleNodeHandler [node=dn1{insert into c_user values(1,'cc')}, packetId=1], host=192.169.1.9, port=3306, statusSync=null, writeQueue=0, modifiedSQLExecuted=true]

 从日志可以看出插入语句是在192.169.1.9上的数据库(主库)上执行的

**3、执行查询语句**

 select * from c_user;

查看mycat/logs/mycat.log文件：

2018-10-23 02:41:39.425 DEBUG [$_NIOREACTOR-1-RW] (io.mycat.server.NonBlockingSession.releaseConnection(NonBlockingSession.java:341)) - release connection MySQLConnection [id=13, lastTime=1540276899422, user=root, schema=emp1019, old shema=emp1019, borrowed=true, fromSlaveDB=true, threadId=37805, charset=utf8, txIsolation=3, autocommit=true, attachment=dn1{select * from c_user}, respHandler=SingleNodeHandler [node=dn1{select * from c_user}, packetId=5], host=192.169.1.24, port=3306, statusSync=null, writeQueue=0, modifiedSQLExecuted=false] 

从日志可以看出查询语句是在192.169.1.24的数据库(从库)上执行的

 

## 六、mycat常用命令

mycat目录/bin 下执行如下命令

**启动Mycat:** ./mycat start

**查看启动状态:** ./mycat status

**停止:** ./mycat stop

**重启:** ./mycat restart

**启动并控制台打印日志:** ./mycat console

 

## 七、存在的问题

 程序连接mycat执行较复杂的存储过程存在问题(比如执行带出参的存储过程，程序拿不到出参)

   经了解： mycat执行存储过程需要在执行存储过程的sql语句前加注解