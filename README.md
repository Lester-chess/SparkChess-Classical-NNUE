# SparkChess Engine v2.0 (NNUE v7 Phase-Gated Multi-Subspace Architecture)

A high-performance, UCI-compliant C++17 Chess Engine featuring a full Classical Tapered Evaluation (`evaluate_classical`) and a redesigned **Phase-Gated Multi-Subspace HalfKP + 32 Structural Virtual Features NNUE (`v7`)** with an end-to-end **Quantization-Aware AdamW Trainer**.

---

## Root-Cause Diagnosis: Why NNUE v6 Failed to Converge

An in-depth audit of the original v6 NNUE implementation (`nnue.h`, `nnue.cpp`, `trainer.h`, `trainer.cpp`) uncovered **5 compounding structural bottlenecks** that prevented training from improving evaluation accuracy or convergence speed:

1. **Rank-1 Hidden Layer Symmetry Collapse (`nnue.cpp` & `trainer.cpp`)**
   - In `v6`, hidden neurons `0..15` were initialized as 16 identical copies and **frozen** (`h < 32` skipped in backprop).
   - Neurons `16..31` were 16 identical copies and **frozen**.
   - Neurons `32..63` were initialized identically, shared identical output weights (`ow = ±32`), and `trainer.cpp` explicitly **averaged all 16 positive and 16 negative neurons together** at the start of `train()`.
   - Because every neuron in a group had identical weights and identical output weights, every neuron received the exact same gradient on every batch, collapsing the 64-neuron network into a single linear scalar with zero non-linear capacity.

2. **Feature Extraction vs. Architecture Mismatch (Missing Phase & Structural Terms)**
   - `evaluate_classical()` computes a 24-point Tapered Phase Interpolation (`MG` vs `EG`) using PeSTO Piece-Square Tables plus rich structural evaluators: Bishop Pair, Passed Pawns by rank, Isolated/Doubled/Connected Pawns, Rook on Open/Semi-Open/7th rank, Outposts, King Shelter, and Mobility.
   - `v6` `evaluate_nnue()` only extracted raw `(king_sq, piece, sq)` coordinates, lacked phase gating (causing Middlegame King-shelter gradients and Endgame King-centralization gradients to cancel out!), and omitted the King's own PST whenever pieces were traded off.

3. **Over-Constrained Hand-Clamped "Trust Region" & Frozen Parameters**
   - `get_feature_trust_bounds()` clamped rank-2 pawn weights to `[-0.004, +0.010]` ( less than 1 quantized LSB!) and froze `ft_biases` and `out_weights`.
   - Furthermore, small output weights (`±32`) divided backpropagated gradients by `64`, starving feature weights of gradient signal.

4. **Cross-Neuron Sigma-Delta Error Diffusion & Epoch Rejection**
   - `quantize_error_diffused_in_place()` pushed rounding residuals from neuron `h` into neuron `h+1`, corrupting neighboring neurons and causing validation MSE spikes that triggered aggressive epoch rollbacks and learning-rate halving.

5. **Duplicate PGN Training Corpus (`sim_large.pgn`) & Unshared Sparse Updates**
   - `sim_large.pgn` contained 400 games that were just 2 games repeated 200 times (only 86 unique quiet positions touching `0.4%` of the 40,960 HalfKP features), and `grad_base_weights` used raw unscaled SGD instead of AdamW.

---

## NNUE v7 Architecture Upgrades

| Component | Original NNUE (`v6`) | Upgraded NNUE (`v7`) |
| :--- | :--- | :--- |
| **Input Feature Space** | `40,960` HalfKP only (`64 × 10 × 64`) | `40,992` (`40,960` HalfKP + `32` Embedded Structural Virtual Features) |
| **32 Structural Features** | None (blind to pawn structure & open files) | King Endgame PST, Bishop Pair, Passed Pawns (Ranks 2-7), Isolated/Doubled/Connected Pawns, Rook Open/Semi-Open/7th Rank, Knight/Bishop Outposts, King Pawn Shield & Threats |
| **Hidden Layer (`L1 = 64`)** | 32 frozen clones + 32 averaged clones (Rank-1 collapse) | **5 Orthogonal Phase-Gated Subspaces** (`MG PeSTO`, `EG PeSTO`, `Structural/Mobility`, `Tactical/King Safety`, `Residual Non-Linear`) |
| **Phase Gating** | None (static linear output sum) | **24-Point Tapered Phase Gating** (`phase / 24.0` for MG neurons `0..15`, `(24 - phase) / 24.0` for EG neurons `16..31`) |
| **Activation Function** | Clipped ReLU with dead-neuron zero gradient | Clipped ReLU `[0, 127]` with **Leaky Straight-Through Estimator (STE, `0.05` slope)** in backprop |
| **Optimizer** | Partial Adam + unscaled SGD + hard clamps | **Full-Network Cosine-Annealed AdamW** across all 64 neurons, `base_weights`, `structural_weights`, `ft_biases`, `out_weights`, and `out_bias` |
| **Hierarchical Tying** | Single `alpha = 0.002` SGD nudge | **Multi-Scale Base `(piece, sq)` + King-Zone HalfKP Hierarchy** with zero-sum orthogonal pair projection |

---

## Building and Running

```bash
cd chess_engine
make
./bin/sparkchess
```

### Custom UCI & Diagnostic Commands
- `eval`: Prints detailed Classical, NNUE v7 (with 5-subspace centipawn breakdown), and Hybrid evaluation.
- `eval_json`: Emits single-line JSON containing `classical_cp`, `nnue_cp`, `hybrid_cp`, `phase`, 5-subspace contributions, active structural feature indices, and all 64 White/Black hidden neuron activations.
- `train pgn <file> <epochs> <batch_size> <out_file>`: Deduplicates PGN positions and runs Cosine-Annealed AdamW training with live telemetry.
- `train selfplay <games> <depth> <epochs> <out_file>`: Generates diverse opening-book self-play trajectories and trains NNUE v7 weights.
