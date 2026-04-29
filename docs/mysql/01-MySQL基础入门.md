# 01-MySQL 基础入门

前言：本文为MySQL学习文档的第一章，聚焦MySQL基础入门知识，作为后续章节（索引、事务、锁机制等）的学习铺垫。内容涵盖MySQL环境安装与配置、SQL基础语法（DDL/DML/DQL/DCL）、数据类型与字段设计规范、主流存储引擎（InnoDB/MyISAM）特性对比四大核心模块，兼顾理论讲解与实操细节，语言通俗易懂，适配零基础入门学习者，同时为后续进阶学习筑牢基础。本文将严格遵循技术文档规范，每个知识点搭配实操示例，避免纯理论堆砌，确保学习者能快速上手MySQL基础操作。

# 一、MySQL 简介

MySQL是一款开源的关系型数据库管理系统（RDBMS），由Oracle公司主导开发维护，凭借轻量、高效、易用、开源免费的特性，成为互联网行业最主流的数据库之一，广泛应用于中小型项目、大型互联网系统（如电商、社交、资讯平台）的后台数据存储。

核心特点：

- 开源免费：社区版完全免费，企业版提供商业支持，降低项目成本；

- 跨平台：支持Windows、Linux、MacOS等多种操作系统，适配不同部署环境；

- 关系型数据库：基于关系模型（表结构）存储数据，支持SQL结构化查询语言，数据一致性强；

- 高性能：优化的存储引擎的（如InnoDB）支持高并发、事务、索引等特性，满足高频数据访问需求；

- 易用性强：语法简洁，上手门槛低，拥有完善的文档和社区支持，问题易排查。

补充：MySQL版本说明：目前主流稳定版本为8.0.x（推荐学习和生产使用），与5.x版本相比，8.0新增了窗口函数、JSON增强、角色管理等特性，性能和安全性更优；本文所有实操示例均基于MySQL 8.0.x版本。

# 二、环境安装与配置（实操重点）

本节涵盖Windows和Linux两种主流操作系统的MySQL安装步骤，以及基础配置优化，确保学习者能顺利完成环境搭建，为后续SQL操作奠定基础。安装核心原则：优先选择稳定版（8.0.x），严格按照步骤操作，避免端口冲突、密码遗漏等问题。

## 2.1 Windows 系统安装（零基础首选）

### 2.1.1 下载安装包

1. 访问MySQL官方下载地址：https://dev.mysql.com/downloads/mysql/，选择“MySQL Community Server”（社区版，免费）；

2. 选择操作系统为“Windows”，下载对应的安装包（推荐“MySQL Installer for Windows”，傻瓜式安装，适合零基础）；

3. 根据自身系统位数（32位/64位）选择对应版本，下载完成后双击运行安装包。

### 2.1.2 安装步骤（图文流程简化）

1. 运行安装包后，选择“Custom”（自定义安装），勾选“MySQL Server 8.0.x”（核心组件），取消其他不必要的组件（如MySQL Workbench，可后续单独安装）；

2. 选择安装路径（建议安装在非C盘，如D:\MySQL\MySQL Server 8.0），避免C盘空间不足；

3. 配置端口：默认端口为3306，若3306端口被占用（如其他数据库占用），可修改为3307等未被占用的端口，记住端口号（后续连接需使用）；

4. 设置root用户密码：root为MySQL超级管理员，密码建议设置复杂且易记忆（如Root@123456），避免简单密码（如123456）导致安全风险；

5. 配置服务：勾选“Configure MySQL as a Windows Service”，将MySQL注册为Windows服务，便于开机自动启动、手动启停；

6. 完成安装，点击“Finish”，重启电脑（可选，确保服务正常启动）。

### 2.1.3 验证安装是否成功

1. 打开Windows“服务”，找到“MySQL80”（服务名称），确认服务状态为“正在运行”，若未运行，右键“启动”；

2. 打开命令提示符（CMD），输入命令：`mysql -u root -p`，按回车；

3. 输入安装时设置的root密码，按回车，若出现“mysql>”提示符，说明安装成功。

## 2.2 Linux 系统安装（生产环境常用）

Linux系统（以CentOS 7为例）安装MySQL，推荐使用YUM源安装，步骤简洁，避免手动配置依赖，适合生产环境快速部署。

