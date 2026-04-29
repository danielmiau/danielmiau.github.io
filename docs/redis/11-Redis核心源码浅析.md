# 11-Redis核心源码浅析.md

前言：本文承接第十章Java客户端与实战，聚焦Redis核心源码解析，延续前十章的排版规范、内容深度与语言风格，不涉及复杂的底层编译细节，重点拆解Redis核心模块（事件驱动、内存管理、数据结构、持久化、集群）的源码逻辑、核心流程与设计思想。本章兼顾中高级进阶知识点（如Redis事件循环、数据结构实现、持久化原理）与源码实操解读，全程保持与前十章一致的代码注释风格、排版逻辑，助力开发者从“会用Redis”进阶到“理解Redis底层实现”，掌握Redis核心设计的精髓，同时规避源码学习中的常见误区。

# 一、Redis源码入门基础

## 1.1 源码环境准备

Redis源码基于C语言开发（最新稳定版6.x+），结构清晰、模块化强，无需复杂的依赖配置，仅需基础的C语言编译环境即可完成源码编译与调试，核心准备步骤如下（适配Linux/Mac环境，Windows可通过WSL实现）：

```bash
# 1. 下载Redis源码（推荐稳定版6.2.x，与前序章节环境一致）
wget https://download.redis.io/releases/redis-6.2.13.tar.gz

# 2. 解压源码包
tar -zxvf redis-6.2.13.tar.gz

# 3. 进入源码目录，编译源码（依赖gcc环境，无gcc需先安装：yum install gcc -y）
cd redis-6.2.13
make

# 4. 编译完成后，生成可执行文件（位于src目录下）
# redis-server：Redis服务端程序
# redis-cli：Redis客户端程序
# redis-check-aof：AOF持久化校验工具
# redis-check-rdb：RDB持久化校验工具
```

补充：源码核心目录说明（重点关注src目录），与前十章讲解的Redis功能一一对应，便于关联理解：

- src/server.c：Redis服务端核心入口，包含主函数、事件循环、核心流程调度。

- src/redis.h：核心数据结构定义（如客户端、服务端、键值对、事件等）。

- src/dict.c/dict.h：字典（Hash表）实现，Redis核心数据结构，用于存储键值对。

- src/ziplist.c/ziplist.h：压缩列表实现，用于List、Hash、ZSet的底层优化存储。

- src/quicklist.c/quicklist.h：快速列表实现，Redis 3.2+后List的底层存储结构。

- src/rdb.c/rdb.h：RDB持久化核心实现，负责RDB文件的生成与加载。

- src/aof.c/aof.h：AOF持久化核心实现，负责AOF日志的写入、重写与加载。

- src/cluster.c/cluster.h：Redis集群核心实现，负责集群节点通信、槽位分配。

- src/evict.c：内存淘汰策略实现，对应前九章讲解的内存管理机制。

## 1.2 源码核心设计思想

Redis源码的核心设计思想贯穿所有模块，也是面试中高频考察的重点，结合前十章的功能讲解，提炼4个核心设计思想，便于后续源码解读：

- 单线程模型：Redis服务端核心逻辑（命令处理、事件循环）采用单线程，避免多线程上下文切换的开销，通过IO多路复用（epoll/kqueue）处理并发连接，兼顾高性能与简洁性。

- 模块化设计：每个核心功能（数据结构、持久化、集群、内存管理）独立成模块，模块间通过统一接口通信，降低耦合度，便于扩展与维护。

- 惰性操作：Redis大量采用惰性策略（如惰性删除、惰性加载），避免不必要的性能开销，提升核心流程的执行效率（如键过期时不立即删除，而是在访问时校验）。

- 底层优化：针对不同场景选择最优的数据结构（如Hash表用于键值对存储、压缩列表用于小数据存储），结合内存池管理，减少内存碎片，提升内存利用率。

# 二、Redis核心模块源码解读（重点）

本节聚焦Redis最核心的5个模块，拆解源码中的关键逻辑与核心流程，不深入复杂的底层细节，重点关联前十章讲解的功能，让开发者理解“功能如何通过源码实现”，每个模块均提炼核心源码片段与解读，贴合面试考点。

## 2.1 事件驱动模型源码（Redis高性能核心）

