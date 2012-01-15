#   py2app/py2exe build script for MyApplication.
#   Will automatically ensure that all build prerequisites are available
#
#   Usage (Mac OS X):
#       python setup.py py2app
#
#   Usage (Windows):
#       python setup.py py2exe

# Now that we use PyInstaller, we actually might not need this file...
import sys
from setuptools import setup

mainscript = 'SelfRestraint.py'

if sys.platform == 'darwin':
    extra_options = dict(
        setup_requires=['py2app'],
        app=[mainscript],
        # Cross-platform applications generally expect sys.argv to
        # be used for opening files.
        options=dict(
            py2app=dict(
                argv_emulation=False,
                includes=['sys','os','time','threading','PySide.QtCore', 'PySide.QtGui'],
                iconfile="SelfControlIcon.icns"
                )
            ),
    )
elif sys.platform == 'win32':
    import py2exe
    extra_options = dict(
        setup_requires=['py2exe'],
        windows=[mainscript],
        icon= [1,"SelfControlIcon.icns"],
    )
else:
    extra_options = dict(
        # Normally unix-like platforms will use "setup.py install"
        # and install the main script as such
        scripts=[mainscript],
 )

setup(
name="SelfRestraint",
**extra_options
)
