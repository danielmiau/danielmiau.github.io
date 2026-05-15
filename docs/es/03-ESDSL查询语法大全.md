# 03-ES DSL查询语法大全

## 本章概述

本章为ES**极高权重、业务开发最核心**的必修章节，是日常项目开发、商品搜索、内容检索、数据筛选的核心能力支撑。本章核心目标为：系统掌握ES两大核心查询体系——精准查询与全文检索，吃透term、match系列所有常用查询语法，熟练掌握bool布尔多条件组合查询，理解查询算分机制与过滤优化原理。所有语法均配套可直接复制运行的实操案例、场景说明、生产避坑方案，帮助开发者彻底告别“只会抄代码不懂原理”的问题，能够独立完成复杂多条件检索需求，同时覆盖面试高频考点，为后续聚合查询、高亮、排序分页等进阶功能打下坚实基础。

---

# 1. 查询基础分类

ES所有查询语法可分为两大体系：**精准查询（Term系列）**与**全文检索（Match系列）**。二者底层执行逻辑、适用场景、性能差异极大，是开发必须区分的核心知识点：精准查询不分词、完全匹配，多用于结构化字段筛选；全文检索自动分词、模糊匹配，多用于文本内容搜索。

## 1.1 精准查询term系列

**精准查询核心特性**：查询关键词**不会被分词**，直接以完整词条去倒排索引匹配，要求字段存储的词条与查询内容**完全一致**才能命中，**仅适配keyword、数值、日期、布尔等结构化字段**，不可用于text分词字段常规检索。

### 1.1.1 term单词条精准查询

**1. 概念定义**

term查询是最基础的精准查询，用于**单个词条完全匹配**，查询内容不经过分词，直接匹配索引中存储的完整词条。

**2. 适用场景**

精准匹配固定字段：商品状态、分类ID、用户性别、手机号、订单编号、状态码等无需分词的结构化字段。

**3. 完整实操示例**

需求：查询商品状态为「上架」的所有商品数据（status为keyword类型）

```json
# term 单条件精准查询
GET /goods_index/_search
{
  "query": {
    "term": {
      "status": {          // 目标字段：必须为keyword/数值类型
        "value": "上架",    // 精准匹配值，不分词
        "boost": 1.0       // 权重分值，默认1.0，可用于手动提升排序权重
      }
    }
  }
}
```

**4. 生产避坑（高频Bug点）**

term查询**绝对不能用于text字段**！text字段入库时已被分词拆分，不存在完整的原文词条，使用term查询会出现「数据存在但查询不到」的问题。

举例：text类型的title字段存的是「Java开发教程」，分词后为多个单字/词语词条，用term匹配完整字符串「Java开发教程」无法命中。

### 1.1.2 terms多词条批量查询

**1. 概念定义**

terms查询是term查询的批量增强版，支持**一次性传入多个精准词条**，满足任意一个词条即可命中，等价于SQL中的 **in ()** 查询。

**2. 适用场景**

多值筛选场景：查询多个商品分类、多个状态、多个用户ID、多个标签等批量精准匹配需求。

**3. 完整实操示例**

需求：查询商品状态为「上架、预售」的所有数据

```json
# terms 多词条批量精准查询
GET /goods_index/_search
{
  "query": {
    "terms": {
      "status": [        // 传入多个精准匹配词条
        "上架",
        "预售"
      ],
      "boost": 1.0
    }
  }
}
```

**4. 核心注意事项**

terms查询同样**不进行分词**，所有传入值必须和索引词条完全匹配；支持数组传参，无数量严格限制，批量筛选性能优异。

### 1.1.3 range范围区间查询

**1. 概念定义**

range范围查询用于**数值、日期类型字段的区间筛选**，支持大于、小于、大于等于、小于等于、区间范围匹配，是结构化数据筛选的核心语法。

**2. 核心匹配符号**

- **gt**：大于（不包含边界）

- **gte**：大于等于（包含边界）

- **lt**：小于（不包含边界）

- **lte**：小于等于（包含边界）

**3. 适用场景**

价格区间筛选、时间范围筛选、销量区间筛选、分数区间筛选等数值类范围业务。

**4. 实操示例1：数值区间查询**

需求：查询价格在100 ~ 500元之间的商品（包含边界）

