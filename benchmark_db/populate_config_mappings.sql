-- Populate config mappings for all GuacaMol benchmarks
-- Maps Table 3 definitions to our exact config format

BEGIN TRANSACTION;

-- ============================================================================
-- Fexofenadine MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'fexofenadine_ap',
    config_alias = 'fexofenadine_sim_ap',
    config_direction = 'maximize',
    config_notes = 'Table 3 uses Thresholded(0.8); our configs incorrectly use clipped modifier instead. Should use: modifier=thresholded, modifier_params={threshold: 0.8}'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'tpsa',
    config_alias = 'tpsa_over_90',
    config_direction = 'maximize',
    config_notes = 'Table 3 specifies sigma=2 but some configs use sigma=10 (incorrect)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'logp',
    config_alias = 'logp_under_4',
    config_direction = 'minimize',
    config_notes = 'Table 3 specifies sigma=2 but some configs use sigma=1 (incorrect)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO')
AND objective_order = 3;

-- ============================================================================
-- Osimertinib MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'osimertinib_fcfp4',
    config_alias = 'osimertinib_sim_fcfp4',
    config_direction = 'maximize',
    config_notes = 'Use clipped modifier with upper_x=0.8 (equivalent to Thresholded)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'osimertinib_ecfp6',
    config_alias = 'not_too_similar_ecfp6',
    config_direction = 'minimize',
    config_notes = 'MinGaussian(0.85, 2) means "prefer dissimilarity <0.85". Use direction=minimize'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'tpsa',
    config_alias = 'tpsa_over_100',
    config_direction = 'maximize',
    config_notes = NULL
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO')
AND objective_order = 3;

UPDATE scoring_functions
SET
    config_name = 'logp',
    config_alias = 'logp_scoring',
    config_direction = 'minimize',
    config_notes = 'MinGaussian(1, 2) means prefer logP ≤ 1'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO')
AND objective_order = 4;

-- ============================================================================
-- Ranolazine MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'ranolazine_ap',
    config_alias = 'ranolazine_sim_ap',
    config_direction = 'maximize',
    config_notes = 'Thresholded(0.7)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'logp',
    config_alias = 'logp_under_7',
    config_direction = 'minimize',
    config_notes = 'MaxGaussian(7, 1) means prefer logP ≤ 7 (despite name "max")'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'tpsa',
    config_alias = 'tpsa_under_95',
    config_direction = 'maximize',
    config_notes = 'MaxGaussian(95, 20) with large sigma=20'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO')
AND objective_order = 3;

UPDATE scoring_functions
SET
    config_name = 'num_fluorine',
    config_alias = 'fluorine_count',
    config_direction = 'maximize',
    config_notes = 'Gaussian(1, 1) targets exactly 1 fluorine atom'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO')
AND objective_order = 4;

-- ============================================================================
-- Perindopril MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'perindopril_ecfp4',
    config_alias = 'perindopril_sim_ecfp4',
    config_direction = 'maximize',
    config_notes = 'No modifier (modifier=none)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'num_aromatic_rings',
    config_alias = 'aromatic_ring_count',
    config_direction = 'maximize',
    config_notes = 'Gaussian(2, 0.5) targets exactly 2 aromatic rings'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO')
AND objective_order = 2;

-- ============================================================================
-- Amlodipine MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'amlodipine_ecfp4',
    config_alias = 'amlodipine_sim_ecfp4',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'num_rings',
    config_alias = 'total_ring_count',
    config_direction = 'maximize',
    config_notes = 'Gaussian(3, 0.5) targets exactly 3 total rings'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO')
AND objective_order = 2;

-- ============================================================================
-- Sitagliptin MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'sitagliptin_ecfp4',
    config_alias = 'sitagliptin_dissimilarity',
    config_direction = 'minimize',
    config_notes = 'INVERTED! Gaussian(0, 0.1) means maximize DISSIMILARITY. Use direction=minimize to penalize high similarity'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'logp',
    config_alias = 'logp_target_2',
    config_direction = 'maximize',
    config_notes = 'Gaussian(2.0165, 0.2) targets exact value'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'tpsa',
    config_alias = 'tpsa_target_77',
    config_direction = 'maximize',
    config_notes = 'Gaussian(77.04, 5) targets exact value'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO')
AND objective_order = 3;

UPDATE scoring_functions
SET
    config_name = 'isomer_C16H15F6N5O',
    config_alias = 'sitagliptin_formula',
    config_direction = 'maximize',
    config_notes = 'Exact formula match: C16H15F6N5O'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO')
AND objective_order = 4;

-- ============================================================================
-- Zaleplon MPO
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'zaleplon_ecfp4',
    config_alias = 'zaleplon_sim_ecfp4',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'isomer_C19H17N3O2',
    config_alias = 'zaleplon_formula',
    config_direction = 'maximize',
    config_notes = 'Exact formula match: C19H17N3O2 (but NOT same structure as zaleplon)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO')
