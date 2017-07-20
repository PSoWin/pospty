from distutils.core import setup
from Cython.Build import cythonize

setup(
    name='pospty',
    ext_modules=cythonize('pospty.pyx',
        compiler_directives={
            'embedsignature': True,
            'language_level': 3,
            'linetrace': True}))
