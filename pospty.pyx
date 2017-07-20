from libc.stdlib cimport malloc, calloc, free
from libc.string cimport strerror
from libc.stddef cimport size_t
from libc.errno cimport errno
from posix.ioctl cimport ioctl

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
    cdef void* ptr = malloc(size)
    if ptr == NULL:
        raise MemoryError('malloc failed')
    return ptr

cdef void* safe_calloc(size_t nmemb, size_t size) except NULL:
    cdef void* ptr = calloc(nmemb, size)
    if ptr == NULL:
        raise MemoryError('calloc failed')
    return ptr

class PosixError(OSError):
    def __init__(self, errno, strerror, callname):
        super().__init__(errno, strerror, callname)
        self.callname = callname
    @classmethod
    def from_errno(cls, callname, errnum=None):
        if errnum is None:
            errnum = errno
        return cls(errnum, (<bytes>strerror(errnum)).decode(), callname)
    @classmethod
    def raise_errno(cls, callname, errnum=None):
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
        self._termios = <termios*>safe_calloc(1, sizeof(termios))
        self._winsize = <winsize*>safe_calloc(1, sizeof(winsize))
    @classmethod
    def default(cls):
        cdef Config obj = cls.__new__(cls)
        return obj
    @classmethod
    def _from_fd(cls, fd):
        cdef Config obj = cls.__new__(cls)
        obj._alloc()
        if tcgetattr(fd, obj._termios) == -1:
            PosixError.raise_errno('tcgetattr')
        if ioctl(fd, TIOCGWINSZ, obj._winsize) == -1:
            PosixError.raise_errno('ioctl')
        return obj
    @classmethod
    def from_file(cls, f):
        return cls._from_fd(f.fileno())