Redis的高性能核心源于“单线程+IO多路复用”的事件驱动模型，核心源码位于src/server.c和src/ae.c（ae即Redis的事件驱动框架），重点解读事件循环的核心流程与IO多路复用的实现。

### 2.1.1 事件驱动核心结构（aeEventLoop）

Redis通过aeEventLoop结构体管理所有事件（文件事件、时间事件），是事件驱动模型的核心，源码片段（简化版，保留核心字段）如下：

```c
// src/ae.h 核心结构体定义
typedef struct aeEventLoop {
    int maxfd;                     // 最大文件描述符
    int setsize;                   // 事件集大小
    long long timeEventNextId;     // 时间事件ID计数器
    aeFileEvent *events;           // 文件事件数组（存储所有注册的文件事件）
    aeTimeEvent *timeEventHead;    // 时间事件链表（存储所有注册的时间事件）
    aeApiState *apidata;           // IO多路复用底层数据（适配epoll/kqueue等）
    int stop;                      // 事件循环停止标志
} aeEventLoop;

// 文件事件结构体（存储单个文件事件，如客户端连接、数据读取）
typedef struct aeFileEvent {
    int mask;                      // 事件类型掩码（读事件AE_READABLE、写事件AE_WRITABLE）
    aeFileProc *rfileProc;         // 读事件回调函数（如客户端发送命令时触发）
    aeFileProc *wfileProc;         // 写事件回调函数（如向客户端返回结果时触发）
    void *clientData;              // 客户端私有数据（关联客户端结构体）
} aeFileEvent;

// 时间事件结构体（存储单个时间事件，如定时任务、过期键清理）
typedef struct aeTimeEvent {
    long long id;                  // 时间事件ID
    long long when_sec;            // 事件触发的秒数
    long long when_ms;             // 事件触发的毫秒数
    aeTimeProc *timeProc;          // 时间事件回调函数
    aeEventFinalizerProc *finalizerProc; // 事件结束回调函数
    void *clientData;              // 私有数据
    struct aeTimeEvent *next;      // 链表指针，连接下一个时间事件
} aeTimeEvent;
```

解读：aeEventLoop是事件循环的核心载体，管理所有文件事件（与客户端的网络交互）和时间事件（定时任务），IO多路复用通过apidata字段适配不同操作系统（Linux用epoll，Mac用kqueue），保证跨平台兼容性。

### 2.1.2 事件循环核心流程（aeMain）

Redis服务端启动后，会进入aeMain函数，开启无限事件循环，核心流程为“等待事件→处理事件→循环执行”，源码片段（简化版）如下：

```c
// src/ae.c 事件循环主函数
void aeMain(aeEventLoop *eventLoop) {
    eventLoop->stop = 0;
    // 无限循环，直到stop被置为1（如Redis服务关闭）
    while (!eventLoop->stop) {
        // 1. 等待事件触发（阻塞，超时时间由时间事件决定）
        aeProcessEvents(eventLoop, AE_ALL_EVENTS);
    }
}

// 处理所有触发的事件
int aeProcessEvents(aeEventLoop *eventLoop, int flags) {
    int processed = 0;
    // 1. 处理时间事件（如过期键清理、AOF重写检查）
    if (flags & AE_TIME_EVENTS) {
        processed += processTimeEvents(eventLoop);
    }
    // 2. 处理文件事件（如客户端连接、命令读取与返回）
    if (flags & AE_FILE_EVENTS) {
        processed += aeApiPoll(eventLoop, tvp); // 调用IO多路复用接口，获取就绪事件
    }
    return processed;
}
```

解读：事件循环的核心逻辑的是aeMain函数，循环调用aeProcessEvents处理时间事件和文件事件：

- 文件事件：对应客户端的网络交互（如连接建立、命令发送、结果返回），由IO多路复用（epoll）监听，就绪后触发回调函数处理。

- 时间事件：对应定时任务（如每秒执行10次的过期键清理、AOF重写定时检查、集群节点心跳检测），由processTimeEvents函数处理。

补充：IO多路复用的核心实现（aeApiPoll），在Linux环境下底层调用epoll_wait，监听多个文件描述符的就绪状态，避免单线程阻塞在单个IO操作上，这也是Redis单线程能处理高并发的关键。

## 2.2 核心数据结构源码（与前序章节对应）

