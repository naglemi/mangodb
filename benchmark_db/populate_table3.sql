-- Populate GuacaMol Benchmark Database with Table 3 data
-- Faithfully reproduces Table 3 from GuacaMol paper (Brown et al. 2019)

BEGIN TRANSACTION;

-- ============================================================================
-- SMARTS Abbreviations (from Table 3 footnote)
-- ============================================================================

INSERT INTO smarts_abbreviations (abbreviation, full_smarts, description) VALUES
('s1', 'CN(C=O)Cc1ccc(c2ccccc2)cc1', 'Valsartan-related pattern'),
('s2', '[#7]-c1n[c;h1]nc2[c;h1]c(-[#8])[c;h0][c;h1]c12', 'Pyrimidine core with oxygen'),
('s3', '[#7]-c1ccc2ncsc2c1', 'Thiazole pattern'),
('s4', 'CS([#6])(=O)=O', 'Methylsulfonyl group'),
('s5', 'CCCOc1cc2ncnc(Nc3ccc4ncsc4c3)c2cc1S(=O)(=O)C(C)(C)C', 'Erlotinib structure'),
('s6', '[#6]-[#6]-[#6]-[#8]-[#6]~[#6]~[#6]~[#6]~[#6]-[#7]-c1ccc2ncsc2c1', 'Ether chain pattern');

-- ============================================================================
-- Rediscovery Benchmarks (3 benchmarks)
-- ============================================================================

-- Celecoxib rediscovery
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Celecoxib rediscovery', 'top-1', NULL, 'rediscovery', 'Rediscover celecoxib molecule');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Celecoxib rediscovery'),
    'similarity', 'sim(celecoxib, ECFP4)', 'celecoxib', 'ECFP4', 'none', 1
);

-- Troglitazone rediscovery
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Troglitazone rediscovery', 'top-1', NULL, 'rediscovery', 'Rediscover troglitazone molecule');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Troglitazone rediscovery'),
    'similarity', 'sim(troglitazone, ECFP4)', 'troglitazone', 'ECFP4', 'none', 1
);

-- Thiothixene rediscovery
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Thiothixene rediscovery', 'top-1', NULL, 'rediscovery', 'Rediscover thiothixene molecule');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Thiothixene rediscovery'),
    'similarity', 'sim(thiothixene, ECFP4)', 'thiothixene', 'ECFP4', 'none', 1
);

-- ============================================================================
-- Similarity Benchmarks (3 benchmarks)
-- ============================================================================

-- Aripiprazole similarity
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Aripiprazole similarity', 'top-1,top-10,top-100', NULL, 'similarity', 'Generate molecules similar to aripiprazole');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, modifier_threshold, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Aripiprazole similarity'),
    'similarity', 'sim(aripiprazole, ECFP4)', 'aripiprazole', 'ECFP4', 'thresholded', 0.75, 1
);

-- Albuterol similarity
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Albuterol similarity', 'top-1,top-10,top-100', NULL, 'similarity', 'Generate molecules similar to albuterol');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, modifier_threshold, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Albuterol similarity'),
    'similarity', 'sim(albuterol, FCFP4)', 'albuterol', 'FCFP4', 'thresholded', 0.75, 1
);

-- Mestranol similarity
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Mestranol similarity', 'top-1,top-10,top-100', NULL, 'similarity', 'Generate molecules similar to mestranol');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, modifier_threshold, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Mestranol similarity'),
    'similarity', 'sim(mestranol, AP)', 'mestranol', 'AP', 'thresholded', 0.75, 1
);

-- ============================================================================
-- Isomer Benchmarks (2 benchmarks)
-- ============================================================================

-- C11H24 isomer
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('C11H24', 'top-159', NULL, 'isomer', 'Generate isomers of C11H24 (159 possible isomers)');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, isomer_formula,
    modifier_type, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C11H24'),
    'isomer', 'isomer(C11H24)', 'C11H24', 'none', 1
);