```json
# 数值范围查询
GET /goods_index/_search
{
  "query": {
    "range": {
      "price": {
        "gte": 100,  // 大于等于100
        "lte": 500   // 小于等于500
      }
    }
  }
}
```

**5. 实操示例2：日期范围查询**

需求：查询近7天创建的商品数据

```json
# 日期范围查询
GET /goods_index/_search
{
  "query": {
    "range": {
      "create_time": {
        "gte": "now-7d", // 当前时间往前7天
        "lte": "now"     // 当前时间
      }
    }
  }
}
```

**6. 生产时间语法简写（常用）**

now-1d：昨天、now-1h：一小时前、now-30m：三十分钟前，无需手动拼接时间字符串，适配动态时间筛选需求。

### 1.1.4 exists非空字段查询

**1. 概念定义**

exists查询用于判断文档中**指定字段是否存在、是否非空**，可以筛选出字段有值或字段为空的文档。

**2. 适用场景**

筛选必填字段缺失数据、过滤无封面商品、筛选有备注数据、清洗脏数据等业务场景。

**3. 实操示例**

需求：查询有商品封面图的所有商品数据（cover字段不为空）

```json
# exists 非空字段查询
GET /goods_index/_search
{
  "query": {
    "exists": {
      "field": "cover" // 查询该字段有值的文档
    }
  }
}
```

**4. 扩展：查询字段为空数据**

结合后续must_not语法，可实现查询字段为空、字段不存在的文档，用于数据清洗。

## 1.2 全文检索match系列

**全文检索核心特性**：查询关键词**会自动经过分词器拆分**，适配text分词字段，用于模糊搜索、全文匹配，是用户端商品搜索、内容检索的核心语法，支持相关性打分排序。

### 1.2.1 match分词模糊查询

**1. 概念定义**

match是ES**最常用的全文检索语法**，会自动对查询关键词分词，拆分多个词条，只要文档匹配任意一个词条即可命中，同时自动计算相关性分数排序。

**2. 核心执行逻辑**

关键词分词 → 多词条匹配 → 综合打分 → 按相关性降序排序。

**3. 适用场景**

用户输入关键词搜索商品、文章、内容，模糊匹配全文数据，是90%用户端搜索的底层语法。

**4. 实操示例**

需求：搜索标题包含「Java开发」的商品

```json
# match 分词模糊全文检索
GET /goods_index/_search
{
  "query": {
    "match": {
      "goods_name": {
        "query": "Java开发", // 关键词会被分词为 Java、开发
        "operator": "or"     // 默认or，匹配任意一个词条即命中
      }
    }
  }
}
```

**5. 核心参数详解**

- **operator: or**：默认值，匹配任意一个词条即可命中，检索范围广；

- **operator: and**：必须匹配**所有分词词条**才能命中，检索更精准，范围更小。

**6. 生产最佳实践**

普通搜索使用默认or，精准搜索场景手动改为and，兼顾检索覆盖率与精准度。

### 1.2.2 match_phrase短语精确匹配

**1. 概念定义**

match_phrase为**短语精准匹配**，同样会对关键词分词，但要求：**所有词条必须全部命中，且词条相对位置连续、顺序一致**，相比普通match更精准。

**2. 核心区别**

match：无序、部分匹配即可；match_phrase：有序、连续、全部词条匹配，严格匹配短语。

**3. 适用场景**

精准短语搜索、标题完整片段匹配、固定话术检索、禁止乱序匹配的业务场景。

**4. 实操示例**

需求：精准匹配标题中包含连续短语「Java实战开发」的商品

```json
# match_phrase 短语精准匹配
GET /goods_index/_search
{
  "query": {
    "match_phrase": {
      "goods_name": {
        "query": "Java实战开发",
        "slop": 0 // 词条之间允许的间隔步数，默认0：必须连续无间隔
      }
    }
  }
}
```

**5. slop参数妙用**

slop=1：允许词条中间间隔1个无关词汇，适配轻微语序打乱的场景，兼顾精准与容错。

### 1.2.3 match_all查询全部文档

**1. 概念定义**

match_all是最简单的查询语法，**查询索引下所有文档数据**，无任何筛选条件，默认按相关性分数排序（所有分数一致）。

**2. 适用场景**

全量数据导出、默认列表页、无筛选条件的分页查询、测试索引数据是否正常。

**3. 实操示例**

```json
# match_all 查询全部文档
GET /goods_index/_search
{
  "query": {
    "match_all": {} // 无条件查询所有数据
  }
}
```

