# 02-Redis五大基础数据结构&底层原理

前言：本文承接上一篇基础入门，重点讲解Redis五大核心基础数据结构（String、List、Hash、Set、ZSet），包含「基础使用命令+底层实现原理」，仅覆盖核心知识点，不涉及进阶用法（如高级命令、集群下的适配等），适配新手入门。

# 1. 字符串（String）—— 最基础、最常用的数据结构

## 1.1 核心定义

String是Redis最基础的数据结构，本质是**动态字符串（Simple Dynamic String，SDS）**，而非C语言中的字符串（char*），可以存储字符串、数字（整数/浮点数）、二进制数据（如图片、视频片段），最大存储容量为512MB。

## 1.2 基础使用命令

```redis
# 1. 存储字符串（最基础命令）
set key value  # 覆盖式存储，若key已存在则替换value
setnx key value # 仅当key不存在时存储，存在则不操作（防覆盖）

# 2. 获取字符串
get key        # 若key不存在，返回nil

# 3. 追加字符串（在原有value末尾添加）
append key "newContent"

# 4. 字符串长度
strlen key

# 5. 数字操作（仅当value是整数时可用）
incr key       # 自增1
decr key       # 自减1
incrby key 10  # 自增指定数值
decrby key 5   # 自减指定数值

# 6. 批量操作（高效）
mset key1 val1 key2 val2 # 批量存储多个key-value
mget key1 key2           # 批量获取多个key的value

# 7. 设置过期时间（结合String使用，常用缓存场景）
setex key 3600 value # 存储key-value，同时设置1小时过期
```

## 1.3 底层原理

String底层采用**SDS（简单动态字符串）**实现，而非C语言原生字符串，核心优势是「动态扩容、二进制安全、避免缓冲区溢出」。

- SDS结构：由「len（已使用长度）、free（空闲长度）、buf（字节数组）」三部分组成；

- 动态扩容：当追加字符串时，若free不足，会自动扩容（扩容规则：len<1MB时，扩容为原来的2倍；len≥1MB时，每次扩容增加1MB）；

- 二进制安全：SDS不以「\0」作为字符串结束标志，可存储任意二进制数据（如图片、音频）；

- 对比C字符串：解决了C字符串“长度计算耗时、无法动态扩容、缓冲区溢出”的问题。

## 1.4 常见使用场景

缓存用户信息（序列化后存储）、验证码存储（设置短期过期）、计数器（如文章阅读量、接口访问量）、分布式锁（基础版setnx）。

# 2. 列表（List）—— 有序、可重复的“链表”

## 2.1 核心定义

List是Redis中的有序列表，元素可重复，支持从「头部（left）」和「尾部（right）」进行插入、删除、查询操作，底层实现随元素数量动态切换，是典型的“双端链表”结构（少量元素时用压缩列表优化）。

## 2.2 基础使用命令

```redis
# 1. 从尾部插入元素（最常用）
rpush key val1 val2 val3 # 向key对应的列表尾部添加1个或多个元素

# 2. 从头部插入元素
lpush key val1 val2      # 向列表头部添加1个或多个元素

# 3. 从尾部删除元素（返回删除的元素）
rpop key

# 4. 从头部删除元素（返回删除的元素）
lpop key

# 5. 查看列表元素（核心）
lrange key 0 -1 # 查看列表所有元素（0是第一个，-1是最后一个）
lindex key 2    # 查看列表中索引为2的元素（索引从0开始）
llen key        # 查看列表的长度

# 6. 移除指定元素
lrem key 2 val  # 从列表中删除2个值为val的元素（正数从头部开始，负数从尾部开始）

# 7. 阻塞式弹出（常用在消息队列场景）
blpop key 10    # 若列表为空，阻塞10秒；若有元素，立即弹出头部元素
brpop key 10    # 阻塞式弹出尾部元素
```

## 2.3 底层原理

List底层采用「双端链表（linkedlist）」和「压缩列表（ziplist）」两种结构动态切换（Redis 3.2+版本优化）：

