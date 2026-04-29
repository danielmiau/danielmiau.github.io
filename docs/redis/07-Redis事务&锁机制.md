# 07-Redis事务&锁机制

前言：本文承接第六章缓存核心问题与解决方案，聚焦Redis的事务机制与锁机制两大核心特性。本章延续前六章的深度与排版规范，从「概念定义、核心原理、实操命令、生产场景应用、常见问题与解决方案」展开，兼顾中高级知识与生产落地实操，重点拆解Redis事务的特殊性、分布式锁的实现与优化，以及生产中避坑要点。

# 一、Redis事务核心认知

## 1.1 Redis事务的定义与核心特性

### 1.1.1 定义

**Redis事务**：是一组命令的集合，Redis会将这组命令一次性、顺序性地执行，在执行过程中，不会被其他客户端发送的命令打断，保证命令执行的原子性（注意：Redis事务的原子性与传统数据库事务不同，需重点区分）。

### 1.1.2 核心特性（与传统数据库事务对比）

Redis事务遵循「ACID」中的部分特性，核心差异在于原子性的实现，具体如下：

- 原子性（Atomicity）：Redis事务的原子性是「部分原子性」—— 事务中的所有命令要么全部执行（无异常），要么全部不执行（执行前发生错误）；但如果执行过程中某条命令报错，后续命令仍会继续执行，报错命令不会回滚（与MySQL事务的原子性不同）。

- 一致性（Consistency）：事务执行前后，Redis中的数据从一个合法状态转换到另一个合法状态，不会出现数据混乱（如执行过程中Redis宕机，未执行完的事务会被放弃，数据恢复到事务执行前的状态）。

- 隔离性（Isolation）：Redis是单线程执行命令，事务执行期间，其他客户端的命令会被阻塞，直到事务执行完成，因此Redis事务的隔离级别是「串行化」（最高隔离级别）。

- 持久性（Durability）：取决于Redis的持久化配置（RDB、AOF），若未开启持久化，事务执行完成后Redis宕机，数据会丢失；若开启AOF持久化且配置为fsync always，可保证事务的持久性。

关键提醒：Redis事务不支持回滚（rollback），这是与传统数据库事务的核心区别，需重点记忆（面试常考）。

## 1.2 Redis事务的执行流程（实操核心）

Redis事务通过4个核心命令实现，执行流程分为「开启事务→入队命令→执行事务/放弃事务」三步，具体如下：

1. 开启事务（MULTI）：执行MULTI命令后，Redis进入事务状态，后续输入的所有命令不会立即执行，而是被加入到事务队列中。

2. 入队命令（如SET、GET、INCR等）：所有命令会被依次加入事务队列，Redis会返回“QUEUED”表示命令入队成功。

3. 执行事务（EXEC）/放弃事务（DISCARD）：
        

    - EXEC：执行事务队列中的所有命令，返回所有命令的执行结果（按入队顺序），事务结束。

    - DISCARD：放弃事务，清空事务队列，事务结束，所有入队命令不会执行。

### 1.2.1 实操示例（Redis命令行）

```redis
# 1. 开启事务
127.0.0.1:6379> MULTI
OK

# 2. 入队命令（依次添加3条命令）
127.0.0.1:6379> SET user:100 name "zhangsan"
QUEUED
127.0.0.1:6379> INCR user:100:age
QUEUED
127.0.0.1:6379> GET user:100
QUEUED

# 3. 执行事务（返回3条命令的执行结果）
127.0.0.1:6379> EXEC
1) OK
2) (integer) 1
3) "zhangsan"

# 放弃事务示例（入队后放弃）
127.0.0.1:6379> MULTI
OK
127.0.0.1:6379> SET user:101 name "lisi"
QUEUED
127.0.0.1:6379> DISCARD
OK
127.0.0.1:6379> GET user:101 # 命令未执行，返回nil
(nil)
```

### 1.2.2 事务执行失败的两种情况（重点区分）

Redis事务执行失败分为「入队失败」和「执行失败」，两种情况的处理逻辑不同，面试常考：

1. 入队失败（语法错误）：
        `127.0.0.1:6379> MULTI
    OK
    127.0.0.1:6379> SET user:100 name "zhangsan" # 语法正确，入队成功
    QUEUED
    127.0.0.1:6379> SETEX user:100  # 语法错误（缺少参数），入队失败
    (error) ERR wrong number of arguments for 'setex' command
    127.0.0.1:6379> EXEC # 执行事务，所有命令均不执行
    (error) EXECABORT Transaction discarded because of previous errors.`

    - 原因：命令语法错误（如命令拼写错误、参数个数错误）。
    - 处理：Redis会立即返回错误提示，该命令入队失败；但事务仍可继续入队其他命令，执行EXEC时，所有命令（包括入队成功的）都会被放弃，事务整体不执行。