### 2.2.1 安装步骤

```bash
# 1. 卸载系统自带的MariaDB（避免冲突，CentOS 7默认自带MariaDB）
yum remove mariadb-server mariadb -y

# 2. 下载MySQL YUM源（适配MySQL 8.0）
wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm

# 3. 安装YUM源
rpm -ivh mysql80-community-release-el7-3.noarch.rpm

# 4. 安装MySQL Server
yum install mysql-community-server -y

# 5. 启动MySQL服务，并设置开机自启
systemctl start mysqld
systemctl enable mysqld

# 6. 查看MySQL初始密码（MySQL 8.0默认生成随机初始密码）
grep 'temporary password' /var/log/mysqld.log

# 7. 登录MySQL，修改初始密码
mysql -u root -p  # 输入步骤6查询到的初始密码
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Root@123456';  # 新密码需符合复杂度（大小写+数字+特殊符号）

# 8. 授权root用户远程访问（可选，便于远程连接MySQL）
use mysql;
update user set host='%' where user='root';
flush privileges;  # 刷新权限
exit;  # 退出MySQL
```

### 2.2.2 验证安装是否成功

```bash
# 重新登录MySQL，确认密码修改成功
mysql -u root -p
# 输入新密码，出现“mysql>”提示符，说明安装成功
# 查看MySQL版本
select version();

```

## 2.3 基础配置优化（必做）

安装完成后，需对MySQL进行基础配置，优化性能和易用性，核心配置文件路径：

- Windows：安装路径下的 my.ini 文件（如D:\MySQL\MySQL Server 8.0\my.ini）；

- Linux：/etc/my.cnf 文件。

核心配置项（修改后重启MySQL服务生效）：

```ini
# 1. 字符集配置（避免中文乱码）
[mysqld]
character-set-server=utf8mb4  # 支持所有中文（包括 emoji）
collation-server=utf8mb4_unicode_ci

# 2. 端口配置（默认3306，若修改需同步客户端连接端口）
port=3306

# 3. 数据存储路径（建议修改为非系统盘，避免系统盘空间不足）
# Windows：
datadir=D:\MySQL\Data
# Linux：
datadir=/var/lib/mysql

# 4. 最大连接数（基础优化，避免连接数不足）
max_connections=100

# 5. 日志配置（便于排查问题）
log-error=/var/log/mysqld.log  # Linux路径
# Windows：
log-error=D:\MySQL\Logs\mysqld.log

```

配置修改后，重启MySQL服务：

- Windows：服务中找到“MySQL80”，右键“重启”；

- Linux：`systemctl restart mysqld`。

## 2.4 客户端工具推荐

命令行工具操作MySQL不够直观，推荐使用以下图形化客户端工具，提升操作效率：

- Navicat：功能强大，支持Windows/MacOS，适合开发和运维人员，可免费试用；

- DBeaver：开源免费，跨平台，支持多种数据库（MySQL、Oracle、Redis等），适合零基础学习者；

- MySQL Workbench：MySQL官方提供的客户端，免费开源，功能简洁，适合简单操作。

客户端连接步骤：打开工具 → 新建连接 → 输入主机地址（localhost/远程IP）、端口（3306）、用户名（root）、密码 → 测试连接 → 连接成功。

# 三、SQL 基础语法（核心重点）

SQL（Structured Query Language，结构化查询语言）是操作关系型数据库的标准语言，MySQL完全兼容SQL标准，同时有少量扩展语法。本节按SQL功能分类（DDL、DML、DQL、DCL），讲解核心语法，搭配实操示例，确保学习者能独立完成基础SQL操作。

核心说明：SQL语法不区分大小写（如SELECT和select效果一致），但建议关键字（如SELECT、INSERT）大写，表名、字段名小写，提升可读性；每条SQL语句以分号（;）结尾。

## 3.1 DDL：数据定义语言（Data Definition Language）

作用：用于定义数据库、表、视图等数据结构，核心操作：创建（CREATE）、修改（ALTER）、删除（DROP）。

### 3.1.1 数据库操作（核心）