Redis的核心数据结构（String、Hash、List、Set、ZSet）的底层实现的是面试高频考点，本节结合前六章讲解的底层结构，解读核心源码片段，重点关注“结构设计”与“核心操作”。

### 2.2.1 字典（Dict）源码（Hash表核心）

Redis的键值对存储核心是字典（Dict），底层采用Hash表实现，支持动态扩容/缩容，源码位于src/dict.c/dict.h，核心结构体与插入操作如下：

```c
// src/dict.h 字典核心结构体
typedef struct dict {
    dictType *type;                // 字典类型（自定义哈希、比较、销毁函数）
    void *privdata;                // 私有数据
    dictht ht[2];                  // 两个Hash表（用于扩容/缩容时的渐进式迁移）
    long rehashidx;                // 重哈希索引（-1表示未进行重哈希）
    unsigned long iterators;       // 迭代器数量（用于防止重哈希时迭代器失效）
} dict;

// Hash表结构体
typedef struct dictht {
    dictEntry **table;             // Hash表数组（存储dictEntry指针）
    unsigned long size;            // Hash表大小（2的幂次）
    unsigned long sizemask;        // 掩码，用于计算Hash索引（size-1）
    unsigned long used;            // 已使用的节点数量
} dictht;

// Hash表节点（存储单个键值对）
typedef struct dictEntry {
    void *key;                     // 键（Redis中键均为String类型）
    union {                        // 值（支持多种类型）
        void *val;
        uint64_t u64;
        int64_t s64;
        double d;
    } v;
    struct dictEntry *next;        // 链表指针，解决Hash冲突（链地址法）
} dictEntry;
```

解读：字典的核心设计是“双Hash表”，用于渐进式重哈希（扩容/缩容），避免一次性重哈希导致的服务阻塞：

- ht[0]：当前正在使用的Hash表。

- ht[1]：扩容/缩容时使用的新Hash表，迁移完成后替换ht[0]。

- rehashidx：记录重哈希的进度，每次事件循环迁移少量节点，实现渐进式迁移，不阻塞服务。

核心操作（dictAdd，简化版源码）：

```c
// 向字典中添加键值对
int dictAdd(dict *d, void *key, void *val) {
    // 1. 计算键的Hash值，获取索引
    dictEntry *entry = dictAddRaw(d, key, NULL);
    if (!entry) return DICT_ERR;
    // 2. 设置节点的值
    dictSetVal(d, entry, val);
    return DICT_OK;
}

// 计算Hash索引，处理Hash冲突
dictEntry *dictAddRaw(dict *d, void *key, dictEntry **existing) {
    // 1. 检查是否需要进行重哈希
    if (dictIsRehashing(d)) _dictRehashStep(d);
    // 2. 计算Hash值和索引
    unsigned int h = dictHashKey(d, key);
    int index = h & d->ht[0].sizemask;
    // 3. 遍历链表，检查键是否已存在（避免重复）
    dictEntry *he = d->ht[0].table[index];
    while (he) {
        if (dictCompareKeys(d, key, he->key)) {
            if (existing) *existing = he;
            return NULL;
        }
        he = he->next;
    }
    // 4. 创建新节点，插入链表头部
    dictEntry *ne = zmalloc(sizeof(*ne));
    ne->key = key;
    ne->next = d->ht[0].table[index];
    d->ht[0].table[index] = ne;
    d->ht[0].used++;
    return ne;
}
```

### 2.2.2 快速列表（Quicklist）源码（List底层实现）

Redis 3.2+后，List的底层实现由“压缩列表+双向链表”改为快速列表（Quicklist），兼顾内存利用率和操作效率，源码位于src/quicklist.c/quicklist.h，核心结构体如下：

