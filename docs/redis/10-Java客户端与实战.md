# 10-Java客户端与实战

前言：本文承接第九章Redis运维监控&生产最佳实践，聚焦Java客户端与实战落地两大核心模块。从「Java客户端选型、核心客户端（Jedis、Lettuce）使用、Spring整合Redis、生产实战场景、性能优化、常见问题避坑」展开，全程保持与前九章一致的代码风格、内容边界与排版逻辑，重点拆解Java项目中Redis客户端的选型技巧、核心API用法、实战场景落地及性能优化方案，助力开发者快速掌握Java操作Redis的核心能力，规避生产环境中的客户端使用风险。

# 一、Java客户端核心认知与选型

## 1.1 核心认知

Redis的Java客户端是Java项目与Redis服务交互的桥梁，核心作用是「封装Redis命令、管理连接、处理异常、提升交互效率」。Java客户端需具备高可用、高性能、易用性、兼容性四大特点，适配Redis单节点、主从、哨兵、集群等多种架构，满足不同业务场景的需求。

补充：Java客户端的选型直接影响项目与Redis的交互性能，需结合项目并发量、架构模式、运维成本综合选择，避免盲目选型导致的性能瓶颈或运维复杂问题。

## 1.2 主流Java客户端对比（生产选型必看）

|客户端|核心特点|优势|劣势|适用场景|
|---|---|---|---|---|
|Jedis|基于BIO模型，API简洁，贴近Redis原生命令，轻量级|易用性高、学习成本低、社区成熟、文档丰富|BIO模型并发性能弱，需手动管理连接池，不支持异步|小型项目、低并发场景、快速开发|
|Lettuce|基于Netty（NIO模型），支持异步、响应式，线程安全|高并发性能强、支持集群、自动管理连接、支持异步操作|API相对复杂、学习成本稍高，依赖Netty|中大型项目、高并发场景、集群架构|
|Redisson|基于Lettuce封装，提供分布式锁、集合等高级功能|高级功能丰富、开箱即用、支持集群，简化分布式开发|封装较深，灵活性稍差，体积较大|分布式项目、需要高级功能（分布式锁等）|
## 1.3 生产选型建议

- 优先选型：中大型项目、高并发场景、Redis集群架构，优先选择「Lettuce」，兼顾性能与高可用，且Spring Boot 2.x及以上默认集成Lettuce，运维成本低。

- 简化开发：若项目需要分布式锁、分布式集合等高级功能，直接选择「Redisson」，无需重复封装，提升开发效率。

- 小型项目：小型项目、低并发、快速验证需求，选择「Jedis」，学习成本低、开发速度快，无需复杂配置。

- 注意：避免混合使用多种客户端，否则会增加连接管理复杂度，导致连接泄露、性能异常等问题。

# 二、核心Java客户端实战（Jedis+Lettuce，生产必掌握）

## 2.1 环境准备（Maven依赖）

以下依赖适配Java 8+、Redis 6.x+，结合Spring Boot 2.x+环境，统一版本，避免依赖冲突，可直接复制到pom.xml使用。

```xml
<!-- 1. Jedis依赖（单独使用Jedis） -->
<dependency>
    <groupId>redis.clients</groupId>
    <artifactId>jedis</artifactId>
    <version>4.4.6</version>
</dependency>

<!-- 2. Lettuce依赖（单独使用Lettuce） -->
<dependency>
    <groupId>io.lettuce</groupId>
    <artifactId>lettuce-core</artifactId>
    <version>6.3.0.RELEASE</version>
</dependency>

<!-- 3. Spring Boot整合Redis（默认集成Lettuce） -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
    <version>2.7.10</version>
    <!-- 排除默认Lettuce，替换为Jedis（可选） -->
    <exclusions>
        <exclusion>
            <groupId>io.lettuce</groupId>
            <artifactId>lettuce-core</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<!-- 4. Redisson依赖（需要高级功能时添加） -->
<dependency>
    <groupId>org.redisson</groupId>
    <artifactId>redisson-spring-boot-starter</artifactId>
    <version>3.23.3</version>
</dependency>
```