```sql
-- 1. 创建数据库（指定字符集，避免中文乱码）
CREATE DATABASE IF NOT EXISTS test_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- 说明：IF NOT EXISTS 表示如果数据库不存在则创建，避免重复创建报错

-- 2. 查看所有数据库
SHOW DATABASES;

-- 3. 切换数据库（操作表前必须切换到对应数据库）
USE test_db;

-- 4. 修改数据库字符集（很少用）
ALTER DATABASE test_db CHARACTER SET utf8mb4;

-- 5. 删除数据库（谨慎操作，删除后数据无法恢复）
DROP DATABASE IF EXISTS test_db;

```

### 3.1.2 表操作（核心）

表是MySQL存储数据的核心载体，每个表由多个字段组成，每个字段对应一种数据类型。

```sql
-- 1. 创建表（以用户表user为例）
CREATE TABLE IF NOT EXISTS user (
    id INT PRIMARY KEY AUTO_INCREMENT,  -- 主键，自增（唯一标识每条数据）
    name VARCHAR(50) NOT NULL,          -- 姓名，非空（不能为空）
    age INT DEFAULT 0,                  -- 年龄，默认值0
    gender VARCHAR(10),                 -- 性别
    create_time DATETIME DEFAULT CURRENT_TIMESTAMP  -- 创建时间，默认当前时间
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- 说明：ENGINE 指定存储引擎，DEFAULT CHARSET 指定字符集

-- 2. 查看当前数据库所有表
SHOW TABLES;

-- 3. 查看表结构（查看表的字段、数据类型、约束等）
DESCRIBE user;  -- 简写：DESC user;

-- 4. 修改表结构（常用）
-- 4.1 添加字段（添加手机号字段）
ALTER TABLE user ADD COLUMN phone VARCHAR(20);
-- 4.2 修改字段数据类型（修改phone字段长度为11）
ALTER TABLE user MODIFY COLUMN phone VARCHAR(11);
-- 4.3 修改字段名（将phone改为mobile）
ALTER TABLE user CHANGE COLUMN phone mobile VARCHAR(11);
-- 4.4 删除字段（删除gender字段）
ALTER TABLE user DROP COLUMN gender;

-- 5. 删除表（谨慎操作）
DROP TABLE IF EXISTS user;

```

## 3.2 DML：数据操纵语言（Data Manipulation Language）

作用：用于操作表中的数据，核心操作：插入（INSERT）、修改（UPDATE）、删除（DELETE）。

### 3.2.1 插入数据（INSERT）

```sql
-- 1. 插入一条数据（指定所有字段）
INSERT INTO user (name, age, mobile, create_time) 
VALUES ('张三', 25, '13800138000', '2026-04-20 10:00:00');

-- 2. 插入一条数据（不指定自增、默认值字段，自动填充）
INSERT INTO user (name, age, mobile) 
VALUES ('李四', 28, '13900139000');  -- create_time 自动填充当前时间，id 自动自增

-- 3. 批量插入数据（高效，推荐）
INSERT INTO user (name, age, mobile) 
VALUES 
('王五', 22, '13700137000'),
('赵六', 30, '13600136000'),
('孙七', 26, '13500135000');

```

### 3.2.2 修改数据（UPDATE）

```sql
-- 1. 修改一条数据（必须加WHERE条件，否则修改所有数据）
UPDATE user SET age = 26 WHERE id = 1;  -- 将id=1的用户年龄改为26

-- 2. 修改多条数据（加WHERE条件筛选）
UPDATE user SET age = 27 WHERE name LIKE '张%';  -- 将姓名以“张”开头的用户年龄改为27

-- 3. 同时修改多个字段
UPDATE user SET age = 29, mobile = '13800138001' WHERE id = 2;

-- 警告：禁止执行无WHERE条件的UPDATE语句，会导致全表数据修改！
-- UPDATE user SET age = 30;  -- 错误操作，会修改所有用户的年龄

```

### 3.2.3 删除数据（DELETE）

```sql
-- 1. 删除一条数据（必须加WHERE条件）
DELETE FROM user WHERE id = 5;  -- 删除id=5的用户

-- 2. 删除多条数据（加WHERE条件筛选）
DELETE FROM user WHERE age < 25;  -- 删除年龄小于25的用户

-- 3. 删除表中所有数据（保留表结构，可恢复）
DELETE FROM user;

-- 4. 清空表中所有数据（不保留表结构，不可恢复，速度更快）
TRUNCATE TABLE user;

-- 警告：禁止执行无WHERE条件的DELETE语句，会删除全表数据！
-- DELETE FROM user;  -- 谨慎操作，删除后数据可通过日志恢复，但难度大

```