```c
// src/quicklist.h 快速列表核心结构体
typedef struct quicklist {
    quicklistNode *head;           // 链表头节点
    quicklistNode *tail;           // 链表尾节点
    unsigned long count;           // 所有节点中的元素总数
    unsigned long len;             // 快速列表的节点数量
    int fill : QL_FILL_BITS;       // 每个节点的最大元素数（由list-max-ziplist-size配置）
    unsigned int compress : QL_COMPRESS_BITS; // 压缩深度（由list-compress-depth配置）
    unsigned int bookmark_count: QL_BOOKMARK_BITS; // 书签数量
    quicklistBookmark bookmarks[]; // 书签数组（用于快速定位）
} quicklist;

// 快速列表节点结构体
typedef struct quicklistNode {
    struct quicklistNode *prev;    // 前驱节点指针
    struct quicklistNode *next;    // 后继节点指针
    unsigned char *zl;             // 压缩列表（存储实际元素）
    unsigned int sz;               // 压缩列表的字节大小
    unsigned int count : 16;       // 压缩列表中的元素数量
    unsigned int encoding : 2;     // 编码方式（RAW/ZIPLIST）
    unsigned int container : 2;    // 容器类型（ZLIST/OTHER）
    unsigned int recompress : 1;   // 是否需要重新压缩
    unsigned int attempted_compress : 1; // 是否尝试过压缩
    unsigned int extra : 10;       // 预留字段
} quicklistNode;
```

解读：快速列表的核心设计是“双向链表+压缩列表”，每个quicklistNode节点内部存储一个压缩列表（ziplist），既减少了链表节点的内存开销，又通过压缩列表提升了小数据的存储效率，与前六章讲解的List底层优化完全对应：

- fill字段：控制每个压缩列表的最大元素数，由配置list-max-ziplist-size决定，默认8。

- compress字段：控制压缩深度，由配置list-compress-depth决定，默认0（不压缩），用于减少内存占用。

- zl字段：指向压缩列表，存储实际的List元素，当元素过多或过大时，会拆分节点。

### 2.2.3 其他核心数据结构（简化解读）

结合前六章内容，简化解读另外3种核心数据结构的源码核心，聚焦面试考点：

- String：底层是简单动态字符串（SDS），源码位于src/sds.c/sds.h，核心是“动态扩容+二进制安全”，避免C语言原生字符串的缺陷，支持高效的append、len等操作。

- ZSet：底层是“字典+跳表”，源码位于src/zset.c/zset.h，字典用于存储“成员→分数”的映射，跳表用于按分数排序，支持高效的范围查询（如zrange、zrevrange）。

- Hash：底层默认是压缩列表（ziplist），当元素数量或大小超过阈值（hash-max-ziplist-entries、hash-max-ziplist-value）时，转为字典（dict），源码逻辑与List类似，兼顾内存与效率。

## 2.3 持久化模块源码（RDB+AOF）

Redis的持久化机制（RDB、AOF）是生产环境中保障数据安全的核心，源码分别位于src/rdb.c和src/aof.c，重点解读核心流程（生成、加载），关联前九章的持久化最佳实践。

### 2.3.1 RDB持久化源码（核心流程）

RDB持久化的核心是“快照生成”与“快照加载”，触发时机分为手动触发（save、bgsave）和自动触发（配置触发），核心源码片段如下：

```c
// src/rdb.c 手动触发bgsave（后台生成RDB，不阻塞服务）
int rdbSaveBackground(char *filename) {
    pid_t childpid;
    long long start;

    // 1. 检查是否正在进行RDB/AOF操作，避免并发
    if (server.rdb_child_pid != -1 || server.aof_child_pid != -1) return C_ERR;

    start = ustime();
    // 2. 创建子进程，由子进程负责生成RDB文件（父进程继续处理客户端请求）
    if ((childpid = fork()) == 0) {
        // 子进程逻辑：生成RDB文件
        if (rdbSave(filename) == C_OK) {
            exit(0);
        } else {
            exit(1);
        }
    } else if (childpid == -1) {
        // fork失败，返回错误
        return C_ERR;
    }
    // 3. 父进程记录子进程ID，等待子进程完成
    server.rdb_child_pid = childpid;
    server.rdb_save_time_start = start;
    return C_OK;
}

// 生成RDB文件核心函数（rdbSave，简化版）
int rdbSave(char *filename) {
    FILE *fp;
    rio rdb;
    int error = 0;

    // 1. 打开文件，准备写入
    if ((fp = fopen(filename, "w")) == NULL) return C_ERR;
    // 2. 初始化rio结构体（Redis的IO抽象层，支持文件、内存等IO操作）
    rioInitWithFile(&rdb, fp);
    // 3. 写入RDB文件头部（魔数、版本号等）
    if (rdbSaveMagicNumber(&rdb) == C_ERR) error = 1;
    // 4. 写入数据库中的键值对（遍历所有字典，序列化存储）
    if (!error && rdbSaveDb(&rdb, server.db) == C_ERR) error = 1;
    // 5. 写入RDB文件尾部（校验和）
    if (!error && rdbSaveEnd(&rdb) == C_ERR) error = 1;

    // 6. 关闭文件，返回结果
    fclose(fp);
    if (error) {
        unlink(filename);
        return C_ERR;
    } else {
        return C_OK;
    }
}
```