## 2.2 Jedis实战（基础用法）

Jedis核心是「手动管理连接池」，需配置连接池参数，避免频繁创建/销毁连接，提升性能，核心用法分为「单节点」和「集群」两种场景。

### 2.2.1 Jedis单节点用法（基础）

```java
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

public class JedisSingleDemo {
    // 1. 配置Jedis连接池（核心，生产必配）
    private static final JedisPool jedisPool;

    static {
        // 连接池配置
        JedisPoolConfig poolConfig = new JedisPoolConfig();
        poolConfig.setMaxTotal(50); // 最大连接数
        poolConfig.setMaxIdle(20); // 最大空闲连接
        poolConfig.setMinIdle(5); // 最小空闲连接
        poolConfig.setMaxWaitMillis(3000); // 最大等待时间（毫秒）
        poolConfig.setTestOnBorrow(true); // 借连接时校验，避免无效连接

        // 初始化连接池（Redis单节点地址、端口、密码）
        jedisPool = new JedisPool(poolConfig, "127.0.0.1", 6379, 3000, "123456");
    }

    // 2. 获取Jedis连接（try-with-resources自动关闭连接）
    public static Jedis getJedis() {
        return jedisPool.getResource();
    }

    // 3. 核心API实战（覆盖String、Hash、List、Set、ZSet常用命令）
    public static void main(String[] args) {
        // 自动关闭连接
        try (Jedis jedis = getJedis()) {
            // 1. String类型
            jedis.set("jedis:name", "Redis"); // 设置值
            String name = jedis.get("jedis:name"); // 获取值
            jedis.expire("jedis:name", 60); // 设置过期时间（60秒）
            System.out.println("String类型：" + name);

            // 2. Hash类型
            jedis.hset("jedis:user:1001", "name", "张三");
            jedis.hset("jedis:user:1001", "age", "25");
            String userName = jedis.hget("jedis:user:1001", "name");
            System.out.println("Hash类型：" + userName);

            // 3. List类型
            jedis.lpush("jedis:list", "A", "B", "C"); // 左推
            String listVal = jedis.lpop("jedis:list"); // 左弹
            System.out.println("List类型：" + listVal);

            // 4. Set类型
            jedis.sadd("jedis:set", "Java", "Redis", "MySQL");
            boolean isMember = jedis.sismember("jedis:set", "Java");
            System.out.println("Set类型：" + isMember);

            // 5. ZSet类型
            jedis.zadd("jedis:zset", 90, "Java");
            jedis.zadd("jedis:zset", 80, "Redis");
            Double score = jedis.zscore("jedis:zset", "Java");
            System.out.println("ZSet类型：" + score);
        } catch (Exception e) {
            // 异常处理（生产需记录日志，避免直接抛出）
            e.printStackTrace();
        }
    }
}

```

### 2.2.2 Jedis集群用法（生产重点）

Redis Cluster场景下，Jedis通过JedisCluster管理集群连接，自动分片，无需手动处理槽位分配，核心配置如下：

```java
import redis.clients.jedis.JedisCluster;
import redis.clients.jedis.JedisPoolConfig;

import java.util.HashSet;
import java.util.Set;

public class JedisClusterDemo {
    // 1. 配置JedisCluster（集群节点地址）
    private static final JedisCluster jedisCluster;

    static {
        // 连接池配置（与单节点一致）
        JedisPoolConfig poolConfig = new JedisPoolConfig();
        poolConfig.setMaxTotal(50);
        poolConfig.setMaxIdle(20);
        poolConfig.setMinIdle(5);
        poolConfig.setMaxWaitMillis(3000);

        // 集群节点集合（至少配置一个节点，Jedis会自动发现其他节点）
        Set<String> clusterNodes = new HashSet<>();
        clusterNodes.add("127.0.0.1:6379");
        clusterNodes.add("127.0.0.1:6380");
        clusterNodes.add("127.0.0.1:6381");

        // 初始化JedisCluster（密码、超时时间、连接池配置）
        jedisCluster = new JedisCluster(clusterNodes, 3000, 3000, 3, "123456", poolConfig);
    }

    // 2. 核心API实战（与单节点用法一致，自动分片）
    public static void main(String[] args) {
        try {
            // 所有命令与单节点Jedis一致，无需关心分片逻辑
            jedisCluster.set("cluster:name", "JedisCluster");
            String name = jedisCluster.get("cluster:name");
            System.out.println("集群String类型：" + name);

            jedisCluster.hset("cluster:user:1002", "name", "李四");
            String userName = jedisCluster.hget("cluster:user:1002", "name");
            System.out.println("集群Hash类型：" + userName);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // 关闭集群连接（生产环境可在项目关闭时调用）
            if (jedisCluster != null) {
                jedisCluster.close();
            }
        }
    }
}

```

