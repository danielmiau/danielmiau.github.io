# 01-Redis基础入门

# 1. Redis 是什么？

Redis（Remote Dictionary Server）是一款开源的、基于内存的高性能键值对（Key-Value）数据库，核心定位是“轻量、高效、易用”，支持多种数据结构，可实现持久化和高可用（具体细节后续章节展开）。

## 1.1 核心基础特点

- 内存存储：数据全部存于内存，读写速度极快

- 多数据结构：支持String、List、Hash、Set、ZSet等常用类型

- 易用性强：命令简洁，部署简单，跨平台支持

- 可扩展：支持持久化、高可用和集群

说明：本章仅讲解“如何启动Redis、如何基础使用”，所有原理、进阶配置均在后续对应章节展开。

# 2. 安装与部署

## 2.1 Linux 环境（推荐生产环境）

### 2.1.1 源码编译安装（核心步骤）

```bash
# 1. 安装依赖（极简）
yum install -y gcc tcl

# 2. 下载源码（以6.2.7稳定版为例）
wget https://download.redis.io/releases/redis-6.2.7.tar.gz
tar -zxvf redis-6.2.7.tar.gz
cd redis-6.2.7

# 3. 编译安装
make
make install PREFIX=/usr/local/redis

# 4. 配置环境变量（可选，方便全局调用）
echo 'export PATH=$PATH:/usr/local/redis/bin' >> /etc/profile
source /etc/profile
```

### 2.1.2 Docker 安装（快速体验，推荐测试环境）

```bash
# 拉取镜像
docker pull redis:6.2.7

# 启动容器（设置密码，映射端口）
docker run -d --name redis -p 6379:6379 redis:6.2.7 --requirepass "yourPassword"
```

### 2.1.3 核心操作（启动、停止、连接）

```bash
# 1. 后台启动（指定配置文件，核心）
redis-server /usr/local/redis/redis.conf

# 2. 停止Redis（优雅关闭，推荐）
redis-cli -a yourPassword shutdown

# 3. 强制停止（不推荐，可能丢数据）
kill -9 $(ps -ef | grep redis-server | grep -v grep | awk '{print $2}')

# 4. 客户端连接（本地连接）
redis-cli -a yourPassword

# 5. 远程连接（指定IP和端口）
redis-cli -h 192.168.1.100 -p 6379 -a yourPassword
```

### 2.1.4 redis.conf 核心配置（仅入门必备）

```ini
# 绑定IP（生产建议绑定内网IP，测试可设0.0.0.0）
bind 127.0.0.1

# 端口号（默认6379）
port 6379

# 后台运行（必开，避免前台阻塞）
daemonize yes

# 访问密码（生产环境必须设置，避免裸奔）
requirepass yourPassword
```

## 2.2 Windows 环境（仅测试用，不推荐生产）

1. 下载Windows版本Redis（官网不提供，可搜索“Redis Windows版”）；

2. 解压后双击 redis-server.exe 启动服务；

3. 双击 redis-cli.exe 打开客户端，输入 auth 密码（若设置）即可使用。

# 3. 客户端连接与通用命令

## 3.1 客户端连接说明

核心使用 redis-cli 客户端，连接成功后，输入命令即可交互；若连接失败，检查IP、端口、密码是否正确，以及Redis服务是否正常运行。

## 3.2 通用键操作命令（仅基础，不涉及具体数据结构）

```redis
# 1. 查看所有key（生产环境慎用！会阻塞进程）
keys *

# 2. 模糊匹配key（生产慎用）
keys user:*

# 3. 检查key是否存在（返回1存在，0不存在）
exists keyName

# 4. 删除指定key（返回1删除成功，0不存在）
del keyName

# 5. 设置key的过期时间（单位：秒）
expire keyName 3600

# 6. 查看key剩余过期时间（秒，-1永久有效，-2已过期/不存在）
ttl keyName

# 7. 查看key的类型（返回string、list等）
type keyName

# 8. 批量查找key（推荐生产使用，非阻塞）
scan 0 match user:* count 1000

# 9. 清空当前库所有key（生产严禁使用！）
flushdb

# 10. 清空所有库所有key（生产严禁使用！）
flushall
```

## 3.3 简单交互示例

```redis
# 1. 存储一个字符串（key=name，value=redis）
set name redis

# 2. 获取key对应的value
get name

# 3. 设置过期时间（1小时）
expire name 3600

# 4. 查看剩余时间
ttl name

# 5. 删除key
del name
```

# 4. Key 设计规范（基础版）

## 4.1 核心设计原则

- 统一前缀：采用「业务模块:功能:主键」的格式，便于管理和区分

- 分隔符：使用冒号「:」分隔，清晰区分层级

- 长度控制：避免过长key，减少内存占用

- 大小写：区分大小写，建议统一使用小写+下划线

## 4.2 规范示例（极简）

```text
user:info:1001    # 用户信息（用户ID=1001）
goods:cache:1001  # 商品缓存（商品ID=1001）
order:id:20260418 # 订单ID（日期+订单标识）
```

# 5. 新手入门避坑

- 严禁在生产环境使用 keys *、flushdb、flushall 命令，会导致服务阻塞或数据丢失；

- 生产环境必须设置Redis密码，禁止裸奔（避免未授权访问）；

- 测试环境用完Redis后，及时停止服务，避免占用过多内存；

- 不要忘记给缓存key设置过期时间，避免内存无限增长；

- 连接Redis时，确保IP、端口、密码正确，若远程连接，需开放对应端口。