**4. 生产避坑**

生产环境禁止无限制使用match_all全量查询，海量数据会导致OOM、集群压力飙升，必须配合分页from+size限制数据条数。

---

# 2. 组合多条件查询

实际业务中几乎没有单一条件查询，都是多条件组合筛选。ES通过**bool布尔查询**实现多条件嵌套组合，是复杂检索需求的核心解决方案，支持精准条件、模糊条件、范围条件、排除条件任意组合。

## 2.1 bool布尔查询核心

bool查询包含四种核心子句，各司其职，可自由嵌套组合，覆盖所有多条件查询场景，也是面试高频考点。

### 2.1.1 must同时满足条件

**1. 核心特性**

must子句内的所有条件**必须全部同时满足**，等价于SQL的 AND，**会参与相关性打分、影响排序权重**。

**2. 适用场景**

需要检索打分、影响排序的必填检索条件，例如用户关键词搜索、核心文本匹配。

**3. 实操示例**

需求：搜索标题包含Java、且状态为上架的商品（两个条件同时满足，参与打分）

```json
# bool must 多条件同时满足
GET /goods_index/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "match": {
            "goods_name": "Java"
          }
        },
        {
          "term": {
            "status": "上架"
          }
        }
      ]
    }
  }
}
```

### 2.1.2 should或满足条件

**1. 核心特性**

should子句内的条件**满足任意一个即可**，等价于SQL的 OR，**会参与相关性打分**，满足的条件越多，分数越高，排名越靠前。

**2. 适用场景**

多条件模糊匹配、权重加分场景、可选筛选条件，用于提升检索相关性。

**3. 实操示例**

需求：搜索标题包含Java 或 ES的商品，匹配越多排名越靠前

```json
# bool should 或条件查询
GET /goods_index/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "goods_name": "Java"
          }
        },
        {
          "match": {
            "goods_name": "ES"
          }
        }
      ]
    }
  }
}
```

### 2.1.3 must_not排除条件

**1. 核心特性**

must_not子句用于**排除不满足的条件**，等价于SQL的 NOT，条件全部不匹配才会命中数据，**不参与检索打分**，仅做数据过滤。

**2. 适用场景**

过滤删除数据、过滤下架商品、过滤指定标签、排除无效脏数据。

**3. 实操示例**

需求：排除状态为下架、预售的商品

```json
# bool must_not 条件排除
GET /goods_index/_search
{
  "query": {
    "bool": {
      "must_not": [
        {
          "terms": {
            "status": ["下架","预售"]
          }
        }
      ]
    }
  }
}
```

### 2.1.4 filter过滤无算分查询

**1. 核心特性**

filter子句要求**所有条件必须同时满足**（同must），但**不进行相关性打分、不影响排序、可缓存查询结果**，查询性能远高于must。

**2. 核心优势**

无算分逻辑、开销极低、支持查询缓存，海量数据筛选性能最优。

**3. 适用场景**

所有结构化固定筛选条件：价格区间、时间范围、状态筛选、分类筛选，无需排序打分的条件全部放入filter。

**4. 实操示例**

需求：筛选价格100-500元、已上架的商品（纯过滤，不打分）

```json
# bool filter 无算分过滤查询
GET /goods_index/_search
{
  "query": {
    "bool": {
      "filter": [
        {
          "range": {
            "price": {
              "gte": 100,
              "lte": 500
            }
          }
        },
        {
          "term": {
            "status": "上架"
          }
        }
      ]
    }
  }
}
```

## 2.2 布尔查询权重与使用场景

bool查询的性能优劣、排序精准度，完全取决于条件放置位置，生产环境必须遵循固定的放置规范，这是ES检索优化的核心基础。

### 2.2.1 过滤条件优先放filter

**1. 核心规范（生产强制规范+面试必背）**

**所有结构化、无需打分的筛选条件，一律放入filter**，禁止放入must。

**2. 为什么优先用filter？**

- 无相关性算分计算，CPU开销大幅降低；

- filter查询结果会被ES自动缓存，重复查询直接读取缓存，性能大幅提升；

- 精准过滤数据范围，减少后续打分计算的数据量。

**3. 适合filter的条件**

term、terms、range、exists、时间筛选、价格筛选、状态筛选、分类筛选。

### 2.2.2 检索打分条件放must

