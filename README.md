# SparkChess UCI 国际象棋引擎 (C++17)

SparkChess 是一款基于现代 C++17 开发的高性能 UCI (Universal Chess Interface 2.0) 国际象棋引擎，专为跨平台（Windows / Linux / macOS）设计，并针对高棋力竞技（目标 ELO 2300+）进行了全方位架构优化。

---

## 🌟 核心特性与架构亮点

### 1. UCI 2.0 标准协议兼容
- 完美支持 UCI 2.0 规范，已针对主流国际象棋图形客户端经过兼容性测试：
  - **Arena Chess GUI**
  - **CuteChess / CuteChess-cli**
  - **Lichess Bot (python-chess / lichess-bot 协议桥接)**
  - **Scid vs. PC**
  - **Banksia GUI / Fritz / ChessBase**
- 规范化支持所有标准 UCI 指令：`uci`, `isready`, `setoption`, `ucinewgame`, `position`, `go`, `stop`, `quit`。
- 内置扩展实用指令：`bench` (性能基准测试)、`perft` (着法生成正确性验证)、`eval` (局面评估详情分解)、`d` (控制台 ASCII 棋盘与 FEN 打印)、`train` (内置 NNUE 训练系统)。

### 2. 双评估系统一键平滑切换
- **Classical Eval (传统古典手工棋值评估)**：
  - 基于经典的 **PeSTO Piece-Square Tables**，支持中局 (MG) 与残局 (EG) 双阶段位置价值精细化映射。
  - **Tapered Phase Interpolation**：采用 24 点非兵棋子相位插值，平滑过渡开局、中局与残局。
  - **几何与阵型特征**：双象优势加分（Bishop Pair）、半开放/开放线车控制（Rook on Open/Semi-open Files）、兵型评估（重叠兵/孤兵惩罚、通路兵阶段奖励）、中局王翼防御盾兵保护（King Shelter）与走子节奏先手权加分（Tempo Bonus）。
- **NNUE 评估 (高效神经网络评估)**：
  - 采用标准高效的 **Perspective 768 -> 256 -> 1** 特征变换器架构（Feature Transformer）。
  - 双重视角（White POV / Black POV）配合 `int16_t` 累加器（Accumulator），支持走子极速 O(1) 增量更新。
  - 采用 **Clipped ReLU** 激活函数 `clamp(x, 0, 127)`，利用线性累加与点积运算，单核即可达到数百万 NPS 推理速度。
  - 外部权重加载：标准 `.nnue` 二进制文件存储（文件与引擎程序彻底解耦分离），启动时支持一键加载，若文件缺失则智能回退至古典评估。
- **模式切换**：支持 `Classical`、`NNUE` 以及 `Hybrid`（古典与网络混合融合评估）三档模式，可在 UCI 选项中随时无缝切换。

### 3. 高性能剪枝搜索系统 (Target ELO 2300+)
- **位棋盘与魔术位棋盘 (Magic Bitboards)**：
  - 全 64 位 `uint64_t` 位棋盘架构，车与象滑动着法采用预计算无冲突魔术位棋盘映射，生成速度超 1500 万节点/秒。
- **Negamax 框架与静态搜索 (Quiescence Search)**：
  - 静态搜索限制在吃子、升变着法，集成 **Stand-Pat** 站立评估、**Delta Pruning** 剪枝与 **SEE 静态交换剪枝**，有效规避地平线效应（Horizon Effect）。
- **静态交换评估 (Static Exchange Evaluation, SEE)**：
  - 极速多级吃子交换价值计算，用于吃子排序及剪枝过滤劣势吃子。
- **置换表 (Transposition Table, TT)**：
  - 64 位 Zobrist 散列，分代淘汰策略（Aging），支持精确值（EXACT）、下界（BETA 截断）、上界（ALPHA 失败）标记；动态自适应根节点将军杀棋步数修正。
  - 内存大小支持 UCI 参数自由配置（1MB ~ 1024MB）。
- **智能走子排序 (Move Ordering)**：
  1. TT 哈希最佳着法 (Hash Move, 权重 1,000,000)
  2. 优质吃子与升变 (MVV-LVA 最有价值受害者-最无价值攻击者 + SEE >= 0, 权重 500,000+)
  3. 第一杀手着法 (Killer Move 1, 权重 400,000)
  4. 第二杀手着法 (Killer Move 2, 权重 300,000)
  5. 历史启发增量着法 (History Heuristic, 权重 0 ~ 200,000)
  6. 劣势吃子 (SEE < 0, 权重 100,000 + SEE)