2. 执行失败（逻辑错误）：
       `127.0.0.1:6379> MULTI
   OK
   127.0.0.1:6379> SET user:100 age "abc" # 语法正确，入队成功
   QUEUED
   127.0.0.1:6379> INCR user:100 age # 语法正确，执行时逻辑错误（字符串无法自增）
   QUEUED
   127.0.0.1:6379> GET user:100 age # 语法正确，入队成功
   QUEUED
   127.0.0.1:6379> EXEC # 执行事务，错误命令失败，其他命令正常执行
1) OK
2) (error) ERR value is not an integer or out of range
3) "abc"`

    - 原因：命令语法正确，但执行时出现逻辑错误（如对非数字值执行INCR操作）。
- 处理：该命令执行失败，返回错误信息，但其他入队成功的命令会继续执行，不会回滚（Redis不支持回滚）。

## 1.3 Redis事务的局限性（生产避坑）

- 不支持回滚：执行过程中出现逻辑错误，错误命令不会回滚，后续命令继续执行，可能导致数据不一致。

- 无法中断事务：事务一旦开启（MULTI），只能通过EXEC执行或DISCARD放弃，无法中途中断。

- 不支持复杂事务操作：Redis事务仅支持简单的命令集合，不支持条件判断（如IF-ELSE）、循环等复杂逻辑。

- 持久化影响事务持久性：若未开启持久化，事务执行完成后Redis宕机，数据会丢失；若开启AOF，需配置合适的fsync策略（如fsync everysec），平衡性能与持久性。

## 1.4 Redis事务的生产应用场景

Redis事务适合「简单的原子性操作场景」，不适合复杂的事务逻辑，常见应用场景：

- 批量操作：一次性执行多个命令，确保命令顺序执行，不被其他命令打断（如批量设置多个key-value）。

- 简单的数据一致性场景：如用户积分扣除与订单状态更新，确保两个操作要么都执行，要么都不执行（需规避执行失败的情况）。

- 计数器批量更新：如批量更新多个商品的库存计数器，确保更新操作的顺序性和原子性。

注意：复杂的事务场景（如分布式事务、多表关联操作），不建议使用Redis事务，应使用分布式事务框架（如Seata）或数据库事务。

# 二、Redis锁机制（生产核心，分布式锁首选）

## 2.1 锁的核心价值与Redis锁的优势

### 2.1.1 锁的核心价值

在分布式系统中，锁的核心作用是「解决并发冲突」，确保多个客户端（或服务节点）对共享资源的操作是互斥的，避免出现数据不一致（如超卖、库存错乱、并发更新冲突）。

### 2.1.2 Redis锁的优势（对比其他锁机制）

- 高性能：Redis是内存数据库，锁的获取和释放操作都是内存级操作，响应速度快（毫秒级）。

- 分布式支持：Redis支持集群部署，可实现分布式锁，适配分布式系统场景（如微服务架构）。

- 易用性：通过Redis命令（如SETNX、EXPIRE）即可快速实现锁机制，无需复杂的开发。

- 灵活性：可自定义锁的过期时间、重试机制，适配不同的业务场景。

常见对比：Redis锁 vs 数据库锁（如MySQL行锁）—— 数据库锁性能低（磁盘IO），不适合高并发场景；Redis锁性能高，适合高并发分布式场景。

## 2.2 Redis锁的核心实现方式（从简单到生产级）

### 2.2.1 方案1：SETNX + EXPIRE（基础版，有缺陷）

核心逻辑：使用SETNX（SET if Not Exists）命令实现锁的获取，使用EXPIRE命令设置锁的过期时间，避免死锁。

- SETNX key value：若key不存在，设置key的值为value，返回1（获取锁成功）；若key已存在，返回0（获取锁失败）。

- EXPIRE key seconds：设置key的过期时间，避免获取锁后服务宕机，导致锁无法释放（死锁）。