-- C9H10N2O2PF2Cl isomer
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('C9H10N2O2PF2Cl', 'top-250', NULL, 'isomer', 'Generate isomers of C9H10N2O2PF2Cl');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, isomer_formula,
    modifier_type, objective_order
) VALUES (
    (SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'C9H10N2O2PF2Cl'),
    'isomer', 'isomer(C9H10N2O2PF2Cl)', 'C9H10N2O2PF2Cl', 'none', 1
);

-- ============================================================================
-- Median Molecules (2 benchmarks)
-- ============================================================================

-- Median molecules 1 (camphor-menthol)
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Median molecules 1', 'top-1,top-10,top-100', 'geometric', 'median', 'Find molecules between camphor and menthol');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'),
     'similarity', 'sim(camphor, ECFP4)', 'camphor', 'ECFP4', 'none', 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 1'),
     'similarity', 'sim(menthol, ECFP4)', 'menthol', 'ECFP4', 'none', 2);

-- Median molecules 2 (tadalafil-sildenafil)
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Median molecules 2', 'top-1,top-10,top-100', 'geometric', 'median', 'Find molecules between tadalafil and sildenafil');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type,
    modifier_type, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'),
     'similarity', 'sim(tadalafil, ECFP6)', 'tadalafil', 'ECFP6', 'none', 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Median molecules 2'),
     'similarity', 'sim(sildenafil, ECFP6)', 'sildenafil', 'ECFP6', 'none', 2);

-- ============================================================================
-- MPO Benchmarks (8 benchmarks)
-- ============================================================================

-- Osimertinib MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Osimertinib MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Osimertinib analogs with optimized TPSA and logP');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name,
    modifier_type, modifier_threshold, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'),
     'similarity', 'sim(osimertinib, FCFP4)', 'osimertinib', 'FCFP4', NULL, 'thresholded', 0.8, NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'),
     'similarity', 'sim(osimertinib, ECFP6)', 'osimertinib', 'ECFP6', NULL, 'min_gaussian', NULL, 0.85, 2, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'),
     'tpsa', 'TPSA', NULL, NULL, 'tpsa', 'max_gaussian', NULL, 100, 2, 3),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Osimertinib MPO'),
     'logp', 'logP', NULL, NULL, 'logp', 'min_gaussian', NULL, 1, 2, 4);

-- Fexofenadine MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Fexofenadine MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Fexofenadine analogs with optimized TPSA and logP');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name,
    modifier_type, modifier_threshold, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'),
     'similarity', 'sim(fexofenadine, AP)', 'fexofenadine', 'AP', NULL, 'thresholded', 0.8, NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'),
     'tpsa', 'TPSA', NULL, NULL, 'tpsa', 'max_gaussian', NULL, 90, 2, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Fexofenadine MPO'),
     'logp', 'logP', NULL, NULL, 'logp', 'min_gaussian', NULL, 4, 2, 3);

-- Ranolazine MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Ranolazine MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Ranolazine analogs with optimized logP, TPSA, and fluorine count');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name,
    modifier_type, modifier_threshold, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'),
     'similarity', 'sim(ranolazine, AP)', 'ranolazine', 'AP', NULL, 'thresholded', 0.7, NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'),
     'logp', 'logP', NULL, NULL, 'logp', 'max_gaussian', NULL, 7, 1, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'),
     'tpsa', 'TPSA', NULL, NULL, 'tpsa', 'max_gaussian', NULL, 95, 20, 3),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Ranolazine MPO'),
     'count', 'number of fluorine atoms', NULL, NULL, 'num_fluorine', 'gaussian', NULL, 1, 1, 4);

-- Perindopril MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Perindopril MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Perindopril analogs with target aromatic ring count');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'),
     'similarity', 'sim(perindopril, ECFP4)', 'perindopril', 'ECFP4', NULL, 'none', NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Perindopril MPO'),
     'count', 'number aromatic rings', NULL, NULL, 'num_aromatic_rings', 'gaussian', 2, 0.5, 2);

-- Amlodipine MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Amlodipine MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Amlodipine analogs with target total ring count');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'),
     'similarity', 'sim(amlodipine, ECFP4)', 'amlodipine', 'ECFP4', NULL, 'none', NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Amlodipine MPO'),
     'count', 'number rings', NULL, NULL, 'num_rings', 'gaussian', 3, 0.5, 2);