解读：RDB持久化的核心设计是“子进程生成快照”，避免阻塞主进程（单线程），核心流程与前九章讲解的一致：

- bgsave：创建子进程，子进程负责遍历数据库、序列化键值对、写入RDB文件，父进程继续处理客户端请求。

- rdbSave：核心是序列化键值对，根据不同的数据结构（dict、ziplist等）采用不同的序列化方式，确保数据能正确加载。

- RDB加载：Redis启动时，会自动检测RDB文件，调用rdbLoad函数加载数据，反向序列化键值对到数据库中。

### 2.3.2 AOF持久化源码（核心流程）

AOF持久化的核心是“命令日志写入”与“日志重写”，采用“写后日志”模式，确保命令的持久性，核心源码片段如下：

```c
// src/aof.c 写入AOF日志（命令执行后写入）
void feedAppendOnlyFile(struct redisCommand *cmd, int dictid, robj **argv, int argc) {
    sds buf = sdsempty();
    struct redisClient *c = server.current_client;

    // 1. 拼接命令字符串（如"SET key value\r\n"）
    buf = catAppendOnlyGenericCommand(buf, cmd, dictid, argv, argc, c->db->id);
    // 2. 写入AOF缓冲区（避免频繁写入磁盘，提升性能）
    if (server.aof_state == AOF_ON) {
        redisAppendToFile(server.aof_fd, buf, sdslen(buf));
        // 3. 根据配置，决定是否立即刷盘（appendfsync配置）
        if (server.aof_fsync == AOF_FSYNC_ALWAYS) {
            redis_fsync(server.aof_fd);
        } else if (server.aof_fsync == AOF_FSYNC_EVERYSEC &&
                   server.aof_last_fsync < server.unixtime) {
            redis_fsync(server.aof_fd);
            server.aof_last_fsync = server.unixtime;
        }
    }
    sdsfree(buf);
}

// AOF重写核心函数（bgrewriteaof，后台重写，避免阻塞）
int aofRewriteBackground(void) {
    pid_t childpid;

    // 1. 检查是否正在进行重写或RDB操作
    if (server.aof_child_pid != -1 || server.rdb_child_pid != -1) return C_ERR;

    // 2. 创建子进程，由子进程负责重写AOF文件
    if ((childpid = fork()) == 0) {
        // 子进程逻辑：重写AOF文件（遍历数据库，生成最简命令集）
        char *filename = aofRewriteTempFileName();
        if (aofRewrite(filename) == C_OK) {
            aofRewriteRename(filename); // 重写完成，替换旧AOF文件
            exit(0);
        } else {
            unlink(filename);
            exit(1);
        }
    } else if (childpid == -1) {
        return C_ERR;
    }
    // 3. 父进程记录子进程ID，继续处理请求
    server.aof_child_pid = childpid;
    return C_OK;
}
```

解读：AOF持久化的核心设计是“缓冲区+后台重写”，兼顾性能与数据安全性，与前九章讲解的AOF配置完全对应：

- feedAppendOnlyFile：命令执行后，将命令拼接为字符串，写入AOF缓冲区，再根据appendfsync配置决定刷盘时机（always/everysec/no）。

- bgrewriteaof：后台重写AOF文件，子进程遍历数据库，生成最简命令集（如多次SET同一key，只保留最后一次），减少AOF文件体积，避免日志膨胀。

- AOF加载：Redis启动时，若开启AOF，会读取AOF文件，重新执行日志中的命令，恢复数据，优先级高于RDB。

## 2.4 内存管理与淘汰策略源码

Redis的内存管理核心是“内存池+惰性删除+内存淘汰”，源码位于src/zmalloc.c（内存池）和src/evict.c（内存淘汰），重点解读内存淘汰策略的实现，关联前九章的内存管理最佳实践。

