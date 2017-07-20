import unittest
import os
import pospty

class TestPospty(unittest.TestCase):
    """test pospty"""
    def test_PosixError(self):
        """test PosixError"""
        self.assertTrue(issubclass(pospty.PosixError, OSError))
        self.assertTrue(issubclass(pospty.PosixError, pospty.PosptyError))
    def test_PosixError___init__(self):
        """test PosixError.__init__"""
        e = pospty.PosixError(2, 'awd', 'dwa')
        self.assertEqual(e.errno, 2)
        self.assertEqual(e.strerror, 'awd')
        self.assertEqual(e.callname, 'dwa')
    def test_PosixError_from_errno(self):
        """test PosixError.from_errno"""
        e = pospty.PosixError.from_errno('open', errnum=2)
        self.assertEqual(e.errno, 2)
        self.assertEqual(e.callname, 'open')
        self.assertEqual(e.strerror, 'No such file or directory')
    def test_PosixError_raise_errno(self):
        """test PosixError.from_errno"""
        try:
            pospty.PosixError.raise_errno('open', errnum=2)
        except pospty.PosixError as e:
            self.assertEqual(e.errno, 2)
            self.assertEqual(e.callname, 'open')
            self.assertEqual(e.strerror, 'No such file or directory')
        else:
            self.assertTrue(False)


if __name__ == '__main__':
    unittest.main()