```redis
# 1. 获取锁（key为锁标识，value可设为随机字符串，用于后续释放锁校验）
127.0.0.1:6379> SETNX lock:user:100 "random_str"
(integer) 1 # 获取锁成功

# 2. 设置锁的过期时间（3秒），避免死锁
127.0.0.1:6379> EXPIRE lock:user:100 3
(integer) 1

# 3. 执行业务逻辑（如更新用户信息）
...

# 4. 释放锁（删除key）
127.0.0.1:6379> DEL lock:user:100
(integer) 1
```

缺陷：SETNX和EXPIRE是两个独立命令，存在「原子性问题」—— 若获取锁（SETNX成功）后，服务宕机，未执行EXPIRE命令，会导致锁永久存在，引发死锁。

### 2.2.2 方案2：SET命令（原子操作，推荐基础版）

核心逻辑：Redis 2.6.12+ 版本支持SET命令的扩展参数，可将SETNX和EXPIRE合并为一个原子操作，解决方案1的死锁问题。

SET命令格式：SET key value NX EX seconds（NX=SETNX，EX=设置过期时间）

```redis
# 原子性获取锁并设置过期时间（3秒）
127.0.0.1:6379> SET lock:user:100 "random_str" NX EX 3
OK # 获取锁成功
# 若锁已存在，返回nil（获取锁失败）
127.0.0.1:6379> SET lock:user:100 "random_str" NX EX 3
(nil)

# 执行业务逻辑后，释放锁（删除key）
127.0.0.1:6379> DEL lock:user:100
(integer) 1
```

优化点：将获取锁和设置过期时间合并为一个原子操作，避免死锁；value设置为随机字符串（如UUID），用于后续释放锁时校验，避免误释放其他客户端的锁。

缺陷：若业务逻辑执行时间超过锁的过期时间，锁会自动释放，其他客户端会获取到锁，可能导致并发冲突；同时，释放锁时（DEL命令），无法确认当前锁是否是自己获取的，可能误释放他人的锁。

### 2.2.3 方案3：SET +  Lua脚本（生产级，解决误释放问题）

核心逻辑：使用SET命令原子性获取锁并设置过期时间，释放锁时通过Lua脚本校验锁的value（随机字符串），确保只有获取锁的客户端才能释放锁，解决误释放问题。

核心原理：Lua脚本在Redis中是原子执行的，可避免释放锁时的并发校验问题。

```redis
# 1. 原子性获取锁（value为UUID，过期时间3秒）
127.0.0.1:6379> SET lock:user:100 "uuid_123" NX EX 3
OK

# 2. 释放锁（Lua脚本，校验value是否一致，一致则删除锁）
# 脚本逻辑：若key存在且value等于传入的uuid，删除key（释放锁），返回1；否则返回0
127.0.0.1:6379> EVAL "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end" 1 lock:user:100 "uuid_123"
(integer) 1 # 释放锁成功

# 若value不一致（如其他客户端获取的锁），释放失败
127.0.0.1:6379> EVAL "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end" 1 lock:user:100 "uuid_456"
(integer) 0
```

### 2.2.4 方案4：Redisson分布式锁（企业级首选，解决所有缺陷）

核心逻辑：Redisson是Redis的Java客户端，内置了分布式锁的实现，自动解决「死锁、误释放、锁过期、重入锁」等问题，无需手动编写Lua脚本，生产环境中优先使用。

核心特性：

- 自动续期：业务逻辑执行时间超过锁的过期时间时，Redisson会自动为锁续期（默认每30秒续期一次），避免锁提前释放。

- 重入锁支持：同一客户端可多次获取同一把锁（重入），避免死锁。

- 原子性操作：底层使用Lua脚本实现锁的获取、释放、续期，确保原子性。

- 高可用：支持Redis Cluster、主从+哨兵架构，确保锁服务的高可用。

```java
# Java + Redisson 分布式锁实操示例
// 1. 初始化Redisson客户端
Config config = new Config();
config.useClusterServers()
      .addNodeAddress("redis://127.0.0.1:6379", "redis://127.0.0.1:6380");
RedissonClient redissonClient = Redisson.create(config);

// 2. 获取分布式锁（锁key为lock:user:100）
RLock lock = redissonClient.getLock("lock:user:100");

try {
    // 3. 获取锁（等待时间10秒，锁过期时间30秒，自动续期）
    boolean isLock = lock.tryLock(10, 30, TimeUnit.SECONDS);
    if (isLock) {
        // 4. 执行业务逻辑（如更新用户信息、扣减库存）
        System.out.println("获取锁成功，执行业务逻辑");
    }
} catch (InterruptedException e) {
    e.printStackTrace();
} finally {
    // 5. 释放锁（只有获取锁的客户端才能释放）
    if (lock.isHeldByCurrentThread()) {
        lock.unlock();
    }
}
```