补充：DELETE 和 TRUNCATE 的区别：DELETE 保留表结构，可通过事务回滚或日志恢复数据；TRUNCATE 不保留表结构（重置自增主键），数据无法恢复，速度比DELETE快。

## 3.3 DQL：数据查询语言（Data Query Language）

作用：用于查询表中的数据，核心操作：SELECT，是SQL中最常用、最复杂的语法，本节讲解基础查询，进阶查询（关联查询、子查询等）将在后续章节讲解。

### 3.3.1 基础查询（核心）

```sql
-- 1. 查询表中所有字段（* 表示所有字段，不推荐生产使用，效率低）
SELECT * FROM user;

-- 2. 查询指定字段（推荐，只查需要的字段，提升效率）
SELECT id, name, age FROM user;

-- 3. 给字段起别名（AS 可省略）
SELECT id AS 编号, name AS 姓名, age AS 年龄 FROM user;
SELECT id 编号, name 姓名, age 年龄 FROM user;

-- 4. 去重查询（DISTINCT，去除重复数据）
SELECT DISTINCT age FROM user;  -- 查询所有不重复的年龄

-- 5. 条件查询（WHERE 子句）
SELECT * FROM user WHERE age > 25;  -- 查询年龄大于25的用户
SELECT * FROM user WHERE name = '张三';  -- 查询姓名为张三的用户
SELECT * FROM user WHERE age BETWEEN 25 AND 30;  -- 查询年龄在25-30之间的用户
SELECT * FROM user WHERE name LIKE '%三%';  -- 查询姓名包含“三”的用户（%表示任意字符）
SELECT * FROM user WHERE age IS NULL;  -- 查询年龄为空的用户
SELECT * FROM user WHERE age IS NOT NULL;  -- 查询年龄不为空的用户
SELECT * FROM user WHERE age = 25 AND mobile LIKE '138%';  -- 多条件查询（AND 同时满足）
SELECT * FROM user WHERE age = 25 OR age = 30;  -- 多条件查询（OR 满足一个即可）

-- 6. 排序查询（ORDER BY，默认升序ASC，降序DESC）
SELECT * FROM user ORDER BY age ASC;  -- 按年龄升序排列
SELECT * FROM user ORDER BY age DESC;  -- 按年龄降序排列
SELECT * FROM user ORDER BY age DESC, id ASC;  -- 先按年龄降序，年龄相同按id升序

-- 7. 限制查询条数（LIMIT，用于分页查询）
SELECT * FROM user LIMIT 3;  -- 查询前3条数据
SELECT * FROM user LIMIT 2, 3;  -- 从第3条开始（索引从0开始），查询3条数据（分页常用）

```

## 3.4 DCL：数据控制语言（Data Control Language）

作用：用于控制数据库的访问权限，核心操作：授权（GRANT）、撤销授权（REVOKE）、创建用户（CREATE USER），主要用于数据库运维，零基础入门可先了解基础用法。

```sql
-- 1. 创建新用户（用于项目连接，避免使用root用户）
CREATE USER IF NOT EXISTS 'test_user'@'localhost' IDENTIFIED BY 'Test@123456';
-- 说明：'test_user' 是用户名，'localhost' 表示只能本地访问，'%' 表示可远程访问

-- 2. 给用户授权（授予test_user操作test_db数据库的所有权限）
GRANT ALL PRIVILEGES ON test_db.* TO 'test_user'@'localhost';
-- 说明：ALL PRIVILEGES 表示所有权限，test_db.* 表示test_db数据库下的所有表

-- 3. 撤销用户权限
REVOKE ALL PRIVILEGES ON test_db.* FROM 'test_user'@'localhost';

-- 4. 删除用户
DROP USER IF EXISTS 'test_user'@'localhost';

-- 5. 刷新权限（授权/撤销授权后需执行）
FLUSH PRIVILEGES;

```

# 四、数据类型与字段设计规范

