SelfRestraint
=============

About
-----
SelfRestraint is a cross platform version of Steve Lambert's [SelfControl](http://github.com/slambert/selfcontrol), written in Python. It allows you to block distracting sites for a set amount of time, so you can use your computer and access the internet without having to worry about distracting sites. 

Credits
-------
SelfRestraint was developed by [Parker Kuivila](http://parker.kuivi.la)  
The UI and features were inspired by [Steve Lambert](http://visitsteve.com/)

License
-------
SelfRestraint is Free Software under the GPL. You are free to share, modify, and add to the code as you wish.

Installation
------------
If you simply want to use the program, just run the included .exe (Windows) or .app (Mac OS X) (Coming Soon!).


Building
--------
If you want to help with the project and build it yourself here's how:  
  
1. Download the dependancies  
	* Python
    * [PyQt4](http://www.riverbankcomputing.co.uk/software/pyqt/download)  
    * Qt Library (Included in the PyQT4 Installer)
    * py2app / [PyInstaller](http://www.pyinstaller.org) (depending on your system)
2. For Windows:  
	* In the PyInstaller directory run `python Configure.py`  
	* Then to create the spec file type `python Makespec.py -F -w --icon=<Path_To_Selfrestraint.ico> \path\to\SelfRestraint.py`  
	* Now a file called `SelfRestraint.spec` should appear  
	* To build the program type `python Build.py \path\to\SelfRestraint.spec`  
	
3. If you're on OS X:  
    
    * Navigate to SelfRestraint.app/Contents/Resources and open __boot__.py
    * Add `sys.path = [os.path.join(os.environ['RESOURCEPATH'], 'lib', 'python2.7', 'lib-dynload')] + sys.path` above `sys.frozen = 'macosx_app'`


Known Bugs 
----------
* Mac version requires password, messy workaround
* Does not work on OS X
* Quitting means you have to re run the app, and let is finish the countdown
* Sometimes the timer doesn't end and the block lasts forever (until hosts file is changed)

To Do
-----
* Linux Support (Possibly done?)
* Add compiled .app 
* Integrate better to use Admin privileges on OSX
* Increase robustness, and make workarounds harder
* Add site/config file to prevent constant reentering of sites