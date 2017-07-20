from libc.stdlib cimport malloc, calloc, free
from libc.string cimport strerror, memcpy, memset
from libc.stddef cimport size_t
from libc.stdint cimport intmax_t
from libc.errno cimport errno
from posix.ioctl cimport ioctl
from cpython.version cimport PY_VERSION_HEX
import operator
from functools import reduce

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

    # Input Modes
    # The c_iflag field describes the basic terminal input control:
    enum: BRKINT # Signal interrupt on break.
    enum: ICRNL # Map CR to NL on input.
    enum: IGNBRK # Ignore break condition.
    enum: IGNCR # Ignore CR.
    enum: IGNPAR # Ignore characters with parity errors.
    enum: INLCR # Map NL to CR on input.
    enum: INPCK # Enable input parity check.
    enum: ISTRIP # Strip character.
    enum: IXANY # [XSI] Enable any character to restart output.
    enum: IXOFF # Enable start/stop input control.
    enum: IXON # Enable start/stop output control.
    enum: PARMRK # Mark parity errors.

    # Output Modes
    # The c_oflag field specifies the system treatment of output:
    enum: OPOST # Post-process output.
    enum: ONLCR # [XSI] Map NL to CR-NL on output.
    enum: OCRNL # Map CR to NL on output.
    enum: ONOCR # No CR output at column 0.
    enum: ONLRET # NL performs CR function.
    enum: OFILL # Use fill characters for delay.
    enum: NLDLY # Select newline delays:
    enum: NL0 # Newline type 0.
    enum: NL1 # Newline type 1.
    enum: CRDLY # Select carriage-return delays:
    enum: CR0 # Carriage-return delay type 0.
    enum: CR1 # Carriage-return delay type 1.
    enum: CR2 # Carriage-return delay type 2.
    enum: CR3 # Carriage-return delay type 3.
    enum: TABDLY # Select horizontal-tab delays:
    enum: TAB0 # Horizontal-tab delay type 0.
    enum: TAB1 # Horizontal-tab delay type 1.
    enum: TAB2 # Horizontal-tab delay type 2.
    enum: TAB3 # Expand tabs to spaces.
    enum: BSDLY # Select backspace delays:
    enum: BS0 # Backspace-delay type 0.
    enum: BS1 # Backspace-delay type 1.
    enum: VTDLY # Select vertical-tab delays:
    enum: VT0 # Vertical-tab delay type 0.
    enum: VT1 # Vertical-tab delay type 1.
    enum: FFDLY # Select form-feed delays:
    enum: FF0 # Form-feed delay type 0.
    enum: FF1 # Form-feed delay type 1.

    # Control Modes
    # The c_cflag field describes the hardware control of the terminal; not all values specified are required to be supported by the underlying hardware:
    enum: CSIZE # Character size:
    enum: CS5 # 5 bits
    enum: CS6 # 6 bits
    enum: CS7 # 7 bits
    enum: CS8 # 8 bits
    enum: CSTOPB # Send two stop bits, else one.
    enum: CREAD # Enable receiver.
    enum: PARENB # Parity enable.
    enum: PARODD # Odd parity, else even.
    enum: HUPCL # Hang up on last close.
    enum: CLOCAL # Ignore modem status lines.

    # Local Modes
    # The c_lflag field of the argument structure is used to control various terminal functions:
    enum: ECHO # Enable echo.
    enum: ECHOE # Echo erase character as error-correcting backspace.
    enum: ECHOK # Echo KILL.
    enum: ECHONL # Echo NL.
    enum: ICANON # Canonical input (erase and kill processing).
    enum: IEXTEN # Enable extended input character processing.
    enum: ISIG # Enable signals.
    enum: NOFLSH # Disable flush after interrupt or quit.
    enum: TOSTOP # Send SIGTTOU for background output.

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

class Flag:
    """base class to contain flag"""
    def to_int(self):
        """get integer value of this flag"""
        return self._value
    def __init__(self, value):
        """init flag with integer value"""
        self._value = value
    @classmethod
    def join(cls, *flags):
        """join flags"""
        return cls(reduce(operator.or_, map(cls.to_int, flags)))

class TermiosFlag(Flag):
    """flag for termios"""
    pass
class TermiosIFlag(TermiosFlag):
    """flag for termios.c_iflag"""
    pass
class TermiosOFlag(TermiosFlag):
    """flag for termios.c_oflag"""
    pass
class TermiosCFlag(TermiosFlag):
    """flag for termios.c_cflag"""
    pass
class TermiosLFlag(TermiosFlag):
    """flag for termios.c_lflag"""
    pass