### 2.2.3 Jedis注意事项（生产避坑）

- 必须使用连接池：禁止每次操作都创建新的Jedis实例（频繁创建/销毁连接会严重影响性能），连接池参数需根据并发量调整。

- 连接自动关闭：使用try-with-resources语法，确保连接用完自动关闭，避免连接泄露。

- 异常处理：所有Redis操作需捕获异常，记录日志，避免因Redis服务异常导致项目崩溃。

- 密码与权限：若Redis设置了密码，必须在初始化连接时传入，否则会报未授权访问错误。

## 2.3 Lettuce实战（高并发首选）

Lettuce基于Netty（NIO模型），支持异步、响应式操作，自动管理连接，无需手动配置连接池（内置连接池），适配高并发场景，核心用法分为「单节点」「集群」「异步操作」三种场景。

### 2.3.1 Lettuce单节点用法（同步）

```java
import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.api.StatefulRedisConnection;
import io.lettuce.core.api.sync.RedisCommands;

public class LettuceSingleSyncDemo {
    public static void main(String[] args) {
        // 1. 配置RedisURI（地址、端口、密码、超时时间）
        RedisURI redisURI = RedisURI.builder()
                .withHost("127.0.0.1")
                .withPort(6379)
                .withPassword("123456")
                .withTimeout(java.time.Duration.ofMillis(3000))
                .build();

        // 2. 初始化RedisClient
        RedisClient redisClient = RedisClient.create(redisURI);

        // 3. 获取状态ful连接（自动管理连接，线程安全）
        try (StatefulRedisConnection<String, String> connection = redisClient.connect()) {
            // 4. 获取同步命令对象
            RedisCommands<String, String> commands = connection.sync();

            // 核心API（与Jedis类似，语法略有差异）
            commands.set("lettuce:name", "RedisLettuce");
            String name = commands.get("lettuce:name");
            commands.expire("lettuce:name", 60);
            System.out.println("Lettuce同步String：" + name);

            commands.hset("lettuce:user:1003", "name", "王五");
            String userName = commands.hget("lettuce:user:1003", "name");
            System.out.println("Lettuce同步Hash：" + userName);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // 关闭RedisClient（项目关闭时调用）
            redisClient.shutdown();
        }
    }
}

```

### 2.3.2 Lettuce异步操作（高并发核心）

Lettuce的异步操作通过AsyncRedisCommands实现，非阻塞，适合高并发场景，避免阻塞主线程，核心用法如下：