- 当列表元素数量少（≤512个）且每个元素长度短（≤64字节）时，使用「压缩列表（ziplist）」，节省内存；

- 当元素数量或长度超过阈值时，自动切换为「双端链表（linkedlist）」，保证插入、删除效率（O(1)）；

- 双端链表优势：每个节点有prev和next指针，可快速定位头部和尾部元素，插入/删除无需移动大量元素。

## 2.4 常见使用场景

消息队列（基础版，用lpush+rpop/brpop）、最新消息展示（如朋友圈最新动态）、栈（lpush+lpop）、队列（lpush+rpop）。

# 3. 哈希（Hash）—— 适合存储“对象”的数据结构

## 3.1 核心定义

Hash是Redis中的“键值对集合”，本质是「字段（field）和值（value）的映射表」，适合存储一个对象（如用户信息、商品信息），每个Hash可以包含多个field-value对，查询单个字段效率极高。

## 3.2 基础使用命令

```redis
# 1. 存储Hash对象（单个field-value）
hset key field value # 向key对应的Hash中添加一个field-value

# 2. 批量存储Hash对象
hmset key field1 val1 field2 val2 # 批量添加多个field-value

# 3. 获取Hash中的字段值
hget key field       # 获取指定field的值
hmget key field1 field2 # 批量获取多个field的值
hgetall key          # 获取Hash中所有field-value（注意：大Hash慎用，会阻塞）

# 4. 查看Hash的相关信息
hlen key             # 查看Hash中field的数量
hexists key field    # 检查Hash中是否存在指定field（1存在，0不存在）

# 5. 删除Hash中的字段
hdel key field1 field2 # 删除Hash中的1个或多个field

# 6. 查看Hash中所有field/所有value
hkeys key            # 查看所有field
hvals key            # 查看所有value
```

## 3.3 底层原理

Hash底层与List类似，采用「压缩列表（ziplist）」和「哈希表（dict）」动态切换：

- 当Hash中field数量少（≤512个）且每个field和value长度短（≤64字节）时，使用「压缩列表（ziplist）」，节省内存；

- 当超过阈值时，切换为「哈希表（dict）」，哈希表采用“数组+链表”结构，解决哈希冲突（链地址法）；

- 优势：查询单个field的效率为O(1)，无需遍历整个对象，比将对象序列化后存在String中更灵活。

## 3.4 常见使用场景

存储用户信息（如user:info:1001，field为name、age、phone）、商品信息、配置项存储（每个配置项作为一个field）。

# 4. 集合（Set）—— 无序、不可重复的“集合”

## 4.1 核心定义

Set是Redis中的无序集合，元素不可重复，支持交集、并集、差集等集合运算，底层基于哈希表实现，查找元素的效率极高（O(1)）。

## 4.2 基础使用命令

```redis
# 1. 向Set中添加元素（不可重复）
sadd key val1 val2 val3 # 向key对应的Set中添加1个或多个元素，重复元素会自动去重

# 2. 查看Set中的所有元素
smembers key           # 查看Set中所有元素（无序）

# 3. 查看Set的元素数量
scard key              # 返回Set中元素的个数

# 4. 检查元素是否在Set中
sismember key val      # 1存在，0不存在（O(1)效率）

# 5. 从Set中删除元素
srem key val1 val2     # 删除Set中的1个或多个元素

# 6. 随机获取Set中的元素
srandmember key 2      # 随机获取2个元素，不删除
spop key               # 随机删除并返回1个元素

# 7. 集合运算（核心优势）
sinter key1 key2       # 求key1和key2的交集（共同元素）
sunion key1 key2       # 求key1和key2的并集（所有元素，去重）
sdiff key1 key2        # 求key1相对于key2的差集（key1有、key2没有的元素）
```

## 4.3 底层原理

Set底层采用「哈希表（dict）」实现，核心逻辑是：