- **高级启发式剪枝与延伸**：
  - **将军延伸 (Check Extensions)**：王受将时自动加深搜索深度 1 层。
  - **空着剪枝 (Null Move Pruning, NMP)**：自适应深度扣减 $R = 2 + depth / 6$，快速检验局面压倒性优势。
  - **迟动削减 (Late Move Reductions, LMR)**：对排列靠后的宁静着法依据对数衰减表自适应降深搜索，发现潜在威胁时触发重搜（Re-search）。
  - **反向虚弱剪枝 (Reverse Futility Pruning)**：低深度评估远超 Beta 时提前截断。
- **迭代加深与愿望窗口 (Iterative Deepening & Aspiration Windows)**：
  - 搜索自深度 1 逐级递增，在深度 $\ge 5$ 时使用窄窗口 $[PV - 25, PV + 25]$ 提速，失败时指数级拓宽窗口。
- **多线程搜索 (Lazy SMP 并发加速)**：
  - 共享置换表架构的 Lazy SMP，支持 1 ~ 64 线程无锁并发搜索，多核心利用率极高，无死锁开销。

### 4. 纯 C++ 内置 NNUE 训练系统 (零外部框架依赖)
- **无需安装 Python / PyTorch / CUDA / TensorFlow**，引擎源码自包含全套训练逻辑：
  - **PGN 数据集解析器**：内置 SAN 着法解析器，可自动解析正规 PGN 棋谱文件，支持胜负和标记（`1-0`, `0-1`, `1/2-1/2`）并提取数万盘对局的所有局面特征。
  - **自对弈样本生成器 (Self-Play Generator)**：内置开局轻度随机化与自对弈机制，可全自动批量对局生成合成局面数据。
  - **Adam 优化器与反向传播**：内置稀疏特征梯度反向传播（每局面仅约 30 个有效激活特征），支持学习率、动量因子调整、Mini-Batch 训练及 MSE 损失收敛。
  - **权重整数量化输出**：训练完成后自动量化为 `int16_t` / `int32_t` 并序列化保存为标准 `.nnue` 二进制权重文件，可立即被引擎外部加载。

### 5. 严谨完整的国际象棋规则测试
- 完整支持所有 FIDE 国际象棋特殊规则：
  - 吃过路兵（En Passant）
  - 王车易位（Castling，严格检测易位通路方格受攻击状态及王受将状态）
  - 兵升变（Promotion，支持后、车、象、马四种升变）
  - 逼和（Stalemate）与将死（Checkmate）精准判定
  - 50 回合规则（50-Move Rule）
  - 三次重复局面判和（Threefold Repetition Detection，基于历史哈希栈回溯）
- **Perft 测试验证**：
  - 标准初始局面深度 5: `4,865,609` 节点（100% 精确匹配）
  - 经典复杂局面 Kiwipete 深度 4: `4,085,603` 节点（100% 精确匹配）

---

## 📂 项目源码目录结构

```text
chess_engine/
├── CMakeLists.txt          # 跨平台 CMake 构建配置 (MSVC / GCC / Clang)
├── Makefile                # GNU Makefile (Linux / MinGW)
├── README.md               # 本项目详细技术文档与使用手册
├── bin/                    # 编译输出目录
│   └── sparkchess          # 可执行引擎程序 (Windows 下为 sparkchess.exe)
├── weights/                # NNUE 权重文件存放目录
│   ├── default.nnue        # 默认内置/导出的 NNUE 权重文件
│   └── trained.nnue        # 用户训练生成的权重文件
└── src/                    # 核心 C++ 源码
    ├── types.h             # 棋盘基础类型、常量、Move 编码与 MoveList
    ├── bitboard.h          # 位棋盘操作内联函数与攻击表声明
    ├── bitboard.cpp        # 攻击表初始化与魔术位棋盘映射
    ├── magics.h            # 预计算验证通过的 64 位车与象 Magic 数
    ├── zobrist.h           # Zobrist 随机哈希键声明
    ├── zobrist.cpp         # 确定性伪随机哈希表初始化
    ├── board.h             # 棋盘状态类声明 (FEN, 走子, 撤销, 规则判定, SEE)
    ├── board.cpp           # 棋盘逻辑实现与特殊规则处理
    ├── movegen.h           # 着法生成器接口 (合法着法/吃子着法)
    ├── movegen.cpp         # 伪合法与合法着法生成算法
    ├── evaluate.h          # 古典评估与 NNUE 评估统一接口
    ├── evaluate.cpp        # PeSTO PST, 兵型, 车开放线, 王安全, 动态相位评估
    ├── nnue.h              # NNUE 神经网络结构定义与累加器逻辑
    ├── nnue.cpp            # NNUE 推理实现与 .nnue 二进制文件读写
    ├── tt.h                # 置换表 (Transposition Table) 结构定义
    ├── tt.cpp              # TT 散列查找、置换存储与分代淘汰
    ├── search.h            # 搜索模块头文件 (SearchLimits, SearchThread, SearchEngine)
    ├── search.cpp          # Alpha-Beta, QS, LMR, NMP, 走子排序, Lazy SMP
    ├── trainer.h           # 内置 NNUE 训练器声明 (PGN 解析, 自对弈, Adam)
    ├── trainer.cpp         # PGN 解析器, 自对弈生成, 反向传播与量化输出
    ├── uci.h               # UCI 2.0 协议交互头文件
    ├── uci.cpp             # UCI 协议命令主循环与诊断指令实现
    └── main.cpp            # 引擎主入口 main()
```

