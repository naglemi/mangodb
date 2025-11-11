"""
mangodb - SQL database infrastructure for mango training system
"""

from setuptools import setup, find_packages

setup(
    name='mangodb',
    version='2.0.0',
    description='SQL database infrastructure for mango training system',
    author='Mango Team',
    packages=find_packages(),
    python_requires='>=3.8',
    install_requires=[
        # No dependencies - uses Python stdlib sqlite3
    ],
    extras_require={
        'postgres': ['psycopg2-binary'],  # For PostgreSQL migration
    },
    package_data={
        'training_db': ['*.sql', '*.md'],
    },
)