生产建议：中小规模业务可使用「SET + Lua脚本」实现，大规模业务、高并发场景优先使用Redisson分布式锁，降低开发成本和踩坑风险。

## 2.3 Redis锁的常见问题与解决方案（生产避坑重点）

### 2.3.1 问题1：死锁

- 产生原因：获取锁后，服务宕机、网络中断，导致锁无法释放；或锁未设置过期时间，永久存在。

- 解决方案：
        

    - 必须为锁设置过期时间（通过SET命令的EX参数），避免锁永久存在。

    - 使用Redisson分布式锁，自动续期，避免业务执行时间过长导致锁提前释放。

    - 定期清理过期锁（通过Redis的过期键淘汰机制），兜底避免死锁。

### 2.3.2 问题2：误释放锁

- 产生原因：释放锁时未校验锁的归属（value），导致误释放其他客户端获取的锁。

- 解决方案：
        

    - 获取锁时，设置value为随机字符串（如UUID），释放锁时通过Lua脚本校验value，确保只有获取锁的客户端才能释放。

    - 使用Redisson分布式锁，底层自动实现锁的归属校验，无需手动处理。

### 2.3.3 问题3：锁过期导致并发冲突

- 产生原因：业务逻辑执行时间超过锁的过期时间，锁自动释放，其他客户端获取锁，导致并发操作同一资源。

- 解决方案：
       

    - 合理设置锁的过期时间（根据业务逻辑执行时间，预留一定冗余，如业务执行需5秒，设置过期时间10秒）。

    - 使用Redisson分布式锁，开启自动续期功能（默认开启），业务执行期间自动为锁续期。

    - 拆分长耗时业务：将长耗时业务拆分为多个短耗时操作，减少锁的持有时间。

### 2.3.4 问题4：Redis集群环境下的锁失效

- 产生原因：Redis Cluster集群中，主节点宕机，从节点未及时同步锁数据，导致锁丢失；或主从切换期间，锁数据未同步，出现多个客户端同时获取锁。

- 解决方案：
        

    - 使用Redisson分布式锁，支持Redis Cluster集群，底层通过「红锁（RedLock）」机制解决主从切换导致的锁失效问题。

    - 避免使用单节点Redis部署锁服务，必须部署主从+哨兵或Redis Cluster集群，确保高可用。

### 2.3.5 问题5：重入锁问题

- 产生原因：同一客户端多次获取同一把锁（如递归调用、多方法调用），若锁不支持重入，会导致死锁。

- 解决方案：
        

    - 使用Redisson分布式锁，默认支持重入锁（RLock接口），同一客户端可多次获取锁，释放时需对应次数的释放。

    - 手动实现重入锁：通过Redis的Hash结构存储锁的持有者和重入次数，获取锁时校验持有者，更新重入次数；释放锁时减少重入次数，次数为0时删除锁。

## 2.4 Redis锁的生产选型建议

- 中小规模业务、低并发场景：使用「SET + Lua脚本」实现，开发成本低，满足基本需求。

- 大规模业务、高并发、分布式场景：优先使用「Redisson分布式锁」，自动解决死锁、误释放、锁过期等问题，提升开发效率和系统稳定性。

- 锁的粒度：尽量缩小锁的粒度（如锁key为“lock:product:100”，而非“lock:product”），减少锁竞争，提升并发能力。

- 过期时间设置：根据业务逻辑执行时间，预留2~3倍的冗余时间，避免锁提前释放；同时开启自动续期（Redisson），应对长耗时业务。

- 高可用保障：锁服务必须部署Redis Cluster或主从+哨兵架构，避免Redis单点故障导致锁服务不可用。

# 三、Redis事务与锁机制的关联与区别

## 3.1 核心关联

- 两者都用于保证数据一致性：事务确保一组命令的顺序执行，锁确保并发操作的互斥性，都是分布式系统中保证数据一致性的核心手段。

- 锁机制可结合事务使用：在事务执行前获取锁，事务执行完成后释放锁，确保事务执行期间，其他客户端无法操作相关资源，避免并发冲突。

- 底层都依赖Redis的原子性操作：事务的原子性依赖Redis的单线程执行，锁的原子性依赖SET命令和Lua脚本。

## 3.2 核心区别

