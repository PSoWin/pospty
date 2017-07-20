from libc.stdlib cimport malloc, calloc, free
from libc.string cimport strerror
from libc.stddef cimport size_t
from libc.errno cimport errno
from posix.ioctl cimport ioctl
from cpython.version cimport PY_VERSION_HEX

cdef extern from '<termios.h>':
    ctypedef unsigned char	cc_t
    ctypedef unsigned int	tcflag_t
    enum: NCCS
    cdef struct termios:
        tcflag_t c_iflag
        tcflag_t c_oflag
        tcflag_t c_cflag
        tcflag_t c_lflag
        cc_t c_cc[NCCS]
    int tcgetattr(int fd, termios *termios_p)

cdef extern from '<sys/ioctl.h>':
    cdef struct winsize:
        unsigned short int ws_row
        unsigned short int ws_col
        unsigned short int ws_xpixel
        unsigned short int ws_ypixel
    enum: TIOCGWINSZ
    enum: TIOCSWINSZ

cdef void* safe_malloc(size_t size) except NULL:
    """safe malloc
    raise MemoryError if failed"""
    cdef void* ptr = malloc(size)
    if ptr == NULL:
        raise MemoryError('malloc failed')
    return ptr

cdef void* safe_calloc(size_t nmemb, size_t size) except NULL:
    """safe calloc
    raise MemoryError if failed"""
    cdef void* ptr = calloc(nmemb, size)
    if ptr == NULL:
        raise MemoryError('calloc failed')
    return ptr

class PosptyError(RuntimeError):
    """base error class for pospty"""
    pass

if PY_VERSION_HEX >= 0x03040000:
    class WError(OSError):
        pass
else:
    class WError(OSError):
        def __init__(self, errno, strerror, filename = None, winerror = None, filename2 = None):
            super().__init__()
            self.errno = errno
            self.strerror = strerror
            self.filename = filename
            self.winerror = winerror
            self.filename2 = filename2

class PosixError(WError, PosptyError):
    """error of system"""
    def __init__(self, errno, strerror, callname):
        """init error with
        ``errno``
        ``strerror`` - textual error msg gets from ``strerror()``
        ``callname`` - what system call caused error"""
        super().__init__(errno, strerror, callname)
        self.callname = callname
    @classmethod
    def from_errno(cls, callname, errnum=None):
        """create PosixError by ``callname`` and last errno (if errnum is None) or errnum"""
        if errnum is None:
            errnum = errno
        return cls(errnum, (<bytes>strerror(errnum)).decode(), callname)
    @classmethod
    def raise_errno(cls, callname, errnum=None):
        """raise PosixError by ``callname`` and last errno (if errnum is None) or errnum"""
        raise cls.from_errno(callname, errnum)

cdef class Config:
    """class Config contains config of a pty"""
    cdef termios* _termios
    cdef winsize* _winsize
    def __cinit__(self):
        self._termios = NULL
        self._winsize = NULL
    def __dealloc__(self):
        free(self._termios)
        free(self._winsize)
    def _alloc(self):
        """alloc memory for ``self._termios`` and ``self._winsize``"""
        self._termios = <termios*>safe_calloc(1, sizeof(termios))
        self._winsize = <winsize*>safe_calloc(1, sizeof(winsize))
    @staticmethod
    def default():
        """create default Config"""
        cdef Config obj = Config.__new__(Config)
        return obj
    @staticmethod
    def _from_fd(fd):
        """create same Config as ``fd`` has"""
        cdef Config obj = Config.__new__(Config)
        obj._alloc()
        if tcgetattr(fd, obj._termios) == -1:
            PosixError.raise_errno('tcgetattr')
        if ioctl(fd, TIOCGWINSZ, obj._winsize) == -1:
            PosixError.raise_errno('ioctl')
        return obj
    @staticmethod
    def from_file(f):
        """create same Config as file ``f`` has"""
        return Config._from_fd(f.fileno())
