#!/usr/bin/env python3
"""Test script for training_db API."""

import sys
from datetime import datetime
sys.path.insert(0, '/home/ubuntu/mangodb')

from training_db import (
    init_db,
    insert_run,
    update_run_status,
    get_run,
    query_runs,
    attach_blog_post,
    attach_crash_data,
    attach_conversation,
    get_stats
)

def test_basic_operations():
    """Test basic database operations."""
    print("=" * 80)
    print("Testing Training Runs Database API")
    print("=" * 80)

    # Test 1: Insert a run
    print("\n1. Inserting test run...")
    test_config = {
        'training': {
            'batch_size': 384,
            'learning_rate': 0.0001,
            'beta': 0.05,
            'num_processes': 4
        },
        'reward': {
            'gradient_method': 'mgda'
        },
        'objectives': [
            {'name': 'COMT_activity', 'direction': 'maximize'},
            {'name': 'KCNH2_activity', 'direction': 'minimize'}
        ],
        'generation': {
            'scaffolds': [
                {'smiles': 'c1ccccc1', 'name': 'benzene'}
            ]
        }
    }

    insert_run(
        run_id='test_run_001',
        wandb_run_id=None,  # Will be added later
        config_dict=test_config,
        chain_of_custody_id='TEST01',
        run_name='test_mgda_run',
        config_file_path='/home/ubuntu/finetune_safe/configs/test.yaml',
        host='ec2',
        instance_id='i-test123'
    )
    print("✓ Run inserted")

    # Test 2: Get the run
    print("\n2. Retrieving run...")
    run = get_run('test_run_001')
    print(f"✓ Retrieved run: {run['run_name']}")
    print(f"  Status: {run['status']}")
    print(f"  Batch size: {run['batch_size']}")
    print(f"  Gradient method: {run['gradient_method']}")

    # Test 3: Update status to running
    print("\n3. Updating run status to 'running'...")
    update_run_status(
        'test_run_001',
        'running',
        wandb_run_id='abc123def',
        wandb_url='https://wandb.ai/entity/project/runs/abc123def',
        started_at=datetime.utcnow()
    )
    print("✓ Status updated to running")

    # Test 4: Attach conversation
    print("\n4. Attaching conversation...")
    attach_conversation('test_run_001', 'conversations/test_run_001/conversation.json')
    print("✓ Conversation attached")

    # Test 5: Query runs
    print("\n5. Querying runs by gradient method...")
    mgda_runs = query_runs(filters={'gradient_method': 'mgda'}, limit=10)
    print(f"✓ Found {len(mgda_runs)} MGDA runs")

    # Test 6: Simulate crash
    print("\n6. Simulating crash...")
    attach_crash_data(
        'test_run_001',
        error_log_s3_key='crash-reports/test_run_001/error.log',
        crash_report_s3_key='crash-reports/test_run_001/report.md',
        crash_analysis_s3_key='crash-reports/test_run_001/analysis.md'
    )
    print("✓ Crash data attached")

    # Test 7: Attach blog post
    print("\n7. Attaching blog post...")
    attach_blog_post('test_run_001', 'https://app.michaelnagle.bio/posts/test-mgda-analysis')
    print("✓ Blog post attached")

    # Test 8: Get updated run
    print("\n8. Retrieving updated run...")
    updated_run = get_run('test_run_001')
    print(f"✓ Final status: {updated_run['status']}")
    print(f"  W&B URL: {updated_run['wandb_url']}")
    print(f"  Blog post: {updated_run['blog_post_url']}")
    print(f"  Crash analysis: {updated_run['crash_analysis_s3_key']}")

    # Test 9: Database stats
    print("\n9. Database statistics...")
    stats = get_stats()
    print(f"✓ Total runs: {stats['total_runs']}")
    print(f"  Crashed: {stats['crashed']}")
    print(f"  With blog posts: {stats['with_blog_posts']}")
    print(f"  With crash analysis: {stats['with_crash_analysis']}")

    print("\n" + "=" * 80)
    print("All tests passed! ✓")
    print("=" * 80)


if __name__ == '__main__':
    test_basic_operations()
