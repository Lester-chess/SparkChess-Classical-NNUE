# SparkChess 1.4 UCI 国际象棋引擎 (C++17/20 — 战术精算与 Syzygy 动态库版)

SparkChess 是一款基于现代 C++17/20 开发的高性能 UCI (Universal Chess Interface 2.0) 国际象棋引擎，专为跨平台（Windows / Linux / macOS）设计。

在 **v1.4** 版本中，引擎针对**中残局均势防漏招**、**优势转化为胜势**以及**外部动态链接库加载 Syzygy 残局库（.rtbw / .rtbz）**进行了全面重构升级。

---

## 🚀 v1.4 核心升级亮点

### 1. 搜索引擎精度与防漏招体系升级 (`src/search.cpp`, `src/board.cpp`, `src/movegen.cpp`)
- **静态搜索地平线将军探测 (`GEN_QUIET_CHECKS`)**：
  - 在 `qsearch` 首层（`qply == 0`）新增安静将军着法生成与探测（结合 `SEE >= 0` 安全过滤），彻底解决叶节点对马抽将、底线闷杀、车象闪将等 1~2 步战术组合失明的问题。
- **静态交换评估 (`Board::see`) X-Ray 透视与牵制修正**：
  - 修复吃过路兵（En Passant）时未从阻挡位棋盘 `occ` 移除被吃兵方格导致斜线/直线 X-Ray 透视失效的 Bug。
  - 引入双王绝对牵制检测（`blockers_for_king`），在 `see()` 交换序列中过滤掉被绝对牵制且偏离射线方向的防守子，杜绝因误判“伪保护”而剪枝掉胜势吃子。
  - 修正次底线吃子升变在交换序列中的真实分值增益。
- **精准 Delta Pruning 与残局保护**：
  - 废除原先固定 `+950 cp` 的粗糙 Delta 剪枝阈值，改为按实际被吃子价值动态计算（`stand_pat + cap_val + 220 < alpha`），并在少子残局阶段自动禁用 Delta 剪枝，防止漏算王护送通路兵等大幅度位置分跃迁。
- **空着剪枝 (NMP) 防逼和 / 防 Zugzwang 护栏**：
  - 要求非兵子力总值 `> 500 cp`（即至少拥有双轻子或车+轻子以上）才允许触发空着剪枝，彻底消除单车兵、马兵、象兵残局中的等死着（Zugzwang）漏招。
- **LMR (后着缩减) 改良与 7 线通路兵延伸**：
  - 引入 `improving` 局势改善趋势栈（对比 `ply` 与 `ply - 2` 的静态评估）。
  - 严禁对**通路兵推进**（`is_passed_pawn_push`）实施激进 LMR 缩减或浅层虚着剪枝；当主变（PV）中通路兵推进至第 7 横线（`rel_r == 6`）时自动触发 +1 层延伸。
- **优势局面动态防和棋 (Dynamic Draw Contempt)**：
  - 当根节点评估处于明显优势（`>= +140 cp`）时，自动对搜索树内的重复局面与 50 回合和棋施加动态惩罚（`-15 ~ -45 cp`），杜绝优势下走出三次重复或容忍对手长将逼和。

### 2. Classical 古典评估中残局战术与优势转化增强 (`src/evaluate.cpp`)
- **绝对牵制 (`blockers_for_king`) 与捉双 (`Fork`) 实时评估**：
  - 实时识别被敌方车/象/后牵制在己方王前的马、象、车、后并给予阶段惩罚；检测兵捉双与安全格马捉双威胁。
- **受困子 (`Trapped Pieces`) 与坏象 (`Bad Bishop`) 惩罚**：
  - 识别边角无安全去向的受困马、被未易位王封锁在底线的受困车，以及受己方同色格中心兵群阻塞的坏象。
- **王翼兵风暴 (`Pawn Storm`) 与安全将军格 (`Safe Checks`)**：
  - 新增敌方兵群向王翼推进的风暴惩罚，并统计敌方后/车/轻子在王圈内的安全将军格，提升中局攻王敏锐度。
- **异色格象残局 (`Opposite-Colored Bishops`) 防盲目兑子缩放**：
  - 自动识别纯异色格象残局（缩放至 `40% ~ 58%`）与车+异色格象残局（缩放至 `78%`），防止优势方把进攻子力盲目兑光走成理论死和的异色格象残局。
- **50 回合衰减 (`50-Move Decay`)**：
  - 当 `halfmove_clock > 50` 时平滑缩放评估分值，倒逼优势方主动推兵或吃子破局，不再无效倒子。

### 3. 基于动态链接库 (`.dll` / `.so` / `.dylib`) 的 Syzygy 残局库系统 (`src/syzygy.cpp`, `src/syzygy_dll/`)
- **运行时外部动态加载架构**：
  - Windows 下使用 `LoadLibraryA` / `GetProcAddress`，Linux/macOS 下使用 `dlopen` / `dlsym`，与主引擎完全解耦。
  - 同时兼容内置编译生成的 `bin/syzygy.dll` (`bin/libsyzygy.so`) 以及任何第三方标准 Fathom 编译的动态链接库。
- **完整的 UCI 残局库选项**：
  - `SyzygyPath`：`.rtbw` / `.rtbz` 残局库目录路径（Windows 用 `;` 分隔，Linux/macOS 用 `:` 分隔）。
  - `SyzygyLibPath`：外部动态链接库路径（默认 `auto`，自动检索 `bin/syzygy.dll`、`syzygy.dll`、`bin/libsyzygy.so` 等）。
  - `SyzygyProbeDepth`：搜索树内探测最小深度（默认 `1`）。
  - `Syzygy50MoveRule`：是否启用 50 回合规则判定 `Cursed Win` / `Blessed Loss`（默认 `true`）。
  - `SyzygyProbeLimit`：最大探测棋子数（默认 `7`，范围 `0 ~ 7`）。
- **根节点完美过滤 + 搜索树内 WDL 裁剪**：
  - 根节点通过 `Syzygy::probe_root` 直接锁定最优胜/和层级走法；搜索树内通过 `Syzygy::probe_wdl` 精确返回胜负和并写入置换表，同时在 UCI 输出中实时汇报 `tbhits`。

---

## 🛠️ 一键编译指南

### Windows (Visual Studio MSVC)
双击运行根目录下的 `build_windows.bat`，脚本将自动：
1. 编译生成 `bin\syzygy.dll` 动态链接库；
2. 编译生成 `bin\sparkchess.exe` 主引擎程序；
3. 自动拷贝开局库 `book.bin` 与 NNUE 权重并运行 `bench 5` 验证。

### Linux / macOS (GNU Make)
```bash
make clean && make
```
将同时生成 `bin/libsyzygy.so` 与 `bin/sparkchess`。

### 跨平台 CMake
```bash
mkdir build && cd build
cmake ..
cmake --build . --config Release
```
