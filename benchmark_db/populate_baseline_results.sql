-- Baseline Results from GuacaMol Paper (Brown et al. 2019)
-- Table 2: Results of the baseline models for the goal-directed benchmarks
-- Source: GuacaMol paper, page 13

-- Celecoxib rediscovery
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'), 'Best from Dataset', 0.505, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'), 'SMILES GA', 0.732, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'), 'Graph MCTS', 0.355, 'GuacaMol Table 2');

-- Troglitazone rediscovery
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'), 'Best from Dataset', 0.419, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'), 'SMILES GA', 0.515, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'), 'Graph MCTS', 0.311, 'GuacaMol Table 2');

-- Thiothixene rediscovery
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'), 'Best from Dataset', 0.456, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'), 'SMILES GA', 0.598, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'), 'Graph MCTS', 0.311, 'GuacaMol Table 2');

-- Aripiprazole similarity
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'), 'Best from Dataset', 0.595, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'), 'SMILES GA', 0.834, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'), 'Graph MCTS', 0.380, 'GuacaMol Table 2');

-- Albuterol similarity
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'), 'Best from Dataset', 0.719, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'), 'SMILES GA', 0.907, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'), 'Graph MCTS', 0.749, 'GuacaMol Table 2');

-- Mestranol similarity
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'), 'Best from Dataset', 0.629, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'), 'SMILES LSTM', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'), 'SMILES GA', 0.790, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'), 'Graph MCTS', 0.402, 'GuacaMol Table 2');

-- C11H24
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'), 'Best from Dataset', 0.684, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'), 'SMILES LSTM', 0.993, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'), 'SMILES GA', 0.829, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'), 'Graph GA', 0.971, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'), 'Graph MCTS', 0.410, 'GuacaMol Table 2');

-- C9H10N2O2PF2Cl
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'), 'Best from Dataset', 0.747, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'), 'SMILES LSTM', 0.879, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'), 'SMILES GA', 0.889, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'), 'Graph GA', 0.982, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'), 'Graph MCTS', 0.631, 'GuacaMol Table 2');

-- Median molecules 1
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'), 'Best from Dataset', 0.334, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'), 'SMILES LSTM', 0.438, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'), 'SMILES GA', 0.334, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'), 'Graph GA', 0.406, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'), 'Graph MCTS', 0.225, 'GuacaMol Table 2');

-- Median molecules 2
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'), 'Best from Dataset', 0.351, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'), 'SMILES LSTM', 0.422, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'), 'SMILES GA', 0.380, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'), 'Graph GA', 0.432, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'), 'Graph MCTS', 0.170, 'GuacaMol Table 2');

-- Osimertinib MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'), 'Best from Dataset', 0.839, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'), 'SMILES LSTM', 0.907, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'), 'SMILES GA', 0.886, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'), 'Graph GA', 0.953, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'), 'Graph MCTS', 0.784, 'GuacaMol Table 2');

-- Fexofenadine MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'), 'Best from Dataset', 0.817, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'), 'SMILES LSTM', 0.959, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'), 'SMILES GA', 0.931, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'), 'Graph GA', 0.998, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'), 'Graph MCTS', 0.695, 'GuacaMol Table 2');

-- Ranolazine MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'), 'Best from Dataset', 0.792, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'), 'SMILES LSTM', 0.855, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'), 'SMILES GA', 0.881, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'), 'Graph GA', 0.920, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'), 'Graph MCTS', 0.616, 'GuacaMol Table 2');

-- Perindopril MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'), 'Best from Dataset', 0.575, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'), 'SMILES LSTM', 0.808, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'), 'SMILES GA', 0.661, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'), 'Graph GA', 0.792, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'), 'Graph MCTS', 0.385, 'GuacaMol Table 2');

-- Amlodipine MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'), 'Best from Dataset', 0.696, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'), 'SMILES LSTM', 0.894, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'), 'SMILES GA', 0.722, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'), 'Graph GA', 0.894, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'), 'Graph MCTS', 0.533, 'GuacaMol Table 2');

-- Sitagliptin MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'), 'Best from Dataset', 0.509, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'), 'SMILES LSTM', 0.545, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'), 'SMILES GA', 0.689, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'), 'Graph GA', 0.891, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'), 'Graph MCTS', 0.458, 'GuacaMol Table 2');

-- Zaleplon MPO
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'), 'Best from Dataset', 0.547, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'), 'SMILES LSTM', 0.669, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'), 'SMILES GA', 0.413, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'), 'Graph GA', 0.754, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'), 'Graph MCTS', 0.488, 'GuacaMol Table 2');

-- Valsartan SMARTS
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'), 'Best from Dataset', 0.259, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'), 'SMILES LSTM', 0.978, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'), 'SMILES GA', 0.552, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'), 'Graph GA', 0.990, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'), 'Graph MCTS', 0.040, 'GuacaMol Table 2');

-- Deco Hop
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'), 'Best from Dataset', 0.933, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'), 'SMILES LSTM', 0.996, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'), 'SMILES GA', 0.970, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'), 'Graph MCTS', 0.590, 'GuacaMol Table 2');

-- Scaffold Hop
INSERT INTO baseline_results (benchmark_id, model_name, score, notes)
VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'), 'Best from Dataset', 0.738, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'), 'SMILES LSTM', 0.998, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'), 'SMILES GA', 0.885, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'), 'Graph GA', 1.000, 'GuacaMol Table 2'),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'), 'Graph MCTS', 0.478, 'GuacaMol Table 2');