**1. 核心规范**

**所有需要分词检索、需要相关性排序的文本条件，一律放入must/should**。

**2. 原理说明**

用户关键词搜索需要根据匹配度智能排序，must/should会对匹配结果进行TF-IDF相关性打分，让最贴合用户需求的结果排在最前面，而filter无打分逻辑，无法实现智能排序。

**3. 适合must的条件**

match、match_phrase全文检索、核心文本匹配、需要参与权重排序的条件。

**4. 生产标准组合模板（可直接复用）**

must放文本检索打分条件，filter放结构化过滤条件，must_not放排除条件，should放加分条件：

```json
# 生产标准多条件组合查询模板
GET /goods_index/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {"goods_name": "Java"}} // 文本检索，需要打分排序
      ],
      "filter": [
        {"term": {"status": "上架"}},      // 状态过滤，无打分
        {"range": {"price": {"gte": 100}}} // 价格过滤，无打分
      ],
      "must_not": [
        {"term": {"is_delete": true}}      // 排除已删除数据
      ],
      "should": [
        {"term": {"is_hot": true}}         // 热门商品加分排序
      ]
    }
  }
}
```

---

# 3. 高级常用查询

基础的精准查询与全文检索可满足常规业务，而电商模糊前缀搜索、自定义规则匹配、附近门店检索等复杂场景，需要依赖ES高级查询语法。本节讲解生产高频使用的模糊匹配进阶语法与地理位置检索语法，所有语法配套实操案例、场景适配与性能避坑方案。

## 3.1 前缀、通配、正则查询

此类查询属于**高级模糊精准匹配**，区别于match分词检索，均基于词条本身匹配，不依赖分词逻辑，主要用于keyword类型字段的自定义模糊匹配，适合账号、编号、商品编码、自定义标签等结构化文本字段检索。

### 3.1.1 prefix前缀匹配查询

**1. 概念定义**

prefix前缀查询用于**匹配以指定关键词开头的词条**，无需完整匹配，仅校验词条前缀一致即可命中，属于高效的左模糊查询。查询过程不进行分词，直接基于倒排索引词条前缀匹配。

**2. 核心适用场景**

账号前缀搜索、订单号前缀匹配、商品编码左模糊查询、用户输入实时联想提示等场景。

**3. 完整实操示例**

需求：查询商品编码以「SP2026」开头的所有商品（goods_code为keyword类型）

```json
# prefix 前缀左模糊查询
GET /goods_index/_search
{
  "query": {
    "prefix": {
      "goods_code": {
        "value": "SP2026",  // 匹配前缀
        "boost": 1.0        // 权重分值
      }
    }
  }
}
```

**4. 生产避坑与性能说明**

prefix仅支持**左前缀匹配**，不支持中缀、后缀匹配；基于倒排索引前缀检索，性能远优于通配符、正则查询；仅可用于keyword字段，text分词字段前缀匹配无效。

### 3.1.2 wildcard通配符查询

**1. 概念定义**

wildcard通配符查询是全能模糊匹配语法，支持自定义通配符实现左模糊、右模糊、全模糊匹配，适配灵活的模糊检索场景。

**2. 核心通配符规则**

- **?**：匹配任意**单个**字符

- *****：匹配**0个或多个**任意字符

**3. 实操示例**

需求1：匹配商品编码中间包含2026，前后任意字符的商品

```json
# wildcard 中间模糊匹配
GET /goods_index/_search
{
  "query": {
    "wildcard": {
      "goods_code": {
        "value": "*2026*"
      }
    }
  }
}
```

需求2：匹配前缀SP、后接任意一位字符的商品编码

```json
# wildcard 单字符精准模糊匹配
GET /goods_index/_search
{
  "query": {
    "wildcard": {
      "goods_code": {
        "value": "SP?"
      }
    }
  }
}
```

**4. 生产性能避坑（高频面试考点）**

**禁止使用前置通配符 *xxx**！倒排索引是前缀有序存储，前置通配符会导致索引失效，触发全量扫描，海量数据下性能极差；优先使用prefix前缀查询，非必要不使用wildcard。

### 3.1.3 regexp正则查询

**1. 概念定义**

regexp正则查询支持通过**正则表达式**匹配词条，是自由度最高的精准模糊查询，可实现所有复杂规则的字符串匹配，适配标准化格式字段校验与筛选。

**2. 适用场景**

