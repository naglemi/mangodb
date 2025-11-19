# Benchmark Database Summary

## Paper 1: Sample Efficiency Matters (NeurIPS 2022)

### Table 2: Top 10 Molecular Optimization Methods (AUC Top-10)

Methods ranked by performance across 23 tasks with 10K oracle query budget:

| Rank | Method | Assembly Strategy | Total Score |
|------|--------|------------------|-------------|
| 1 | REINVENT | SMILES | 14.196 |
| 2 | Graph GA | Fragments | 13.751 |
| 3 | REINVENT | SELFIES | 13.471 |
| 4 | GP BO | Fragments | 13.156 |
| 5 | STONED | SELFIES | 13.024 |
| 6 | LSTM HC | SMILES | 12.223 |
| 7 | SMILES GA | SMILES | 12.054 |
| 8 | SynNet | Synthesis | 11.498 |
| 9 | DoG-Gen | Synthesis | 11.456 |
| 10 | DST | Fragments | 10.989 |

### PMO Benchmark Tasks (23 total)

**Similarity-based tasks:**
- albuterol_similarity
- mestranol_similarity
- celecoxib_rediscovery
- thiothixene_rediscovery
- troglitazone_rediscovery

**Multi-Property Optimization (MPO) tasks:**
- amlodipine_mpo
- fexofenadine_mpo
- osimertinib_mpo
- perindopril_mpo
- ranolazine_mpo
- sitagliptin_mpo
- zaleplon_mpo

**Isomer tasks:**
- isomers_c7h8n2o2
- isomers_c9h10n2o2pf2cl

**Bioactivity prediction tasks:**
- drd2 (DRD2 receptor)
- gsk3b (GSK3β kinase)
- jnk3 (JNK3 kinase)

**Other tasks:**
- qed (Quantitative Estimate of Drug-likeness)
- median1
- median2
- deco_hop (Decoration hop)
- scaffold_hop
- valsartan_smarts

### Key Metrics
- **Oracle Budget**: 10,000 queries
- **Evaluation Metric**: AUC Top-10 (area under curve of top-10 average vs oracle calls)
- **Number of Methods Benchmarked**: 25
- **Number of Independent Runs**: 5 per method per task

### Algorithm Categories
1. **Genetic Algorithm (GA)**: SMILES-GA, Graph-GA, STONED, SynNet
2. **Monte-Carlo Tree Search (MCTS)**: Graph-MCTS
3. **Bayesian Optimization (BO)**: BOSS, GP BO, ChemBO
4. **VAE**: SMILES-VAE, SELFIES-VAE, JT-VAE, DoG-AE
5. **Hill Climbing (HC)**: SMILES-LSTM-HC, SELFIES-LSTM-HC, MIMOSA, DoG-Gen
6. **Reinforcement Learning (RL)**: REINVENT, SELFIES-REINVENT, MolDQN
7. **Score-based Modeling (SBM)**: MARS, GFlowNet
8. **Gradient Ascent (GRAD)**: Pasithea, DST
9. **Screening**: Random screening, MolPAL (model-based)

---

## Paper 2: GraphXForm (Digital Discovery 2025)

### Table 1: GuacaMol Benchmark Performance

Performance on 4 representative goal-directed tasks:

| Method | Ranolazine MPO | Perindopril MPO | Sitagliptin MPO | Scaffold Hop |
|--------|----------------|-----------------|-----------------|--------------|
| Graph GA | 0.920 | 0.792 | 0.891 | **1.000** |
| REINVENT-Transformer | 0.934 | 0.679 | 0.735 | 0.582 |
| **GraphXForm** | **0.944** | **0.835** | **0.965** | **1.000** |

### GraphXForm Total GuacaMol Performance
- **Total Score**: 18.227 (across all 20 GuacaMol tasks)
- **Graph GA Score**: 17.983
- **Key Innovation**: Graph transformer operating directly on molecular graphs

### Solvent Design Tasks

GraphXForm was also evaluated on two novel solvent design tasks:

**Task 1: IBA (Isobutanol) Extraction**
- Objective: Design solvents for separating isobutanol from water
- Metric: Partition coefficient P∞_IBA with miscibility gap constraint
- Best GraphXForm result: 8.87

**Task 2: TMB/DMBA Separation**
- Objective: Design solvents for enzymatic reaction product extraction
- Educt: 3,5-dimethoxy-benzaldehyde (DMBA)
- Product: (R)-3,3',5,5'-tetra-methoxy-benzoin (TMB)
- Metric: Ratio P∞_TMB/P∞_DMBA
- Best GraphXForm result: 8.65

### Comparison Methods
1. **Graph GA** (Jensen, 2019)
2. **REINVENT-Transformer** (Xu et al., 2024)
3. **STONED** (Nigam et al., 2021)
4. **JT-VAE** (Jin et al., 2018)

---

## Additional Benchmarks Identified

### From Sample Efficiency Paper:
1. **GuacaMol** (Brown et al., 2019) - 20 goal-directed tasks
2. **Therapeutic Data Commons (TDC)** - Source of oracle functions
3. **ZINC 250K** - Training/screening database

### From GraphXForm Paper:
1. **GuacaMol** - 20 goal-directed tasks (same as above)
2. **COSMObase 2020** - 6,098 compounds for solvent screening
3. **ChEMBL database** - ~1.5M molecules for pretraining
4. **QM9 dataset** - ~128K molecules for JT-VAE training

### Property Prediction Models Used:
- **Activity Coefficients**: GH-GNN (Gibbs-Helmholtz Graph Neural Network)
- **COSMO-RS**: For thermodynamic property prediction
- **UNIFAC**: Activity coefficient prediction

---

## Key Findings

### Sample Efficiency Matters:
1. Older methods (REINVENT, Graph GA) still outperform newer ones
2. Most methods fail to optimize within realistic oracle budgets (<10K queries)
3. SELFIES shows no clear advantage over SMILES for optimization
4. Model-based methods can be more efficient but require careful design
5. Different algorithm types excel at different oracle landscapes

### GraphXForm:
1. Graph-based approach ensures chemical validity by construction
2. Decoder-only transformer architecture enables long-range dependencies
3. Hybrid training (deep CEM + self-improvement learning) enables stable fine-tuning
4. Can flexibly enforce structural constraints during generation
5. Can start design from existing molecular structures
6. Outperforms baselines on both drug design and solvent design tasks

---

## Recommended Benchmark Tasks for benchmark_db

### High Priority (Well-Established):
1. GuacaMol goal-directed tasks (20 tasks)
2. DRD2, GSK3β, JNK3 bioactivity
3. QED optimization
4. Similarity-based rediscovery tasks

### Medium Priority (Emerging):
1. Solvent design for liquid-liquid extraction
2. Multi-property optimization (MPO) tasks
3. Scaffold hopping
4. Isomer identification

### Evaluation Metrics to Include:
1. AUC Top-K (sample efficiency)
2. Best molecule found
3. Top-K average
4. Validity rate
5. Diversity metrics
6. Number of oracle calls

---

## Data Files Downloaded
- `papers/sample_efficiency_matters.pdf` (9.7 MB)
- `papers/graphxform.pdf` (3.2 MB)