```c
// src/evict.c 内存淘汰核心函数（当内存达到maxmemory时触发）
int freeMemoryIfNeeded(void) {
    size_t mem_used, mem_tofree, mem_freed;
    int j, k, i;

    // 1. 计算当前已使用内存，判断是否需要淘汰
    mem_used = zmalloc_used_memory();
    if (mem_used < server.maxmemory) return C_OK;

    // 2. 计算需要释放的内存大小
    mem_tofree = mem_used - server.maxmemory;
    mem_freed = 0;

    // 3. 根据配置的内存淘汰策略，执行淘汰逻辑
    while (mem_freed < mem_tofree) {
        int bestdbid = -1;
        struct dictEntry *bestentry = NULL;
        // 遍历所有数据库，寻找待淘汰的键
        for (j = 0; j < server.dbnum; j++) {
            struct redisDb *db = server.db + j;
            dict *d = db->dict;
            if (dictSize(d) == 0) continue;

            // 根据淘汰策略，选择待淘汰的键
            if (server.maxmemory_policy == MAXMEMORY_ALLKEYS_LRU) {
                // 所有键采用LRU策略（最近最少使用）
                de = dictGetRandomKey(d);
                // 省略LRU评分逻辑，选择评分最低的键
            } else if (server.maxmemory_policy == MAXMEMORY_VOLATILE_LRU) {
                // 只淘汰设置了过期时间的键，采用LRU策略
                de = dictFindExpiredKey(d);
            }
            // 省略其他淘汰策略（如LFU、TTL、RANDOM）的逻辑
        }

        // 4. 淘汰选中的键，释放内存
        if (bestentry == NULL) return C_ERR; // 无键可淘汰，返回错误
        dbDelete(server.db + bestdbid, &bestkey);
        mem_freed += zmalloc_size(bestentry);
    }
    return C_OK;
}
```

解读：内存淘汰策略的核心逻辑是freeMemoryIfNeeded函数，当内存使用量超过maxmemory配置时，触发淘汰：

- 淘汰策略分支：根据maxmemory_policy配置，执行对应的淘汰逻辑（LRU、LFU、TTL、RANDOM等），与前九章讲解的淘汰策略完全对应。

- 键选择逻辑：遍历所有数据库，根据策略筛选待淘汰的键（如LRU策略选择最近最少使用的键），淘汰后释放内存，直到内存使用量低于maxmemory。

- 内存池：Redis通过zmalloc系列函数（src/zmalloc.c）管理内存，采用内存池机制，预先分配内存块，减少内存碎片，提升内存分配效率。

## 2.5 集群模块源码（核心简化）

Redis集群的核心是“槽位分配+节点通信”，源码位于src/cluster.c，重点解读槽位分配与节点心跳的核心逻辑，关联前八章的集群配置与运维。

```c
// src/cluster.h 集群节点结构体（简化版）
typedef struct clusterNode {
    char name[CLUSTER_NAMELEN];    // 节点ID（唯一标识）
    int flags;                     // 节点状态（主节点、从节点、故障节点等）
    unsigned char slots[CLUSTER_SLOTS/8]; // 节点负责的槽位（位图存储，16384个槽位）
    int numslots;                  // 节点负责的槽位数量
    struct clusterNode *master;    // 主节点指针（从节点特有）
    struct clusterNode *slaveof;   // 从节点指针（主节点特有）
    list *slaves;                  // 从节点列表（主节点特有）
    long long ping_sent;           // 最后一次发送ping的时间
    long long pong_received;       // 最后一次接收pong的时间
} clusterNode;

// src/cluster.c 槽位分配核心函数
void clusterAddSlot(clusterNode *node, int slot) {
    // 1. 检查槽位是否已被分配
    if (clusterSlotIsAssigned(slot)) {
        clusterNode *oldnode = clusterGetSlotNode(slot);
        // 移除旧节点的槽位
        clusterDelSlot(oldnode, slot);
    }
    // 2. 将槽位分配给新节点（位图置1）
    node->slots[slot/8] |= (1 << (slot%8));
    node->numslots++;
    // 3. 广播槽位分配信息，同步给所有集群节点
    clusterBroadcastPong(CLUSTER_BROADCAST_ALL);
}
```

解读：Redis集群的核心源码逻辑与前八章讲解的集群机制一致：

- 槽位管理：通过clusterNode结构体的slots位图（16384个槽位）管理节点负责的槽位，clusterAddSlot函数用于分配槽位，分配后广播给所有节点，保证集群一致性。

