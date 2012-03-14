#
# Author: Parker Kuivila
# Email: ptk3[at]duke.edu -or- Parker.Kuivila[at]gmail.com
# Web: http://Parker.Kuivi.la
# 
# A multi-platform, Python implementation of Steve
# Lambert's SelfControl app. 
#
 
import sys, os, time, webbrowser, urllib
# Importing only specific modules from Qt will save us about 150MB of space
from PyQt4.QtCore import Qt, QTimer, SIGNAL
from PyQt4.QtGui import QPushButton, QDialog, QApplication, QSlider, QLabel, QHBoxLayout, \
QVBoxLayout, QPlainTextEdit, QLCDNumber, QMessageBox
from threading import Timer

class MainForm(QDialog):
     
    def __init__(self, parent=None):
        # Create our main`layout for picking duration and such
        super(MainForm, self).__init__(parent)
        self.setWindowTitle("SelfRestraint")
        # Create widgets such as buttons and slider
        self.editButton  = QPushButton("Edit Blocklist")
        self.startButton = QPushButton("Start")    
        self.timeSlider  = QSlider(Qt.Horizontal)
        self.timeLabel   = QLabel('Disabled')
        # Disable start button
        self.startButton.setEnabled(False)
        # Mess with the slider
        self.timeSlider.setTickPosition(QSlider.TicksBelow)
        self.timeSlider.setTickInterval(1)
        # Edit button widths
        self.startButton.setFixedWidth(90)
        self.editButton.setFixedWidth(120)
        self.setFixedSize(600,150)
        # Create another layout to hold bottom contents
        bottomRow = QHBoxLayout()
        layout = QVBoxLayout()
        # Add to the layout
        layout.addWidget(self.startButton,0,Qt.AlignHCenter)
        layout.addWidget(self.timeSlider)        
        bottomRow.addWidget(self.timeLabel)
        bottomRow.addWidget(self.editButton,0,Qt.AlignRight)
        layout.addLayout(bottomRow)
        # Set layout
        self.setLayout(layout)
        # Link functions to button and slider
        self.startButton.clicked.connect(backend.startBlock)
        self.timeSlider.valueChanged.connect(self.change)
        self.editButton.clicked.connect(self.openList)
         
    def openList(self):
        """docstring for openList"""
        list.show()
             
    # Displays the block time on the label        
    def change(self):
        """docstring for change"""
        if self.timeSlider.value() == 0:
            self.timeLabel.setText("Disabled")
            self.startButton.setEnabled(False)
            return
        self.startButton.setEnabled(True)
        loc = self.timeSlider.value()* 15
        if ((loc-loc%60)/60) == 1:
                hours = str((loc-loc%60)/60)+" hour, "
        elif ((loc-loc%60)/60) == 0:
                hours = ""
        else:
                hours = str((loc-loc%60)/60)+" hours, "

        self.timeLabel.setText(hours+str(loc%60) +" minutes")

class ListEditor(QDialog):

    def __init__(self, parent=None):
        # Create layout for the blocked domains
        super(ListEditor, self).__init__(parent)
        self.setWindowTitle("Website Blocklist")
        # Create widgets
        self.tableView  = QPlainTextEdit()
        self.tableView.appendPlainText("# Add one website per line #\nexample.com\n")

        layout = QVBoxLayout()
        layout.addWidget(self.tableView)
        self.saveButton = QPushButton("Done")
        self.saveButton.clicked.connect(self.closeList)
        layout.addWidget(self.saveButton, 0, Qt.AlignRight)
        
        self.setLayout(layout)
    
    def closeList(self):
        # Hide the list
        """docstring for closeList"""
        list.hide()
    