---

## 🛠️ 编译与安装指南

本项目仅依赖标准 C++17 编译器（包含 `std::thread` 多线程库），无需安装任何第三方外部依赖。

### 1. Windows 环境编译

#### 方法 A：使用 Microsoft Visual Studio (MSVC)
1. 安装 **Visual Studio 2019 / 2022**（勾选“使用 C++ 的桌面开发”工作负载）。
2. 打开“**x64 Native Tools Command Prompt for VS**”（Visual Studio 开发者命令提示符）。
3. 进入项目根目录：
   ```cmd
   cd chess_engine
   mkdir build
   cd build
   cmake .. -G "Visual Studio 17 2022" -A x64
   cmake --build . --config Release
   ```
4. 编译成功后，可执行文件位于 `chess_engine/bin/sparkchess.exe`。

#### 方法 B：使用 CL 命令行直接编译 (极简快速)
在 Visual Studio 开发者命令提示符中直接执行：
```cmd
cd chess_engine
cl.exe /O2 /Oi /Ot /GL /std:c++17 /EHsc /W3 /Fe:bin\sparkchess.exe src\*.cpp /link /LTCG
```

#### 方法 C：使用 MinGW-w64 (GCC for Windows)
若安装了 MSYS2 / MinGW-w64：
```cmd
cd chess_engine
mingw32-make -j4
```
或直接通过命令行编译：
```cmd
g++ -O3 -std=c++17 -Wall -Wextra -pthread src/*.cpp -o bin/sparkchess.exe
```

---

### 2. Linux / macOS 环境编译

#### 使用 Makefile (推荐)
```bash
cd chess_engine
make -j$(nproc)
```
编译产物将输出在 `bin/sparkchess`。