MySQL支持多种数据类型，合理选择数据类型和设计字段，是保证数据库性能、数据一致性的关键。本节讲解常用数据类型，以及字段设计的核心规范，避免设计不合理导致的性能问题或数据异常。

## 4.1 常用数据类型（核心重点）

MySQL数据类型分为四大类：数值型、字符串型、日期时间型、其他类型，重点掌握以下常用类型。

### 4.1.1 数值型（存储数字）

|数据类型|说明|适用场景|
|---|---|---|
|INT|整数类型，占4字节，范围：-2147483648 ~ 2147483647|用户ID、年龄、数量等整数场景|
|BIGINT|大整数类型，占8字节，范围：-9223372036854775808 ~ 9223372036854775807|订单ID、雪花ID等需要大整数的场景|
|DECIMAL(M,D)|高精度小数类型，M表示总位数，D表示小数位数（如DECIMAL(10,2)表示最大99999999.99）|金额、价格等需要高精度的场景（禁止用FLOAT/DOUBLE，避免精度丢失）|
|TINYINT|小整数类型，占1字节，范围：-128 ~ 127（常用unsigned表示0~255）|状态值（如0-禁用、1-启用）、性别（0-女、1-男）等|
### 4.1.2 字符串型（存储文本）

|数据类型|说明|适用场景|
|---|---|---|
|VARCHAR(M)|可变长度字符串，M表示最大长度（1~65535），实际占用空间随内容长度变化|姓名、手机号、地址等长度不固定的文本（推荐首选）|
|CHAR(M)|固定长度字符串，M表示固定长度（1~255），无论内容长度，均占用M字节|身份证号、手机号（固定11位）等长度固定的文本|
|TEXT|长文本类型，最大长度65535字节（约64KB）|备注、简介等中等长度文本|
|LONGTEXT|超长文本类型，最大长度4294967295字节（约4GB）|文章内容、日志等超长文本|
补充：VARCHAR 和 CHAR 的区别：VARCHAR 可变长度，节省空间；CHAR 固定长度，查询速度快，根据文本长度是否固定选择。

### 4.1.3 日期时间型（存储时间）

|数据类型|说明|适用场景|
|---|---|---|
|DATETIME|日期时间类型，格式：YYYY-MM-DD HH:MM:SS，范围：1000-01-01 00:00:00 ~ 9999-12-31 23:59:59|创建时间、更新时间等需要完整日期时间的场景（推荐首选）|
|DATE|日期类型，格式：YYYY-MM-DD，范围：1000-01-01 ~ 9999-12-31|生日、注册日期等只需要日期的场景|
|TIME|时间类型，格式：HH:MM:SS，范围：-838:59:59 ~ 838:59:59|打卡时间、时长等只需要时间的场景|
|TIMESTAMP|时间戳类型，格式：YYYY-MM-DD HH:MM:SS，范围：1970-01-01 00:00:01 ~ 2038-01-19 03:14:07，会随时区变化|需要随时区自动调整的时间场景（慎用，避免时区问题）|
## 4.2 字段设计规范（避坑重点）

合理设计字段是数据库优化的基础，避免因设计不当导致数据冗余、性能下降、数据异常等问题，核心规范如下：

- 1.  字段类型尽量小：在满足业务需求的前提下，选择最小的合适数据类型（如年龄用TINYINT，不用INT；手机号用CHAR(11)，不用VARCHAR(20)），节省内存和磁盘空间，提升查询性能。

- 2.  避免使用NULL值：NULL值会增加查询复杂度（需用IS NULL/IS NOT NULL判断），占用额外存储空间，建议给字段设置默认值（如年龄默认0，字符串默认空字符串''）。

- 3.  主键设计规范：每个表必须有主键（唯一标识每条数据），优先使用自增主键（INT AUTO_INCREMENT）或雪花ID（BIGINT），避免使用字符串作为主键（查询速度慢），禁止使用复合主键（除非特殊场景）。

- 4.  字段命名规范：采用小写字母+下划线命名（如user_name、create_time），避免使用关键字（如user、order、date），命名要直观（见名知意），不使用缩写（除非通用缩写，如id、name）。