AND objective_order = 2;

-- ============================================================================
-- Median Molecules 1 (camphor-menthol)
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'camphor_ecfp4',
    config_alias = 'camphor_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'menthol_ecfp4',
    config_alias = 'menthol_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1')
AND objective_order = 2;

-- ============================================================================
-- Median Molecules 2 (tadalafil-sildenafil)
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'tadalafil_ecfp6',
    config_alias = 'tadalafil_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'sildenafil_ecfp6',
    config_alias = 'sildenafil_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2')
AND objective_order = 2;

-- ============================================================================
-- Rediscovery Benchmarks (single objective, simple mapping)
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'celecoxib_ecfp4',
    config_alias = 'celecoxib_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier - pure similarity rediscovery'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'troglitazone_ecfp4',
    config_alias = 'troglitazone_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'thiothixene_ecfp4',
    config_alias = 'thiothixene_similarity',
    config_direction = 'maximize',
    config_notes = 'No modifier'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery')
AND objective_order = 1;

-- ============================================================================
-- Similarity Benchmarks
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'aripiprazole_ecfp4',
    config_alias = 'aripiprazole_similarity',
    config_direction = 'maximize',
    config_notes = 'Thresholded(0.75)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'albuterol_fcfp4',
    config_alias = 'albuterol_similarity',
    config_direction = 'maximize',
    config_notes = 'Thresholded(0.75)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'mestranol_ap',
    config_alias = 'mestranol_similarity',
    config_direction = 'maximize',
    config_notes = 'Thresholded(0.75)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity')
AND objective_order = 1;

-- ============================================================================
-- Isomer Benchmarks
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'isomer_C11H24',
    config_alias = 'undecane_isomers',
    config_direction = 'maximize',
    config_notes = '159 possible isomers - special top-159 scoring'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'isomer_C9H10N2O2PF2Cl',
    config_alias = 'complex_isomers',
    config_direction = 'maximize',
    config_notes = 'Special top-250 scoring'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl')
AND objective_order = 1;

-- ============================================================================
-- SMARTS and Hop Benchmarks (complex - needs custom implementation)
-- ============================================================================

UPDATE scoring_functions
SET
    config_name = 'valsartan_smarts',
    config_alias = 'valsartan_tetrazole_pattern',
    config_direction = 'maximize',
    config_notes = 'SMARTS pattern s1 (see smarts_abbreviations table). Requires custom SMARTS matcher'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'logp',
    config_alias = 'logp_target_2',
    config_direction = 'maximize',
    config_notes = 'Gaussian(2.0165, 0.2) - same as Sitagliptin'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'tpsa',
    config_alias = 'tpsa_target_77',
    config_direction = 'maximize',
    config_notes = 'Gaussian(77.04, 5) - same as Sitagliptin'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS')
AND objective_order = 3;

UPDATE scoring_functions
SET
    config_name = 'bertz_complexity',
    config_alias = 'bertz_target_896',
    config_direction = 'maximize',
    config_notes = 'Gaussian(896.38, 30) targets specific complexity'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS')
AND objective_order = 4;

-- Deco Hop objectives
UPDATE scoring_functions
SET
    config_name = 'smarts_s2_required',
    config_alias = 'pyrimidine_core_present',
    config_direction = 'maximize',
    config_notes = 'SMARTS s2 must be present. Requires custom implementation'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'smarts_s3_forbidden',
    config_alias = 'thiazole_absent',
    config_direction = 'maximize',
    config_notes = 'SMARTS s3 must be absent'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'smarts_s4_forbidden',
    config_alias = 'methylsulfonyl_absent',
    config_direction = 'maximize',
    config_notes = 'SMARTS s4 must be absent'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop')
AND objective_order = 3;

UPDATE scoring_functions
SET
    config_name = 'erlotinib_phco',
    config_alias = 'erlotinib_scaffold_similarity',
    config_direction = 'maximize',
    config_notes = 'PHCO fingerprint similarity to s5. Thresholded(0.85)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop')
AND objective_order = 4;

-- Scaffold Hop objectives
UPDATE scoring_functions
SET
    config_name = 'smarts_s2_forbidden',
    config_alias = 'pyrimidine_absent',
    config_direction = 'maximize',
    config_notes = 'SMARTS s2 must be absent (opposite of Deco Hop)'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop')
AND objective_order = 1;

UPDATE scoring_functions
SET
    config_name = 'smarts_s6_required',
    config_alias = 'ether_chain_present',
    config_direction = 'maximize',
    config_notes = 'SMARTS s6 must be present'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop')
AND objective_order = 2;

UPDATE scoring_functions
SET
    config_name = 'erlotinib_phco',
    config_alias = 'erlotinib_similarity',
    config_direction = 'maximize',
    config_notes = 'PHCO fingerprint to s5. Thresholded(0.75) - lower threshold than Deco Hop'
WHERE benchmark_id = (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop')
AND objective_order = 3;

COMMIT;
