#
# Author: Parker Kuivila
# Email: ptk3[at]duke.edu -or- Parker.Kuivila[at]gmail.com
# Web: http://Parker.Kuivi.la
# 
# A multi-platform, Python implementation of Steve
# Lambert's SelfControl app. 
#
 
import sys
import os
import time
from PySide.QtCore import *
from PySide.QtGui import *
from threading import Timer

class MainForm(QDialog):
     
    def __init__(self, parent=None):
        # Create our main`layout for picking duration and such
        super(MainForm, self).__init__(parent)
        self.setWindowTitle("PySelfControl")
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
        # os.system("""osascript -e 'do shell script "echo true"  with administrator privileges'""")
        form.hide()
        list.close()
        
        hostsFile = open(self.HostsFile, "r")
        
        
        tempHosts = open('/tmp/etc_hosts.tmp', 'a')
        for line in hostsFile:
            tempHosts.write(line)
        
        
        tempHosts.write("\n# PySelfControl Blocklist. NO NOT EDIT OR MODIFY THE CONTENTS OF THIS\n")
        tempHosts.write("# PySelfControl will remove the block when the timer has ended\n")
        tempHosts.write('# Block the following sites:\n')
        
        blockedSites = list.tableView.toPlainText()
        blockedSites = blockedSites.split("\n")
        
        for sites in blockedSites:
            if sites != "# Add one website per line #" and len(sites)>2:
                tempHosts.write( "0.0.0.0\t"+sites+"\n" )
            
        tempHosts.write("# End Blocklist")
        tempHosts.close()
        hostsFile.close()
        
        os.system("""osascript -e 'do shell script "mv /tmp/etc_hosts.tmp /etc/hosts"  with administrator privileges'""")
        
        
        self.blockTime = form.timeSlider.value()*  60 * 15
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


if __name__ == '__main__':
    # Create the Qt Application
    app = QApplication(sys.argv)
    backend = Backend()
    # Create and show the forms
    form = MainForm()
    form.show()
    list = ListEditor()
    # Run the main Qt loop
    counter = QLCDNumber()
    counter.setSegmentStyle(QLCDNumber.Filled)
    counter.setNumDigits(8)
    counter.resize(150, 60)
    sys.exit(app.exec_())
    