- 节点通信：通过ping/pong消息实现节点间的心跳检测，判断节点状态（正常/故障），故障节点会被标记，触发主从切换或槽位迁移。

- 主从切换：当主节点故障时，从节点通过投票机制选举新的主节点，接管原主节点的槽位，保证集群高可用。

# 三、Redis源码面试高频考点（重点总结）

结合本章源码解读与前十章内容，提炼Redis源码面试中最常考察的考点，整理为核心问答形式，便于记忆与应对面试。

- 考点1：Redis单线程为什么能处理高并发？
答：核心是“单线程+IO多路复用”，单线程避免多线程上下文切换开销，IO多路复用（epoll）监听多个客户端连接的就绪事件，同时处理多个客户端的请求，无需阻塞在单个IO操作上，兼顾高性能与简洁性。

- 考点2：Redis字典（Hash表）的扩容机制是什么？
答：采用渐进式重哈希，当Hash表的负载因子（used/size）超过阈值（默认1）时，创建新的Hash表（ht[1]），每次事件循环迁移少量节点（从ht[0]到ht[1]），迁移完成后替换ht[0]，避免一次性重哈希导致的服务阻塞。

- 考点3：Redis List的底层实现是什么？核心设计思路是什么？
答：Redis 3.2+后是快速列表（Quicklist），核心设计是“双向链表+压缩列表”，每个链表节点内部存储一个压缩列表，既减少链表节点的内存开销，又通过压缩列表提升小数据的存储效率，兼顾内存与操作效率。

- 考点4：Redis AOF重写的核心逻辑是什么？为什么要重写？
答：核心逻辑是子进程遍历数据库，生成最简命令集（如多次SET同一key只保留最后一次），替换旧的AOF文件；重写的目的是减少AOF文件体积，避免日志膨胀，提升AOF加载速度。

- 考点5：Redis内存淘汰策略的实现逻辑是什么？
答：当内存使用量超过maxmemory配置时，触发freeMemoryIfNeeded函数，根据配置的淘汰策略（LRU/LFU/TTL等），遍历所有数据库，筛选待淘汰的键，淘汰后释放内存，直到内存使用量低于maxmemory。

- 考点6：Redis集群的槽位分配机制是什么？
答：Redis集群共有16384个槽位，每个节点负责一部分槽位，通过clusterNode结构体的slots位图管理槽位，槽位分配后会广播给所有节点，保证集群节点间的槽位信息一致；客户端根据键的Hash值计算槽位，直接与负责该槽位的节点通信。

# 四、源码学习建议（落地指南）

结合前十一章的内容，给开发者提供Redis源码学习的落地建议，避免盲目学习，高效掌握核心源码逻辑：

- 循序渐进，先易后难：优先学习事件驱动模型、字典、SDS等核心模块，再学习持久化、集群等复杂模块，避免一开始陷入底层编译、复杂算法的细节。

- 关联功能，融会贯通：学习源码时，结合前十章讲解的Redis功能（如持久化、内存管理、集群），理解“功能如何通过源码实现”，建立“功能-源码”的关联，加深记忆。

- 聚焦核心，忽略细节：无需掌握所有源码（如跨平台适配、错误处理的边角逻辑），重点关注核心流程、核心结构体与设计思想，贴合面试考点与生产实践。

- 动手调试，加深理解：下载源码，编译后通过gdb调试（如调试事件循环、RDB生成流程），观察源码的执行过程，比单纯阅读源码更高效。

# 五、总结

1. Redis源码核心模块：事件驱动模型（单线程+IO多路复用）是高性能核心，字典、快速列表等数据结构是功能基础，持久化、内存管理、集群是生产环境必备模块，各模块相互配合，构成Redis的完整功能。

2. 核心设计思想：单线程、模块化、惰性操作、底层优化，贯穿所有源码模块，是Redis高性能、高可用、高易用性的关键。

3. 面试高频重点：事件驱动模型的实现、字典的渐进式重哈希、快速列表的设计、AOF重写逻辑、内存淘汰策略、集群槽位分配，需熟练掌握核心流程与源码片段。

4. 学习目标：源码学习的核心是“理解设计思想”，而非“背诵源码”，结合前十一章的内容，实现从“会用Redis”到“理解Redis”的进阶，能够应对中高级面试，同时规避生产环境中的底层风险。