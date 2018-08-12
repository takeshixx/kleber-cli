from setuptools import setup
import kleber_cli

setup(name='kleber',
      version=kleber_cli.__version__,
      packages=['kleber_cli'],
      entry_points = {
            'console_scripts': ['kleber=kleber_cli.main:main']},
      url='https://github.com/takeshixx/kleber-cli',
      license='BSD-3-Clause',
      author='takeshix',
      description='Official command line client for Kleber')