```java
import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.api.StatefulRedisConnection;
import io.lettuce.core.api.async.RedisAsyncCommands;

import java.util.concurrent.ExecutionException;

public class LettuceAsyncDemo {
    public static void main(String[] args) throws ExecutionException, InterruptedException {
        // 1. 配置RedisURI（与同步用法一致）
        RedisURI redisURI = RedisURI.builder()
                .withHost("127.0.0.1")
                .withPort(6379)
                .withPassword("123456")
                .withTimeout(java.time.Duration.ofMillis(3000))
                .build();

        // 2. 初始化RedisClient
        RedisClient redisClient = RedisClient.create(redisURI);

        // 3. 获取连接
        try (StatefulRedisConnection<String, String> connection = redisClient.connect()) {
            // 4. 获取异步命令对象
            RedisAsyncCommands<String, String> asyncCommands = connection.async();

            // 5. 异步执行命令（非阻塞，返回Future对象）
            asyncCommands.set("lettuce:async:name", "AsyncLettuce");
            // 阻塞获取结果（生产可结合CompletableFuture异步处理）
            String name = asyncCommands.get("lettuce:async:name").get();
            System.out.println("Lettuce异步String：" + name);

            // 异步执行Hash命令
            asyncCommands.hset("lettuce:async:user:1004", "name", "赵六");
            String userName = asyncCommands.hget("lettuce:async:user:1004", "name").get();
            System.out.println("Lettuce异步Hash：" + userName);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            redisClient.shutdown();
        }
    }
}

```

### 2.3.3 Lettuce集群用法（生产重点）

Lettuce集群用法与单节点类似，通过RedisClusterClient初始化，自动适配集群分片、主从切换，核心用法如下：

```java
import io.lettuce.core.RedisURI;
import io.lettuce.core.cluster.RedisClusterClient;
import io.lettuce.core.cluster.api.StatefulRedisClusterConnection;
import io.lettuce.core.cluster.api.sync.RedisClusterCommands;

import java.util.Arrays;
import java.util.List;

public class LettuceClusterDemo {
    public static void main(String[] args) {
        // 1. 配置集群节点URI（多个节点）
        List<RedisURI> clusterURIs = Arrays.asList(
                RedisURI.builder().withHost("127.0.0.1").withPort(6379).withPassword("123456").build(),
                RedisURI.builder().withHost("127.0.0.1").withPort(6380).withPassword("123456").build(),
                RedisURI.builder().withHost("127.0.0.1").withPort(6381).withPassword("123456").build()
        );

        // 2. 初始化RedisClusterClient
        RedisClusterClient clusterClient = RedisClusterClient.create(clusterURIs);

        // 3. 获取集群连接
        try (StatefulRedisClusterConnection<String, String> connection = clusterClient.connect()) {
            // 4. 获取集群同步命令对象
            RedisClusterCommands<String, String> clusterCommands = connection.sync();

            // 核心API（与单节点一致，自动分片）
            clusterCommands.set("lettuce:cluster:name", "LettuceCluster");
            String name = clusterCommands.get("lettuce:cluster:name");
            System.out.println("Lettuce集群String：" + name);

            clusterCommands.hset("lettuce:cluster:user:1005", "name", "孙七");
            String userName = clusterCommands.hget("lettuce:cluster:user:1005", "name");
            System.out.println("Lettuce集群Hash：" + userName);
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            // 关闭集群客户端
            clusterClient.shutdown();
        }
    }
}

```

### 2.3.4 Lettuce注意事项（生产避坑）

- 无需手动配置连接池：Lettuce内置连接池（默认使用GenericObjectPool），可通过配置调整连接池参数，无需手动管理。

- 线程安全：StatefulRedisConnection是线程安全的，可共享使用，无需为每个线程创建新连接。

- 异步操作：高并发场景优先使用异步操作，避免阻塞主线程，提升系统吞吐量。

- 集群适配：Lettuce自动适配Redis集群的主从切换、槽位迁移，无需手动处理，运维成本低。

# 三、Spring Boot整合Redis（生产实战）

Spring Boot通过spring-boot-starter-data-redis简化Redis整合，默认集成Lettuce，支持Jedis替换，提供RedisTemplate和StringRedisTemplate两个核心模板，无需手动初始化客户端，大幅提升开发效率。

## 3.1 基础配置（application.yml）

核心配置包括Redis连接信息、连接池配置、序列化配置，适配单节点、集群两种场景，可直接复制使用。