- 5.  金额字段规范：金额必须使用DECIMAL(M,D)类型（如DECIMAL(10,2)），禁止使用FLOAT/DOUBLE类型，避免精度丢失（如0.1+0.2用FLOAT计算会得到0.30000000447034836）。

- 6.  避免字段冗余：不重复存储相同的数据（如用户表中不存储用户所属部门名称，应存储部门ID，关联部门表查询），减少数据冗余和更新异常。

- 7.  状态字段规范：状态字段（如is_enable、status）建议使用TINYINT类型，用固定值表示状态（如0-禁用、1-启用、2-审核中），并在注释中说明每个值的含义，便于后续维护。

# 五、主流存储引擎特性对比（核心重点）

MySQL的存储引擎是数据库的核心组件，负责数据的存储和读取，不同存储引擎的特性不同，适配不同的业务场景。目前MySQL主流的存储引擎是InnoDB（默认）和MyISAM，本节对比两者的核心特性，帮助学习者选择合适的存储引擎。

补充：查看MySQL支持的存储引擎：`SHOW ENGINES;`；查看表的存储引擎：`SHOW TABLE STATUS LIKE 'user';`；创建表时指定存储引擎：`CREATE TABLE 表名 (...) ENGINE=引擎名;`。

## 5.1 核心特性对比（表格清晰呈现）

|特性|InnoDB（MySQL 8.0 默认）|MyISAM|
|---|---|---|
|事务支持|支持ACID事务（核心优势）|不支持事务|
|锁机制|支持行级锁、表级锁（并发性能好）|只支持表级锁（并发性能差）|
|外键支持|支持外键（维护数据一致性）|不支持外键|
|索引类型|聚簇索引（主键索引）+ 非聚簇索引|非聚簇索引（B+树索引）|
|数据存储|数据和索引存储在同一个文件（.ibd）|数据和索引分开存储（.MYD 数据文件，.MYI 索引文件）|
|崩溃恢复|支持崩溃恢复（基于事务日志），数据安全性高|不支持崩溃恢复，崩溃后可能丢失数据|
|查询性能|写操作（INSERT/UPDATE/DELETE）性能优，读操作性能略逊于MyISAM|读操作（SELECT）性能优，写操作性能差|
|适用场景|电商、金融等需要事务、高并发、数据安全的场景（推荐首选）|博客、新闻等只读多、写少，无需事务的场景（目前已基本淘汰）|
## 5.2 存储引擎选择建议（实战重点）

- 1.  优先选择InnoDB：MySQL 8.0默认存储引擎，支持事务、行级锁、外键，数据安全性高，适配绝大多数业务场景（如电商、后台管理系统、金融系统）。

- 2.  谨慎选择MyISAM：仅适用于只读多、写少，无需事务的简单场景（如静态网站、日志存储），目前已基本被InnoDB替代，不推荐用于生产环境。

- 3.  特殊场景选择：若需要极致的读性能，且无需事务、外键，可考虑MyISAM；若需要分区表、全文索引（MySQL 8.0 InnoDB已支持全文索引），优先选择InnoDB。

补充：MySQL 8.0 中，MyISAM已被标记为“过时”，后续版本可能会移除，因此生产环境优先使用InnoDB，避免后续迁移成本。

# 六、总结（入门必会）

1.  核心回顾：本章重点讲解了MySQL基础入门的四大核心内容，包括环境安装与配置（Windows/Linux）、SQL基础语法（DDL/DML/DQL/DCL）、数据类型与字段设计规范、主流存储引擎对比，是后续章节学习的基础。

2.  实操重点：环境安装需注意端口、密码、配置文件的设置，确保服务正常启动；SQL语法需熟练掌握基础操作（创建数据库/表、插入/修改/查询数据），重点注意WHERE条件的使用，避免误操作；字段设计需遵循规范，选择合适的数据类型。

3.  核心结论：InnoDB是目前MySQL的主流存储引擎，支持事务、行级锁，适配绝大多数业务场景；MyISAM已基本淘汰，仅适用于特殊只读场景。

4.  学习建议：本章内容以实操为主，建议学习者亲自搭建MySQL环境，执行每一条SQL语句，熟悉语法细节和操作流程；重点记忆数据类型选择、字段设计规范和存储引擎特性，为后续索引、事务等进阶内容筑牢基础。