手机号格式筛选、身份证合规校验、自定义编码规则匹配、复杂格式字符串筛选。

**3. 实操示例**

需求：匹配11位手机号格式的用户数据（phone为keyword字段）

```json
# regexp 正则匹配查询
GET /user_index/_search
{
  "query": {
    "regexp": {
      "phone": "^1[0-9]{10}$" // 1开头，后续10位数字的手机号正则
    }
  }
}
```

**4. 生产最佳实践**

正则查询性能最差，仅用于少量数据、低频筛选场景；海量数据场景禁止频繁使用regexp，极易造成集群CPU飙升。

## 3.2 地理位置查询

ES内置完善的LBS地理位置检索能力，基于前文讲解的geo_point地理坐标字段，可实现附近范围、区域圈选等检索，是同城门店、附近骑手、周边房源等LBS业务的核心支撑。

### 3.2.1 距离范围查询

**1. 概念定义**

geo_distance距离查询，以**指定经纬度为圆心、指定距离为半径**，查询圆形范围内的所有地理位置数据，是「附近门店」场景的核心语法。

**2. 核心参数说明**

- location：中心点经纬度（纬度、经度）

- distance：检索半径，支持km、m单位

- distance_type：距离计算方式，默认球面距离

**3. 完整实操示例**

需求：查询当前坐标（深圳）5km范围内的所有门店

```json
# geo_distance 圆形范围附近查询
GET /shop_index/_search
{
  "query": {
    "geo_distance": {
      "distance": "5km",        // 检索半径5公里
      "location": {             // 中心点坐标：纬度、经度
        "lat": "22.543096",
        "lon": "114.057868"
      }
    }
  }
}
```

**4. 拓展排序场景**

可结合sort排序，实现「由近到远」的门店排序效果，完美适配用户附近列表业务。

### 3.2.2 矩形区域范围查询

**1. 概念定义**

geo_bounding_box矩形区域查询，通过**左上角、右下角两个坐标点**确定一个矩形范围，查询落在该矩形区域内的所有地理位置数据，适配地图框选检索场景。

**2. 核心参数**

- top_left：矩形左上角经纬度

- bottom_right：矩形右下角经纬度

**3. 实操示例**

需求：查询指定矩形区域内的所有门店数据

```json
# geo_bounding_box 矩形区域查询
GET /shop_index/_search
{
  "query": {
    "geo_bounding_box": {
      "location": {
        "top_left": {        // 左上角坐标
          "lat": "22.600000",
          "lon": "114.000000"
        },
        "bottom_right": {   // 右下角坐标
          "lat": "22.500000",
          "lon": "114.100000"
        }
      }
    }
  }
}
```



# 4.查询打分与权重控制

ES全文检索默认会根据文本匹配度自动打分排序，理解默认打分机制是优化检索排序的基础。同时生产业务常需要自定义字段权重、固定排序规则，本节详解TF-IDF打分原理与自定义权重方案，解决「检索结果排序不符合业务预期」的核心问题。

## 4.1 ES默认打分机制TF-IDF

ES 5.0版本后默认采用**BM25算法**替代传统TF-IDF，但核心逻辑仍围绕词频、逆文档频率展开，面试常统称TF-IDF打分机制，是检索相关性排序的底层核心。

### 4.1.1 词频与逆文档频率原理

**1. TF（词频 Term Frequency）**

定义：**单个词条在当前文档中出现的次数**。

核心逻辑：词条在当前文档中出现次数越多，说明该文档与检索关键词相关性越高，打分越高、排名越靠前。

BM25优化：限制词频无限叠加，避免长文本词条重复过多导致排序失真。

**2. IDF（逆文档频率 Inverse Document Frequency）**

定义：**词条在整个索引所有文档中的稀缺程度**。

核心逻辑：词条在全局文档中出现次数越少、越稀缺，区分度越高，权重分值越高；通用高频词汇（的、是、and等）IDF分值极低，对排序几乎无影响。

### 4.1.2 检索排序打分逻辑

**1. 完整打分公式逻辑（通俗版）**

最终分数 = 词频权重（当前文档匹配次数） + 逆文档频率权重（词条稀缺度） + 位置权重（词条匹配位置）

**2. 排序优先级规则**

- 匹配词条数量越多，分数越高；

- 稀缺词条匹配优先加分；

- 词条在文本靠前位置匹配，权重更高；

