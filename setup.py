from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

setup(
    name='pospty',
    ext_modules=cythonize(
        Extension('pospty',
            sources=['pospty.pyx'],
            libraries=['util']),
        compiler_directives={
            'embedsignature': True,
            'language_level': 3,
            'linetrace': True}))