```yaml
# Spring Boot整合Redis基础配置（单节点）
spring:
  redis:
    host: 127.0.0.1  # Redis地址
    port: 6379       # 端口
    password: 123456 # 密码（无密码可省略）
    timeout: 3000ms  # 超时时间
    lettuce:         # 默认Lettuce客户端配置（替换为Jedis可修改为jedis）
      pool:
        max-active: 50    # 最大连接数
        max-idle: 20      # 最大空闲连接
        min-idle: 5       # 最小空闲连接
        max-wait: 3000ms  # 最大等待时间

# 集群配置（替换单节点配置，按需使用）
# spring:
#   redis:
#     password: 123456
#     timeout: 3000ms
#     cluster:
#       nodes: 127.0.0.1:6379,127.0.0.1:6380,127.0.0.1:6381  # 集群节点
#       max-redirects: 3  # 最大重定向次数
#     lettuce:
#       pool:
#         max-active: 50
#         max-idle: 20
#         min-idle: 5
#         max-wait: 3000ms
```

## 3.2 核心模板使用（RedisTemplate vs StringRedisTemplate）

Spring Boot提供两个核心模板，两者区别在于序列化方式，生产中优先使用StringRedisTemplate（避免序列化异常）。

### 3.2.1 StringRedisTemplate（推荐使用）

StringRedisTemplate默认使用String序列化，适用于key和value都是String类型的场景，无需额外配置，直接注入使用：

```java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

@Component
public class StringRedisTemplateDemo {

    // 注入StringRedisTemplate（Spring自动初始化）
    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    // 1. String类型操作
    public void stringOps() {
        // 设置值（带过期时间）
        stringRedisTemplate.opsForValue().set("spring:name", "SpringRedis", 60, TimeUnit.SECONDS);
        // 获取值
        String name = stringRedisTemplate.opsForValue().get("spring:name");
        System.out.println("StringRedisTemplate String：" + name);
    }

    // 2. Hash类型操作
    public void hashOps() {
        stringRedisTemplate.opsForHash().put("spring:user:1006", "name", "周八");
        stringRedisTemplate.opsForHash().put("spring:user:1006", "age", "28");
        // 获取单个字段值
        String userName = (String) stringRedisTemplate.opsForHash().get("spring:user:1006", "name");
        System.out.println("StringRedisTemplate Hash：" + userName);
    }

    // 3. 其他类型操作（List、Set、ZSet）与上述类似，调用对应opsForXxx()方法
}

```

### 3.2.2 RedisTemplate（自定义序列化）

RedisTemplate默认使用JdkSerializationRedisSerializer，会导致key和value序列化后出现乱码，需自定义序列化（推荐使用Jackson2JsonRedisSerializer），适用于value为Java对象的场景：

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.serializer.Jackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.StringRedisSerializer;

import com.fasterxml.jackson.databind.ObjectMapper;

@Configuration
public class RedisConfig {

    // 自定义RedisTemplate序列化配置
    @Bean
    public RedisTemplate<String, Object> redisTemplate(LettuceConnectionFactory lettuceConnectionFactory) {
        RedisTemplate<String, Object> redisTemplate = new RedisTemplate<>();
        // 设置连接工厂
        redisTemplate.setConnectionFactory(lettuceConnectionFactory);

        // 初始化Jackson序列化器
        Jackson2JsonRedisSerializer<Object> jacksonSerializer = new Jackson2JsonRedisSerializer<>(Object.class);
        ObjectMapper objectMapper = new ObjectMapper();
        // 允许序列化所有类
        objectMapper.activateDefaultTyping(objectMapper.getPolymorphicTypeValidator(), ObjectMapper.DefaultTyping.NON_FINAL);
        jacksonSerializer.setObjectMapper(objectMapper);

        // 设置key序列化方式（String）
        redisTemplate.setKeySerializer(new StringRedisSerializer());
        redisTemplate.setHashKeySerializer(new StringRedisSerializer());

        // 设置value序列化方式（Jackson）
        redisTemplate.setValueSerializer(jacksonSerializer);
        redisTemplate.setHashValueSerializer(jacksonSerializer);

        // 初始化RedisTemplate
        redisTemplate.afterPropertiesSet();
        return redisTemplate;
    }
}