- 重复匹配适度加分，不会无限叠加。

**3. 面试高频问题**

问：为什么冷门关键词检索结果更精准？答：冷门词条IDF值极高，匹配权重极大，优先置顶；热门通用词条IDF值极低，排序区分度弱。

## 4.2 自定义字段查询权重

默认打分机制是全局统一规则，无法适配业务个性化排序需求。例如电商搜索中，商品标题匹配权重应远高于商品详情匹配，本节通过boost参数实现自定义权重排序。

### 4.2.1 boost权重提升设置

**1. 概念定义**

boost是ES内置权重参数，可对**指定查询条件、指定字段**设置权重系数，系数越大，匹配后得分越高，排序越靠前。默认权重为1.0。

**2. 业务场景**

标题匹配权重3倍、简介匹配权重2倍、详情匹配权重1倍，实现核心字段优先匹配置顶。

**3. 实操示例（多字段权重差异化）**

```json
# 自定义字段权重排序
GET /goods_index/_search
{
  "query": {
    "bool": {
      "should": [
        {
          "match": {
            "goods_name": {    // 商品标题权重最高
              "query": "Java",
              "boost": 3.0
            }
          }
        },
        {
          "match": {
            "goods_desc": {    // 商品详情权重最低
              "query": "Java",
              "boost": 1.0
            }
          }
        }
      ]
    }
  }
}
```

**4. 生产最佳实践**

权重系数建议设置在1-5之间，过大权重会导致排序失衡，丢失相关性参考意义。

### 4.2.2 固定排序忽略打分

**1. 适用场景**

无需相关性排序，需要**固定业务规则排序**的场景：按销量、价格、创建时间、热度排序，完全忽略ES默认检索打分。

**2. 实现方案**

通过sort排序字段覆盖默认打分排序，sort优先级高于相关性分数。

**3. 实操示例**

```json
# 固定业务排序，忽略检索打分
GET /goods_index/_search
{
  "query": {
    "match": {
      "goods_name": "Java"
    }
  },
  "sort": [
    {"sales": "desc"},    // 销量倒序优先
    {"price": "asc"}      // 销量相同按价格升序
  ]
}
```

**4. 核心结论**

有自定义sort排序时，ES**完全忽略默认打分机制**，严格按照自定义字段规则排序。

# 5. Java客户端操作ES

生产环境不会手动通过Kibana执行DSL查询，全部通过Java代码远程调用ES集群实现检索、写入、批量操作。目前官方唯一推荐、企业通用的客户端为**RestHighLevelClient**，本节完整讲解环境配置、DSL代码构建、批量数据导入全流程，可直接落地项目。

## 5.1 RestHighLevelClient常用API

### 5.1.1 环境依赖与连接配置

**1. Maven核心依赖（SpringBoot环境）**

适配SpringBoot2.x、ES7.x主流版本，生产通用依赖：

```xml
<!-- ES高级客户端依赖 -->
<dependency>
    <groupId>org.elasticsearch.client</groupId>
    <artifactId>elasticsearch-rest-high-level-client</artifactId>
    <version>7.17.0</version>
</dependency>
```

**2. application.yml配置文件**

```yaml
# ES集群配置
elasticsearch:
  host: 127.0.0.1
  port: 9200
  connect-timeout: 5000
  read-timeout: 10000
  write-timeout: 10000
```

**3. 客户端连接配置类（可直接复用）**

```java
import org.apache.http.HttpHost;
import org.elasticsearch.client.RestHighLevelClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;

/**
 * ES客户端配置类
 */
@Configuration
public class EsClientConfig {

    @Value("${elasticsearch.host}")
    private String host;

    @Value("${elasticsearch.port}")
    private Integer port;

    /**
     * 注册ES高级客户端Bean，全局单例
     */
    @Bean
    public RestHighLevelClient restHighLevelClient() {
        return new RestHighLevelClient(
                org.elasticsearch.client.RestClient.builder(new HttpHost(host, port, "http"))
        );
    }
}
```

### 5.1.2 Java构建DSL查询语句

通过Java原生API构建DSL语句，实现全文检索、多条件组合查询，与Kibana手写DSL完全等价，适配业务开发。

**完整实操代码：多条件组合查询**

