import setuptools


setuptools.setup(
    name='data-products',
    version='0.0.1',

    author='Max Zheng',
    author_email='max@metabase.com',

    description='A library of data products that can be created from a single command.',
    long_description=open('README.md').read(),

    url='https://github.com/metabase/data-products',

    install_requires=open('requirements.txt').read(),

    license='MIT',

    packages=setuptools.find_packages(),
    include_package_data=True,

    python_requires='>=3.8',
    setup_requires=['setuptools-git', 'wheel'],

    entry_points={
       'console_scripts': [
           'dap = data_products.script:cli',
       ],
    },

    # Standard classifiers at https://pypi.org/classifiers/
    classifiers=[
      'Development Status :: 5 - Production/Stable',

      'Intended Audience :: Developers',
      'Topic :: Scientific/Engineering :: Information Analysis',

      'License :: OSI Approved :: MIT License',

      'Programming Language :: Python :: 3',
      'Programming Language :: Python :: 3.8',
    ],

    keywords='data product financial models generator',
)