```

使用示例（value为Java对象）：

```java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

@Component
public class RedisTemplateDemo {

    @Autowired
    private RedisTemplate<String, Object> redisTemplate;

    // 存储Java对象
    public void saveObject() {
        // 模拟用户对象
        User user = new User(1007, "吴九", 30);
        // 存储对象（自动序列化为JSON）
        redisTemplate.opsForValue().set("spring:user:1007", user, 60, TimeUnit.SECONDS);
        // 获取对象（自动反序列化为Java对象）
        User userFromRedis = (User) redisTemplate.opsForValue().get("spring:user:1007");
        System.out.println("RedisTemplate 存储对象：" + userFromRedis);
    }

    // 静态内部类（模拟用户对象）
    static class User {
        private Integer id;
        private String name;
        private Integer age;

        // 构造方法、getter、setter
        public User(Integer id, String name, Integer age) {
            this.id = id;
            this.name = name;
            this.age = age;
        }

        @Override
        public String toString() {
            return "User{id=" + id + ", name='" + name + "', age=" + age + "}";
        }
    }
}

```

## 3.3 Spring Boot整合Redis注意事项（生产避坑）

- 序列化选择：优先使用StringRedisTemplate，若需存储Java对象，必须自定义RedisTemplate的序列化方式，避免乱码。

- 连接池配置：必须配置连接池参数（max-active、max-idle等），避免连接不足导致的性能瓶颈。

- 异常处理：所有Redis操作需捕获异常（如RedisConnectionFailureException），记录日志，避免影响主线程。

- 集群适配：整合Redis集群时，只需配置cluster.nodes，Spring自动适配集群逻辑，无需手动处理分片。

- 避免频繁调用：高频操作（如循环调用set）需批量处理（使用Pipeline），减少网络往返次数。

# 四、Java客户端生产实战场景（落地必备）

结合实际业务场景，拆解Java客户端的核心实战用法，覆盖缓存、分布式锁、限流等高频场景，可直接复用代码。

## 4.1 场景1：缓存查询（最常用）

核心逻辑：查询数据时，先查Redis缓存，缓存命中则直接返回；缓存未命中则查询数据库，将结果存入缓存，设置过期时间，避免缓存穿透、击穿。

```java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class CacheQueryService {

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    // 模拟数据库查询
    private String queryFromDB(Integer id) {
        // 实际场景中调用DAO层查询数据库
        return "数据库数据：用户ID=" + id;
    }

    // 缓存查询实战（避免缓存穿透、击穿）
    public String queryWithCache(Integer id) {
        String key = "cache:user:" + id;
        // 1. 先查缓存
        String data = stringRedisTemplate.opsForValue().get(key);
        if (data != null) {
            // 缓存命中，直接返回
            return data;
        }

        // 2. 缓存未命中，查询数据库
        data = queryFromDB(id);
        if (data == null) {
            // 数据库也无数据，设置空值缓存（避免缓存穿透），短期过期
            stringRedisTemplate.opsForValue().set(key, "", 5, TimeUnit.MINUTES);
            return null;
        }

        // 3. 将数据库数据存入缓存，设置过期时间（避免缓存雪崩）
        stringRedisTemplate.opsForValue().set(key, data, 30, TimeUnit.MINUTES);
        return data;
    }
}

```

## 4.2 场景2：分布式锁（Redisson实战）

分布式项目中，多节点竞争同一资源（如商品库存扣减），需使用分布式锁保证原子性，Redisson封装了分布式锁的实现，开箱即用，避免手动实现锁的坑。

```java
import org.redisson.api.RLock;
import org.redisson.api.RedissonClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.concurrent.TimeUnit;

@Service
public class DistributedLockService {

    @Autowired
    private RedissonClient redissonClient;

    // 模拟商品库存扣减
    private Integer stock = 100;