class Backend():
    """docstring for Backend"""
    # Backend class to deal with parsing the blocked lists
    # and appending them to the system hosts file
    def __init__(self, parent=None):
        if os.name == "posix":
            self.HostsFile = "/etc/hosts"
        elif os.name == "nt":
            self.HostsFile = "C:\Windows\System32\drivers\etc\hosts"
        else:
            sys.exit(1)  #let's try to avoid breaking things
        
    
    def startBlock(self):
        """docstring for startBlock"""
        # Append the blacklisted domains to the system hosts file
        form.hide()
        list.close()
        
        hostsFile = open(self.HostsFile, "a")
        
        hostsFile.write("\n# PySelfControl Blocklist. NO NOT EDIT OR MODIFY THE CONTENTS OF THIS\n")
        hostsFile.write("# PySelfControl will remove the block when the timer has ended\n")
        hostsFile.write('# Block the following sites:\n')
        
        blockedSites = list.tableView.toPlainText()
        # remove whitespace before and after
        blockedSites = [ site.strip() for site in blockedSites.split("\n") ]
        # filter out comments and empty rows
        blockedSites = [ site for site in blockedSites if (not site.startsWith('#')) and site != '' ]
        # write out
        for sites in blockedSites:
            hostsFile.write( "0.0.0.0\t"+sites+"\n" )
            temp = sites
            if sites.startsWith('www.'):
                temp = temp.split('www.')[1]
                hostsFile.write( "0.0.0.0\t"+temp+"\n" )
            else:
                hostsFile.write( "0.0.0.0\t"+"www."+sites+"\n" )

        hostsFile.write("# End Blocklist")
        hostsFile.close()
        self.blockTime = form.timeSlider.value()* 60 * 15
        t = Timer(self.blockTime,self.endBlock)
        t.start()
        counter.display(time.strftime('%H:%M.%S', time.gmtime(self.blockTime)))
        counter.show()
        timer = QTimer(counter)
        counter.connect(timer, SIGNAL("timeout()"), self.countDown)
        timer.start(1000)

        
    def countDown(self):
        self.blockTime = self.blockTime-1
        timestring = time.strftime('%H:%M.%S', time.gmtime(self.blockTime))
        counter.display(timestring)

    def endBlock(self):
        # Traverse host file and remove the site blocks
        restoreContents = []
        ignore  = False;
        f = open(self.HostsFile, "r") #Open File
        
        for line in f:
            if line == "# PySelfControl Blocklist. NO NOT EDIT OR MODIFY THE CONTENTS OF THIS\n":
                ignore = True
            if ignore == False:
                restoreContents.append(line)
            elif line == "# End Blocklist":
                ignore = False
        
        f.close()
        
        #Restore contents
        if restoreContents[len(restoreContents)-1] == "\n":
            restoreContents.pop() # prevent adding newlines each time
            
        f = open(self.HostsFile, "w")
        for line in restoreContents:
            f.write(line)
        f.close()
        form.show()
        counter.hide()

class checkForUpdates():
    def __init__(self, parent=None):
        self.VERSION = "0.2" # The version of this app
        f = urllib.urlopen("https://raw.github.com/ParkerK/selfrestraint/master/version")
        if os.name == "nt":
            self.new_version = f.read().split("\n")[0].split(":")[1]
        else:
            self.new_version = f.read().split("\n")[1].split(":")[1]
        
    def check(self):    
        if self.new_version != self.VERSION:
            self.alertBox = QMessageBox()
            self.alertBox.setText ("A new version of SelfRestraint is now available. It's recommended that you download this update")
            self.alertBox.downloadButton = self.alertBox.addButton("Get The Update",3)
            self.alertBox.downloadButton.clicked.connect(self.openURL)
            self.alertBox.addButton("Remind Me Later",1)
            self.alertBox.show()
            
    
    def openURL(self):
        webbrowser.open_new("http://parker.kuivi.la/projects/selfrestraint.html")
    
if __name__ == '__main__':
    # In OS X we need to run this as root in order to block sites
    if os.name == "posix" and sys.platform == "darwin":
        if os.getuid() !=0:
            old_uid = os.getuid()
            # os.chdir('../MacOS')
            # os.system("""osascript -e 'do shell script "./SelfRestraint;"  with administrator privileges'""") 
            # # If running via 'python SelfRestraint.py uncomment out below, and comment out above two lines
            # # os.system("""osascript -e 'do shell script "python SelfRestraint.py"  with administrator privileges'""")
            # sys.exit(1)
    elif os.name == "posix": # If Linux
        if os.geteuid() !=0: # If not root, run as root
            print "Script not started as root. Running sudo.." # Debugging stuff
            args = ['gksudo', sys.executable] + sys.argv + [os.environ]
            # the next line replaces the currently-running process with the sudo
            os.execlpe('gksudo', *args)
            sys.exit(1)
            
    
    
    # Create the Qt Application
        
    app = QApplication(sys.argv)
    backend = Backend()
    # Create and show the forms
    if os.name == "nt":
        # Make sure the program is running w/ administrative privileges.
        from win32com.shell import shell
        if not shell.IsUserAnAdmin():
            alertBox = QMessageBox()
            alertBox.setText ("You may need to run this program as an Administrator. If it doesn't work please close this program, and run it by right clicking and choose 'Run As Administrator' ")
            alertBox.show()
    
    updater = checkForUpdates()    
    updater.check()        
    form = MainForm()
    form.show()
    
    list = ListEditor()
    # Run the main Qt loop
    counter = QLCDNumber()
    counter.setSegmentStyle(QLCDNumber.Filled)
    counter.setNumDigits(8)
    counter.resize(150, 60)
    sys.exit(app.exec_())    