```java
import org.elasticsearch.action.search.SearchRequest;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.client.RestHighLevelClient;
import org.elasticsearch.index.query.BoolQueryBuilder;
import org.elasticsearch.index.query.QueryBuilders;
import org.elasticsearch.search.SearchHit;
import org.elasticsearch.search.builder.SearchSourceBuilder;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.io.IOException;

/**
 * ES查询业务实操
 */
@Service
public class EsSearchService {

    // 注入全局客户端
    @Resource
    private RestHighLevelClient restHighLevelClient;

    /**
     * 多条件组合查询：标题模糊匹配 + 价格区间 + 状态上架
     */
    public void searchGoods() throws IOException {
        // 1. 创建搜索请求，指定索引名
        SearchRequest searchRequest = new SearchRequest("goods_index");
        SearchSourceBuilder sourceBuilder = new SearchSourceBuilder();

        // 2. 构建布尔组合查询
        BoolQueryBuilder boolQuery = QueryBuilders.boolQuery();

        // must：标题分词模糊检索，参与打分
        boolQuery.must(QueryBuilders.matchQuery("goods_name", "Java开发"));

        // filter：价格区间、状态过滤，无打分可缓存
        boolQuery.filter(QueryBuilders.rangeQuery("price").gte(100).lte(500));
        boolQuery.filter(QueryBuilders.termQuery("status", "上架"));

        // 3. 封装查询条件
        sourceBuilder.query(boolQuery);
        searchRequest.source(sourceBuilder);

        // 4. 执行查询
        SearchResponse response = restHighLevelClient.search(searchRequest);

        // 5. 解析结果
        for (SearchHit hit : response.getHits().getHits()) {
            // 获取文档JSON数据
            String source = hit.getSourceAsString();
            System.out.println("查询结果：" + source);
        }
    }
}
```

**核心说明**

所有DSL语法均对应`QueryBuilders`工具类方法，无需手写JSON字符串，代码简洁、不易出错，支持所有精准查询、全文检索、组合查询语法。

### 5.1.3 批量导入数据实现

单条写入数据性能极低，生产环境海量数据初始化、批量同步必须使用**Bulk批量API**，大幅提升写入吞吐量。

**完整批量写入实操代码**

```java
import org.elasticsearch.action.bulk.BulkRequest;
import org.elasticsearch.action.bulk.BulkResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.client.RestHighLevelClient;
import org.elasticsearch.common.xcontent.XContentType;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.io.IOException;
import java.util.List;

@Service
public class EsBulkService {

    @Resource
    private RestHighLevelClient restHighLevelClient;

    /**
     * 批量导入数据到ES
     * @param dataList 待导入JSON数据列表
     */
    public void bulkImportData(List<String> dataList) throws IOException {
        // 1. 创建批量请求对象
        BulkRequest bulkRequest = new BulkRequest();

        // 2. 循环封装单条数据
        for (String jsonData : dataList) {
            IndexRequest request = new IndexRequest("goods_index");
            // 指定JSON数据，内容格式为JSON
            request.source(jsonData, XContentType.JSON);
            bulkRequest.add(request);
        }

        // 3. 批量执行写入
        BulkResponse bulkResponse = restHighLevelClient.bulk(bulkRequest);

        // 4. 异常排查：打印批量失败信息
        if (bulkResponse.hasFailures()) {
            System.err.println("批量导入失败：" + bulkResponse.buildFailureMessage());
        }
    }
}
```

**生产最佳实践**

批量写入建议控制单次条数在1000-5000条之间，过小频繁IO、过大容易超时，根据服务器性能动态调整。

---

## 本章总结

本章作为ES业务开发极高权重核心章节，补齐了高级检索、排序优化、Java客户端落地的全套能力。核心要点：熟练掌握了prefix、wildcard、regexp三类高级模糊匹配语法及生产性能避坑规则，精通圆形、矩形两类地理位置检索实现LBS业务；深度吃透ES TF-IDF/BM25打分底层原理，掌握词频、逆文档频率的排序逻辑，可通过boost自定义字段权重、通过sort实现固定业务排序，解决检索排序不精准的问题；最后完整掌握RestHighLevelClient的环境配置、DSL代码构建、批量数据导入全流程，实现了从Kibana语法到Java代码落地的完整闭环。本章所有内容均为生产高频落地场景与面试核心考点，下一章将基于本章查询能力，深入讲解ES分页、高亮、聚合统计、结果过滤等进阶优化功能，完善全套检索业务体系。