    // 分布式锁实战（商品库存扣减）
    public boolean deductStock(Integer productId) {
        // 1. 定义锁的key（唯一标识，如商品ID）
        String lockKey = "lock:product:stock:" + productId;

        // 2. 获取分布式锁
        RLock lock = redissonClient.getLock(lockKey);

        try {
            // 3. 尝试获取锁（等待10秒，持有30秒，自动释放）
            boolean acquired = lock.tryLock(10, 30, TimeUnit.SECONDS);
            if (!acquired) {
                // 未获取到锁，返回失败
                return false;
            }

            // 4. 获得锁，执行库存扣减（原子操作）
            if (stock > 0) {
                stock--;
                System.out.println("库存扣减成功，剩余库存：" + stock);
                return true;
            } else {
                System.out.println("库存不足，扣减失败");
                return false;
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
            return false;
        } finally {
            // 5. 释放锁（必须在finally中释放，避免死锁）
            if (lock.isHeldByCurrentThread()) {
                lock.unlock();
            }
        }
    }
}

```

## 4.3 场景3：批量操作（Pipeline优化）

高频小批量操作（如批量插入、批量查询），使用Pipeline批量执行命令，减少网络往返次数，提升性能（Jedis、Lettuce、Spring RedisTemplate均支持）。

```java
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class PipelineService {

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    // Spring RedisTemplate批量插入（Pipeline）
    public void batchInsert() {
        // 批量插入100条数据，使用Pipeline减少网络往返
        stringRedisTemplate.executePipelined((connection) -> {
            for (int i = 1; i <= 100; i++) {
                String key = "pipeline:key:" + i;
                String value = "value:" + i;
                // 批量执行set命令
                connection.set(key.getBytes(), value.getBytes());
            }
            return null;
        });
        System.out.println("批量插入完成");
    }

    // 批量查询（Pipeline）
    public void batchQuery() {
        stringRedisTemplate.executePipelined((connection) -> {
            for (int i = 1; i <= 100; i++) {
                String key = "pipeline:key:" + i;
                // 批量执行get命令
                connection.get(key.getBytes());
            }
            return null;
        });
        System.out.println("批量查询完成");
    }
}

```

## 4.4 场景4：过期键监听（业务通知）

某些场景下（如订单超时取消），需监听Redis过期键，当键过期时触发业务逻辑，Lettuce和Spring Redis均支持过期键监听。

```java
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.KeyExpirationEventMessageListener;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;

@Configuration
public class RedisKeyExpireConfig {

    // 配置Redis消息监听容器
    @Bean
    public RedisMessageListenerContainer redisMessageListenerContainer(RedisConnectionFactory connectionFactory) {
        RedisMessageListenerContainer container = new RedisMessageListenerContainer();
        container.setConnectionFactory(connectionFactory);
        return container;
    }

