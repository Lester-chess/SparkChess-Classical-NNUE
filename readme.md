# SparkChess 1.4.0 Hotfix1 Build & Tuning Manual

SparkChess is a high-performance chess engine compliant with the Universal Chess Interface (UCI) protocol, featuring an evaluation module that supports both offline Texel evaluation optimization and online SPSA search parameter tuning.

---

## 1. System Requirements & Installation

### 1.1 Requirements
- **Linux** (Ubuntu 20.04+ recommended) or **Windows** (10/11 x86_64)
- **Compiler**: GCC / G++ (v9.0+ supporting C++17) or MSVC
- **Dependencies**: OpenMP (for multi-threaded tuning)
- **Compatibility Layer (Optional)**: Wine (required only if running Windows `.exe` on Linux instances)

### 1.2 Compilation from Source

#### On Linux (Native / AutoDL / VPS)
```bash
# Clone the repository
git clone https://github.com/your-repo/sparkchess.git
cd sparkchess

# Build using G++ with optimization flags
g++ -O3 -std=c++17 -fopenmp -march=native src/*.cpp -o bin/sparkchess

# Grant executable permissions
chmod +x bin/sparkchess
```

#### On Windows
- :Use the internal Bat to build the exe version 




---

## 2. Basic UCI Usage

SparkChess conforms to the standard UCI protocol. Launch the executable from a terminal or connect it to any chess GUI (Arena, Cutechess, Bankia, Fritz).

### 2.1 Interactive Terminal Mode
Start the engine directly:
```bash
./sparkchess
```

Common UCI commands:
```text
uci                       # Initialize engine and print engine parameters
isready                   # Check if engine is ready (replies 'readyok')
setoption name Threads value 8
setoption name Hash value 256
position startpos moves e2e4 e7e5
go depth 15               # Search to depth 15
go wtime 300000 btime 300000 winc 2000 binc 2000  # Timed search
quit                      # Terminate the engine
```

---

## 3. Texel Tuning (Evaluation Tuning)

Texel Tuning optimizes handcrafted evaluation function parameters (e.g., Piece Values, Piece-Square Tables, Pawn Structure bonuses) against game outcomes ($R \in \{0.0, 0.5, 1.0\}$) by minimizing the Mean Squared Error:

$$\text{Loss} = \frac{1}{N} \sum_{i=1}^{N} \left( R_i - \sigma(K \cdot E_i) \right)^2$$

### 3.1 Command Syntax
```text
tune texel <dataset.pgn> <epochs> <learning_rate> <output_weights.bin> <start_from_checkpoint>
```

### 3.2 Parameter Descriptions
- `<dataset.pgn>`: Path to a collection of quiet, decisive games (e.g., `long_decided_games.pgn`).
- `<epochs>`: Number of iterations over the full dataset (typical: `20`–`50`; `100` for vast datasets).
- `<learning_rate>`: Step size for gradient updates (e.g., `0.004` or `0.001` depending on the optimizer).
- `<output_weights.bin>`: Path to save the optimized evaluation weights.
- `<start_from_checkpoint>`: `0` to initialize from current defaults; `1` to resume from the target binary file.

### 3.3 Execution Example
```text
tune texel long_decided_games.bare.[21951].pgn 10 0.002 HCE1.bin 0
```

### 3.4 Operational Notes
- **Loading Latency**: Parsing large PGN files (e.g., 20,000+ games) may take several minutes before `Epoch 1/10` appears.
- **CPU Utilization**: Ensure multi-threading is enabled so that feature extraction scales across all available cores.

---

## 4. SPSA Tuning (Search & Tactical Tuning)

Simultaneous Perturbation Stochastic Approximation (SPSA) tunes continuous search heuristics (e.g., Late Move Reductions, Futility Pruning margins, Null Move parameters) by playing self-play games under tight time controls.

### 4.1 Prerequisites
- **Cutechess-CLI** or **Fastchess** installed.
- A standardized opening book (e.g., `8moves_v3.pgn` or `UHO_XXL_2022.epd`).
- SPSA harness script (Python or shell wrapper).

### 4.2 SPSA Configuration Workflow

1. **Expose Parameters via UCI Options**:
   Ensure search parameters are exposed in `sparkchess` via UCI:
   ```text
   option name LMR_Base type spin default 75 min 40 max 120
   option name NMP_DepthReduction type spin default 3 min 1 max 6
   ```

2. **Define SPSA Hyperparameters**:
   - Number of iterations ($N$): `5000`–`20000` games.
   - Perturbation factor ($c$): Step width for gradient estimation.
   - Learning rate decay ($a, A, \alpha$).

3. **Running the Cutechess Match Loop**:
   ```bash
   python3 spsa_tune.py \
       --engine "./bin/sparkchess" \
       --book "books/8moves_v3.pgn" \
       --games 10000 \
       --threads 10 \
       --tc "10+0.1" \
       --spsa-config "spsa_params.json"
   ```

---

## 5. Validation & Elo Testing (SPRT)

Once Texel or SPSA tuning is complete, validate that the updated weights produce a measurable Elo increase using Sequential Probability Ratio Testing (SPRT):

```bash
cutechess-cli \
  -engine name=SparkChess_Tuned cmd=./sparkchess-tuned \
  -engine name=SparkChess_Base  cmd=./sparkchess-base \
  -each proto=uci tc=10+0.1 \
  -rounds 2000 \
  -repeat \
  -openings file=openings.pgn format=pgn order=random \
  -sprt elo0=0 elo1=5 alpha=0.05 beta=0.05 \
  -concurrency 10
```