-- Sitagliptin MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Sitagliptin MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Molecules dissimilar to sitagliptin but with similar properties');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, property_name, isomer_formula,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'),
     'similarity', 'sim(sitagliptin, ECFP4)', 'sitagliptin', 'ECFP4', NULL, NULL, 'gaussian', 0, 0.1, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'),
     'logp', 'logP', NULL, NULL, 'logp', NULL, 'gaussian', 2.0165, 0.2, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'),
     'tpsa', 'TPSA', NULL, NULL, 'tpsa', NULL, 'gaussian', 77.04, 5, 3),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Sitagliptin MPO'),
     'isomer', 'isomer(C16H15F6N5O)', NULL, NULL, NULL, 'C16H15F6N5O', 'none', NULL, NULL, 4);

-- Zaleplon MPO
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Zaleplon MPO', 'top-1,top-10,top-100', 'geometric', 'mpo', 'Molecules similar to zaleplon but with different formula');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, target_molecule, fingerprint_type, isomer_formula,
    modifier_type, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'),
     'similarity', 'sim(zaleplon, ECFP4)', 'zaleplon', 'ECFP4', NULL, 'none', 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Zaleplon MPO'),
     'isomer', 'isomer(C19H17N3O2)', NULL, NULL, 'C19H17N3O2', 'none', 2);

-- Valsartan SMARTS
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Valsartan SMARTS', 'top-1,top-10,top-100', 'geometric', 'smarts', 'Molecules with valsartan SMARTS pattern and sitagliptin properties');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, smarts_pattern, smarts_present, property_name,
    modifier_type, modifier_mu, modifier_sigma, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'),
     'smarts', 'SMARTS(s1, true)', 's1', TRUE, NULL, 'none', NULL, NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'),
     'logp', 'logP', NULL, NULL, 'logp', 'gaussian', 2.0165, 0.2, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'),
     'tpsa', 'TPSA', NULL, NULL, 'tpsa', 'gaussian', 77.04, 5, 3),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Valsartan SMARTS'),
     'bertz', 'Bertz', NULL, NULL, 'bertz_complexity', 'gaussian', 896.38, 30, 4);

-- ============================================================================
-- Hop Benchmarks (2 benchmarks)
-- ============================================================================

-- Deco Hop (Decoration Hopping)
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Deco Hop', 'top-1,top-10,top-100', 'arithmetic', 'hop', 'Change decorations while keeping scaffold');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, smarts_pattern, smarts_present, target_molecule, fingerprint_type,
    modifier_type, modifier_threshold, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'),
     'smarts', 'SMARTS(s2, true)', 's2', TRUE, NULL, NULL, 'none', NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'),
     'smarts', 'SMARTS(s3, false)', 's3', FALSE, NULL, NULL, 'none', NULL, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'),
     'smarts', 'SMARTS(s4, false)', 's4', FALSE, NULL, NULL, 'none', NULL, 3),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Deco Hop'),
     'similarity', 'sim(s5, PHCO)', 's5', NULL, NULL, 'PHCO', 'thresholded', 0.85, 4);

-- Scaffold Hop
INSERT INTO benchmarks (benchmark_name, scoring_type, aggregation_method, category, description)
VALUES ('Scaffold Hop', 'top-1,top-10,top-100', 'arithmetic', 'hop', 'Change scaffold while keeping decorations');

INSERT INTO scoring_functions (
    benchmark_id, function_type, function_name, smarts_pattern, smarts_present, target_molecule, fingerprint_type,
    modifier_type, modifier_threshold, objective_order
) VALUES
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'),
     'smarts', 'SMARTS(s2, false)', 's2', FALSE, NULL, NULL, 'none', NULL, 1),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'),
     'smarts', 'SMARTS(s6, true)', 's6', TRUE, NULL, NULL, 'none', NULL, 2),
    ((SELECT benchmark_id FROM benchmarks WHERE benchmark_name = 'Scaffold Hop'),
     'similarity', 'sim(s5, PHCO)', 's5', NULL, NULL, 'PHCO', 'thresholded', 0.75, 3);

COMMIT;