- 将Set中的每个元素作为「哈希表的key」，value统一设为null（仅用key来保证唯一性）；

- 利用哈希表的特性，实现“元素不可重复”和“O(1)查找效率”；

- 补充：当Set中元素是整数且数量较少（≤512个）时，会使用「整数集合（intset）」优化，进一步节省内存。

## 4.4 常见使用场景

用户标签（如用户喜欢的分类）、好友列表（去重）、共同好友/推荐好友（交集运算）、抽奖活动（spop随机抽取）。

# 5. 有序集合（ZSet）—— 有序、不可重复，带“分数”的集合

## 5.1 核心定义

ZSet（Sorted Set）是Redis中最特殊的基础数据结构，兼具「Set的不可重复性」和「List的有序性」，每个元素都关联一个「分数（score）」，Redis通过分数为元素排序（升序/降序），底层实现最复杂，效率也极高。

## 5.2 基础使用命令

```redis
# 1. 向ZSet中添加元素（score+value，不可重复）
zadd key score1 val1 score2 val2 # 添加元素，若val已存在，会更新其score

# 2. 查看ZSet中的元素（按score排序）
zrange key 0 -1 withscores # 按score升序，查看所有元素及分数
zrevrange key 0 -1 withscores # 按score降序，查看所有元素及分数

# 3. 查看ZSet的元素数量
zcard key              # 返回ZSet中元素的个数

# 4. 查看元素的score
zscore key val         # 返回指定val对应的score

# 5. 按score范围查询元素
zrangebyscore key 10 20 withscores # 查看score在10~20之间的元素（升序）
zrevrangebyscore key 20 10 withscores # 降序查询

# 6. 删除ZSet中的元素
zrem key val1 val2     # 删除指定val的元素
zremrangebyscore key 0 10 # 删除score在0~10之间的元素

# 7. 查看元素的排名
zrank key val          # 按score升序，返回元素的排名（从0开始）
zrevrank key val       # 按score降序，返回元素的排名
```

## 5.3 底层原理

ZSet底层采用「压缩列表（ziplist）」和「跳表（skiplist）+ 哈希表（dict）」动态切换：

- 当ZSet中元素数量少（≤128个）且每个元素长度短（≤64字节）时，使用「压缩列表（ziplist）」，节省内存；

- 当超过阈值时，切换为「跳表（skiplist）+ 哈希表」的组合结构：
        

    - 跳表（skiplist）：负责按score排序，支持快速插入、删除、范围查询（效率接近红黑树，实现更简单）；

    - 哈希表（dict）：负责映射“元素val → score”，支持O(1)查询元素的score；

- 核心优势：兼顾“有序性”和“高效查询”，范围查询效率远高于其他数据结构。

## 5.4 常见使用场景

排行榜（如文章点赞榜、商品销量榜）、带权重的消息队列、范围查询（如查询分数前10的用户）。

# 6. 五大数据结构核心对比

|数据结构|核心特点|底层结构（极简）|核心场景|
|---|---|---|---|
|String|单值键值对，可存字符串/数字/二进制|SDS（动态字符串）|缓存、计数器、验证码|
|List|有序、可重复，双端操作|ziplist + linkedlist|消息队列、最新动态|
|Hash|键值对集合，适合存对象|ziplist + dict|用户/商品信息存储|
|Set|无序、不可重复，支持集合运算|intset + dict|用户标签、共同好友|
|ZSet|有序、不可重复，带score|ziplist + skiplist + dict|排行榜、范围查询|
# 7. 新手避坑要点

- Hash的hgetall命令：大Hash（field数量多）慎用，会阻塞Redis进程，建议用hmget查询指定field；

- ZSet的score：可以是整数或浮点数，但尽量用整数（避免浮点数精度问题）；

- Set和ZSet的去重：两者都自动去重，但ZSet会按score排序，Set无序，根据场景选择；

- 底层结构切换：无需手动干预，Redis会根据元素数量和长度自动切换，核心是“内存和效率平衡”。