class FlagDict:
    """dict of flag"""
    def __getitem__(self, key):
        try:
            return getattr(self, key)
        except AttributeError as e:
            raise KeyError(key) from e

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
    def _alloc(self, alloc_termios=True, alloc_winsize=True):
        """alloc memory for ``self._termios`` and ``self._winsize``"""
        if alloc_termios: self._termios = <termios*>safe_calloc(1, sizeof(termios))
        if alloc_winsize: self._winsize = <winsize*>safe_calloc(1, sizeof(winsize))
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
    def copy(self):
        """dup this Config instance"""
        cdef Config obj = Config.__new__(Config)
        obj._alloc(self._termios is not NULL, self._winsize is not NULL)
        if self._termios is not NULL: memcpy(obj._termios, self._termios, sizeof(termios))
        if self._winsize is not NULL: memcpy(obj._winsize, self._winsize, sizeof(winsize))
        return obj
    def add_flags(self, *flags):
        """add flags to termios"""
        if self._termios is NULL: self._alloc(True, False)
        i, o, c, l = (
            [TermiosIFlag(self._termios.c_iflag)],
            [TermiosOFlag(self._termios.c_oflag)],
            [TermiosCFlag(self._termios.c_cflag)],
            [TermiosLFlag(self._termios.c_lflag)])
        for f in flags:
            if not isinstance(f, TermiosFlag):
                raise TypeError('TermiosFlag excepted, got {}'.format(type(f).__name__))
            if isinstance(f, TermiosIFlag):
                i.append(f)
            elif isinstance(f, TermiosOFlag):
                o.append(f)
            elif isinstance(f, TermiosCFlag):
                c.append(f)
            elif isinstance(f, TermiosLFlag):
                l.append(f)
        self._termios.c_iflag = TermiosIFlag.join(*i).to_int()
        self._termios.c_oflag = TermiosOFlag.join(*o).to_int()
        self._termios.c_cflag = TermiosCFlag.join(*c).to_int()
        self._termios.c_lflag = TermiosLFlag.join(*l).to_int()
    def clear_flags(self):
        """clear flags of termios"""
        if self._termios is NULL:
            self._alloc(True, False)
        memset(self._termios, 0, sizeof(termios))
    def set_flags(self, *flags):
        """set flags to termios"""
        self.clear_flags()
        self.add_flags(*flags)
    flag = FlagDict()
    def set_size(self, cols, rows, xpixel=0, ypixel=0):
        """set winsize"""
        if self._winsize is NULL:
            self._alloc(False, True)
        self._winsize.ws_col = cols
        self._winsize.ws_row = rows
        self._winsize.ws_xpixel = xpixel
        self._winsize.ws_ypixel = ypixel
    def set_initial_size(self, cols, rows, xpixel=0, ypixel=0):
        """set winsize"""
        return self.set_size(cols, rows, xpixel, ypixel)
for k, v in {
    'BRKINT': TermiosIFlag(BRKINT),
    'ICRNL': TermiosIFlag(ICRNL),
    'IGNBRK': TermiosIFlag(IGNBRK),
    'IGNCR': TermiosIFlag(IGNCR),
    'IGNPAR': TermiosIFlag(IGNPAR),
    'INLCR': TermiosIFlag(INLCR),
    'INPCK': TermiosIFlag(INPCK),
    'ISTRIP': TermiosIFlag(ISTRIP),
    'IXANY': TermiosIFlag(IXANY),
    'IXOFF': TermiosIFlag(IXOFF),
    'IXON': TermiosIFlag(IXON),
    'PARMRK': TermiosIFlag(PARMRK)}.items():
    setattr(TermiosIFlag, k, v)
    setattr(Config.flag, k, v)
for k, v in {
    'OPOST': TermiosOFlag(OPOST),
    'ONLCR': TermiosOFlag(ONLCR),
    'OCRNL': TermiosOFlag(OCRNL),
    'ONOCR': TermiosOFlag(ONOCR),
    'ONLRET': TermiosOFlag(ONLRET),
    'OFILL': TermiosOFlag(OFILL),
    'NLDLY': TermiosOFlag(NLDLY),
    'NL0': TermiosOFlag(NL0),
    'NL1': TermiosOFlag(NL1),
    'CRDLY': TermiosOFlag(CRDLY),
    'CR0': TermiosOFlag(CR0),
    'CR1': TermiosOFlag(CR1),
    'CR2': TermiosOFlag(CR2),
    'CR3': TermiosOFlag(CR3),
    'TABDLY': TermiosOFlag(TABDLY),
    'TAB0': TermiosOFlag(TAB0),
    'TAB1': TermiosOFlag(TAB1),
    'TAB2': TermiosOFlag(TAB2),
    'TAB3': TermiosOFlag(TAB3),
    'BSDLY': TermiosOFlag(BSDLY),
    'BS0': TermiosOFlag(BS0),
    'BS1': TermiosOFlag(BS1),
    'VTDLY': TermiosOFlag(VTDLY),
    'VT0': TermiosOFlag(VT0),
    'VT1': TermiosOFlag(VT1),
    'FFDLY': TermiosOFlag(FFDLY),
    'FF0': TermiosOFlag(FF0),
    'FF1': TermiosOFlag(FF1)}.items():
    setattr(TermiosOFlag, k, v)
    setattr(Config.flag, k, v)
for k, v in {
    'CSIZE': TermiosCFlag(CSIZE),
    'CS5': TermiosCFlag(CS5),
    'CS6': TermiosCFlag(CS6),
    'CS7': TermiosCFlag(CS7),
    'CS8': TermiosCFlag(CS8),
    'CSTOPB': TermiosCFlag(CSTOPB),
    'CREAD': TermiosCFlag(CREAD),
    'PARENB': TermiosCFlag(PARENB),
    'PARODD': TermiosCFlag(PARODD),
    'HUPCL': TermiosCFlag(HUPCL),
    'CLOCAL': TermiosCFlag(CLOCAL)}.items():
    setattr(TermiosCFlag, k, v)
    setattr(Config.flag, k, v)
for k, v in {
    'ECHO': TermiosLFlag(ECHO),
    'ECHOE': TermiosLFlag(ECHOE),
    'ECHOK': TermiosLFlag(ECHOK),
    'ECHONL': TermiosLFlag(ECHONL),
    'ICANON': TermiosLFlag(ICANON),
    'IEXTEN': TermiosLFlag(IEXTEN),
    'ISIG': TermiosLFlag(ISIG),
    'NOFLSH': TermiosLFlag(NOFLSH),
    'TOSTOP': TermiosLFlag(TOSTOP)}.items():
    setattr(TermiosLFlag, k, v)
    setattr(Config.flag, k, v)