|对比维度|Redis事务|Redis锁机制|
|---|---|---|
|核心作用|保证一组命令的顺序执行，避免执行过程中被打断|保证并发操作的互斥性，避免多个客户端同时操作共享资源|
|原子性|部分原子性，执行中报错不回滚，后续命令继续执行|完全原子性，获取/释放锁的操作是原子的，不会出现中间状态|
|使用场景|批量命令执行、简单的原子性操作|分布式并发控制、共享资源操作（如库存扣减、订单创建）|
|局限性|不支持回滚、无法中断、不支持复杂逻辑|需解决死锁、误释放、锁过期等问题，依赖高可用部署|
# 四、生产综合实践（落地指南）

## 4.1 事务与锁的结合使用示例（Java+Redis）

场景：用户积分扣除（扣减积分+记录积分变动），需保证两个操作的原子性，同时避免并发扣减冲突。

```java
// 1. 初始化RedisTemplate
@Autowired
private StringRedisTemplate redisTemplate;

// 2. 业务逻辑：扣减用户积分（结合事务与锁）
public boolean deductPoints(Long userId, Integer points) {
    // 锁key（粒度：用户级别）
    String lockKey = "lock:user:points:" + userId;
    // 随机字符串（用于释放锁校验）
    String uuid = UUID.randomUUID().toString();
    
    try {
        // 3. 获取锁（原子操作，过期时间5秒）
        Boolean isLock = redisTemplate.opsForValue().setIfAbsent(lockKey, uuid, 5, TimeUnit.SECONDS);
        if (Boolean.FALSE.equals(isLock)) {
            // 未获取到锁，返回失败（可添加重试机制）
            return false;
        }
        
        // 4. 开启Redis事务
        redisTemplate.multi();
        
        // 5. 入队命令（扣减积分+记录变动）
        // 扣减积分（假设用户积分key为user:points:userId）
        redisTemplate.opsForValue().decrement("user:points:" + userId, points);
        // 记录积分变动（hash结构，key为user:points:log:userId）
        redisTemplate.opsForHash().put("user:points:log:" + userId, System.currentTimeMillis() + "", "扣减" + points + "积分");
        
        // 6. 执行事务
        List<Object> result = redisTemplate.exec();
        if (result == null || result.size() != 2) {
            // 事务执行失败（如入队错误），返回失败
            return false;
        }
        
        // 7. 事务执行成功，返回true
        return true;
    } catch (Exception e) {
        // 异常处理，放弃事务
        redisTemplate.discard();
        e.printStackTrace();
        return false;
    } finally {
        // 8. 释放锁（Lua脚本校验，避免误释放）
        String script = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end";
        redisTemplate.execute(new DefaultRedisScript<Integer>(script, Integer.class), Collections.singletonList(lockKey), uuid);
    }
}
```

## 4.2 生产避坑总结

- Redis事务：不依赖事务回滚，需提前校验命令语法，避免执行过程中出现逻辑错误；复杂事务场景优先使用数据库事务或分布式事务框架。

- Redis锁：优先使用Redisson，避免手动编写脚本踩坑；必须设置锁的过期时间，开启自动续期；锁的粒度要细，避免锁竞争影响并发性能。

- 高可用：Redis服务（事务和锁）必须部署集群（Cluster或主从+哨兵），避免单点故障导致服务不可用。

- 性能优化：减少锁的持有时间，拆分长耗时业务；避免大量并发请求同时竞争同一把锁，可通过分片、分段等方式分散锁竞争。

# 五、总结

1. Redis事务是一组命令的集合，具有「部分原子性、一致性、串行化隔离性、持久性（依赖持久化配置）」，不支持回滚，适合简单的批量原子操作。

2. Redis事务的核心命令：MULTI（开启事务）、EXEC（执行事务）、DISCARD（放弃事务），执行失败分为入队失败（整体不执行）和执行失败（仅错误命令失败，后续继续执行）。

3. Redis锁的核心作用是解决分布式并发冲突，常用实现方式：SET命令（原子操作）、SET+Lua脚本（解决误释放）、Redisson（企业级首选）。

4. Redis锁的常见问题：死锁（设置过期时间）、误释放（Lua脚本校验）、锁过期（自动续期）、集群锁失效（Redisson红锁）、重入锁（Redisson支持）。

5. 事务与锁的关联：锁保证事务执行期间的互斥性，事务保证一组命令的顺序执行，两者结合可更好地保证分布式系统的数据一致性。

6. 生产选型：简单场景用SET+Lua脚本，高并发分布式场景用Redisson；事务适合批量操作，锁适合并发控制，根据业务场景合理搭配使用。