    // 监听过期键事件
    @Bean
    public KeyExpirationEventMessageListener keyExpirationListener(RedisMessageListenerContainer container) {
        // 自定义监听逻辑（继承KeyExpirationEventMessageListener）
        return new KeyExpirationEventMessageListener(container) {
            @Override
            public void onMessage(org.springframework.data.redis.connection.Message message, byte[] pattern) {
                // 获取过期的key
                String expiredKey = new String(message.getBody());
                System.out.println("Redis键过期：" + expiredKey);

                // 触发业务逻辑（如订单超时取消）
                if (expiredKey.startsWith("order:timeout:")) {
                    String orderId = expiredKey.split(":")[2];
                    cancelOrder(orderId); // 订单取消方法
                }
            }

            // 模拟订单取消
            private void cancelOrder(String orderId) {
                System.out.println("订单" + orderId + "超时，执行取消操作");
            }
        };
    }
}

```

# 五、Java客户端性能优化（生产重点）

## 5.1 连接池优化（核心）

- 参数调整：根据项目并发量调整连接池参数，避免连接过多（浪费资源）或连接不足（阻塞请求）。
        

    - max-active：建议设置为业务最大并发量的1.5-2倍（如最大并发100，设置为150-200）。

    - max-idle：建议设置为max-active的50%-70%，减少连接创建开销。

    - min-idle：建议设置为max-active的10%-20%，保证有空闲连接可用。

    - max-wait：建议设置为3000-5000ms，避免无限等待导致请求超时。

- 连接校验：开启连接校验（testOnBorrow、testOnReturn），避免使用无效连接，减少异常。

## 5.2 命令优化（减少网络开销）

- 批量操作：使用Pipeline批量执行命令，减少网络往返次数（如批量插入、批量查询）。

- 避免阻塞命令：禁止使用KEYS、HGETALL、SMEMBERS等阻塞命令，替换为SCAN、HSCAN、SSCAN等非阻塞命令。

- 合理使用序列化：选择高效的序列化方式（如String、Jackson），避免使用JDK序列化（效率低、占用空间大）。

- 减少大键操作：避免存储大键（单键超过1MB），大键的读写会占用大量网络带宽和Redis资源。

## 5.3 高并发优化（Lettuce重点）

- 使用异步操作：高并发场景下，优先使用Lettuce的异步操作（AsyncRedisCommands），避免阻塞主线程，提升系统吞吐量。

- 连接共享：StatefulRedisConnection是线程安全的，可在多线程间共享，无需为每个线程创建新连接。

- 集群分片：高并发、大内存场景，使用Redis Cluster分片，分散单节点压力，提升并发处理能力。

## 5.4 缓存优化（避免常见问题）

- 设置合理过期时间：为缓存key设置过期时间，避免缓存雪崩（给不同key设置随机过期时间）。

- 缓存穿透防护：对不存在的key设置空值缓存，或使用布隆过滤器过滤无效key。

- 缓存击穿防护：对热点key设置永不过期，或使用分布式锁保护热点key。

- 缓存更新策略：采用“更新数据库+删除缓存”或“先删除缓存+更新数据库”策略，确保缓存与数据库数据一致。

# 六、Java客户端常见问题与避坑指南

|常见问题|问题原因|避坑方案|
|---|---|---|
|连接泄露|Jedis未关闭连接、try-with-resources使用不当，导致连接池耗尽|使用try-with-resources自动关闭连接，定期检查连接池状态，避免手动关闭连接遗漏|
|序列化乱码|RedisTemplate使用默认JDK序列化，或序列化方式不统一|优先使用StringRedisTemplate，存储对象时自定义Jackson序列化，保证序列化方式统一|
|高并发卡顿|使用Jedis（BIO模型）、未使用异步操作、连接池参数不合理|替换为Lettuce，使用异步操作，优化连接池参数，使用Pipeline批量操作|
|分布式锁死锁|未释放锁、锁过期时间过短、异常导致锁未释放|使用Redisson分布式锁（自动释放），在finally中释放锁，合理设置锁过期时间|
|缓存与数据库不一致|缓存更新策略不合理，未及时删除/更新缓存|采用“更新数据库+删除缓存”策略，高频场景可引入消息队列保证一致性|
|集群连接失败|集群节点配置错误、密码错误、网络不通、槽位分配异常|检查集群节点地址和密码，确保网络通畅，查看集群槽位分配状态（CLUSTER INFO）|
# 七、总结

1. Java客户端核心选型：高并发、集群场景优先Lettuce，分布式场景需高级功能选Redisson，小型项目快速开发选Jedis，避免混合使用。

2. 核心客户端用法：Jedis需手动管理连接池，Lettuce基于NIO支持异步，Spring Boot整合Redis通过RedisTemplate/StringRedisTemplate简化开发，无需手动初始化。

3. 生产实战场景：重点掌握缓存查询、分布式锁、批量操作、过期键监听，可直接复用实战代码，提升开发效率。

4. 性能优化核心：优化连接池参数、使用Pipeline批量操作、避免阻塞命令、合理设置缓存过期时间，Lettuce场景优先使用异步操作。

5. 常见避坑点：避免连接泄露、序列化乱码、死锁、缓存与数据库不一致，集群场景需确保节点配置正确、网络通畅。

6. 关键面试考点：客户端选型对比、Spring Boot整合Redis、分布式锁实现、缓存优化策略、常见问题排查与解决。