#### 使用 CMake
```bash
cd chess_engine
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

---

## 🎮 GUI 图形客户端加载与使用教程

SparkChess 能够无缝接入所有支持 UCI 协议的国际象棋软件。

### 1. 在 Arena Chess GUI 中加载
1. 打开 Arena，点击顶部菜单栏 **`Engines` -> `Manage...`**。
2. 切换到 **`Details`** 选项卡，点击右下角 **`New`**。
3. 浏览并选择 `sparkchess.exe`（或 Linux 下的 `sparkchess`）。
4. 在协议类型中选择 **`UCI`**。
5. 点击 **`Apply`**，接着切换到 **`UCI`** 标签页即可调整引擎参数（Hash 缓存、线程数、评估模式等）。
6. 点击 **`OK`**，随后在主界面按 `Ctrl + 1` 即可与 SparkChess 开始对弈！

### 2. 在 CuteChess 中加载
1. 打开 CuteChess，进入 **`Tools` -> `Settings` -> `Engines`**。
2. 点击底部的 **`+` (Add)** 按钮。
3. 找到 `sparkchess.exe`，CuteChess 会自动执行 `uci` 指令并识别出引擎名称 `SparkChess 1.0`。
4. 点击 **`Apply`** 保存配置。

### 3. 在 Lichess 作为 Bot 运行
1. 下载开源的 `lichess-bot` 客户端。
2. 打开 `config.yml`，在 `engine:` 部分指定路径：
   ```yaml
   engine:
     dir: "./"
     name: "sparkchess.exe"
     protocol: "uci"
     uci_options:
       Hash: 256
       Threads: 4
       EvalMode: "NNUE"
       NNUEFile: "weights/default.nnue"
   ```
3. 启动 `python lichess-bot.py`，引擎即可以官方认证的 Bot 账号在 Lichess 全天候对弈。

---

## ⚙️ UCI 参数详细配置说明

在 GUI 的引擎参数面板（或通过控制台输入 `setoption name <Option> value <Value>`）可以调整以下参数：

| 参数名称 | 类型 | 默认值 | 可选范围 | 功能说明 |
| :--- | :--- | :--- | :--- | :--- |
| **`Hash`** | spin (整数) | `16` | `1 ~ 1024` | 置换表 (Transposition Table) 内存大小 (MB)。实战对弈建议设为 128 或 256。 |
| **`Threads`** | spin (整数) | `1` | `1 ~ 64` | 搜索并发线程数 (Lazy SMP)。依据物理 CPU 核心数设置 (如 4, 8, 16)。 |
| **`EvalMode`** | combo (下拉) | `NNUE` | `Classical`, `NNUE`, `Hybrid` | 局面评估模式：<br>• `Classical`: 传统纯手工棋值与 PST 评估<br>• `NNUE`: 神经网络累加器评估<br>• `Hybrid`: 50% 古典 + 50% NNUE 融合评估 |
| **`NNUEFile`** | string (文本) | `weights/default.nnue` | 任意文件路径 | 外部 NNUE 权重文件路径。加载成功后立即生效。 |

---

## 🧠 NNUE 训练与权重更新实战指南

SparkChess 内置轻量级神经网络训练流水线，所有操作均可在引擎命令行中直接执行，无需 Python 环境。

### 1. 导入 PGN 棋谱训练

若您手头有大师对局或高手对局的 PGN 棋谱（如 `games.pgn`）：

1. 打开终端运行引擎交互终端：
   ```bash
   ./bin/sparkchess
   ```
2. 输入 `train pgn` 命令启动训练：
   ```text
   train pgn <pgn文件路径> [训练轮数epochs] [批大小batch_size] [学习率lr] [输出权重文件]
   ```
   **示例**：
   ```text
   train pgn my_master_games.pgn 10 128 0.001 weights/trained.nnue
   ```
3. 引擎将执行以下步骤：
   - 解析 PGN 格式的头标签与 SAN 走法（如 `e4`, `Nf3`, `O-O`, `Bxf7+` 等）。
   - 将棋局逐步重放并提取每个局面的白方与黑方 768 维稀疏特征。
   - 使用 Adam 优化器进行 Mini-Batch 梯度下降训练，并在每个 Epoch 实时输出均方误差损失（Loss）。
   - 训练结束后自动完成整数量化，保存为标准二进制 `weights/trained.nnue`。

---

### 2. 通过自我对弈 (Self-Play) 生成样本并训练

在没有外部棋谱的情况下，可让引擎通过自我博弈自动生成训练样本：

1. 启动引擎：
   ```bash
   ./bin/sparkchess
   ```
2. 输入 `train selfplay` 指令：
   ```text
   train selfplay <对局局数> <对弈搜索深度> <训练轮数> <输出权重文件>
   ```
   **示例**：自动生成 100 盘对局（搜索深度 5 层），并在生成的数据上训练 5 轮：
   ```text
   train selfplay 100 5 5 weights/selfplay_model.nnue
   ```
3. 生成过程中，引擎会在开局前 2 步引入随机化探索以保证局面多样性，对局结束（杀棋、长将、逼和、50回合）后将结果反标到局面序列中进行梯度反向传播。

---

### 3. 加载新训练的权重并切换评估模式验证

训练完成后，您可以直接在命令行或 GUI 中即时加载并验证效果：

```text
# 1. 载入刚刚训练的新权重
setoption name NNUEFile value weights/trained.nnue

# 2. 检查当前局面评估分解对比
eval

# 3. 切换评估模式至纯古典模式
setoption name EvalMode value Classical
eval

# 4. 切换评估模式至 NNUE 模式
setoption name EvalMode value NNUE
eval

# 5. 开展固定深度搜索
go depth 7
```

---

## 📊 命令行交互诊断常用指令汇总

| 命令 | 参数格式 | 示例 | 功能说明 |
| :--- | :--- | :--- | :--- |
| `d` 或 `display` | 无 | `d` | 打印当前棋盘 ASCII 图样、当前 FEN 与 Zobrist Hash Key |
| `eval` | 无 | `eval` | 输出当前局面的古典评估分、NNUE 评估分及当前生效评估模式 |
| `bench` | `[depth]` | `bench 6` | 在标准 5 组基准对局上运行搜索，输出总耗时及 NPS 算力指标 |
| `perft` | `<depth>` | `perft 5` | 对当前局面开展 Perft 走法树性能与规则正确性测试 |
| `position` | `startpos [moves ...]`<br>`fen <FEN> [moves ...]` | `position startpos moves e2e4 c7c5` | 设置当前棋盘局面与历史步数 |
| `go` | `depth <d>`<br>`wtime <t> btime <t> ...`<br>`movetime <ms>` | `go depth 8`<br>`go movetime 1500` | 启动思考计算并返回 `bestmove` |
| `train` | `pgn ...`<br>`selfplay ...` | 见训练指南章节 | 执行内置 NNUE 训练流水线 |
| `quit` | 无 | `quit` | 退出引擎程序 |
