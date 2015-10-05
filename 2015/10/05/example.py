# encoding: utf-8
import wx
from listctrl import ColumnInfo, ListCtrl


# We want to present multiple data records of the following arbitrary data
# type in a list control:
class Person:

    def __init__(self, name, haircut, erdos_number):
        self.name = name
        self.haircut = haircut
        self.erdos_number = erdos_number


class Dialog(wx.Dialog):

    # List of columns, note that there is *no* requirement that they are class
    # variables. They could also be determined dynamically and for example
    # make use of methods as formatter functions:
    Columns = [
        ColumnInfo(
            "Name",
            lambda idx, person: person.name,
            wx.LIST_FORMAT_LEFT),
        ColumnInfo(
            "Erdős",
            lambda idx, person: person.erdos_number,
            wx.LIST_FORMAT_RIGHT),
        ColumnInfo(
            "Haircut",
            lambda idx, person: person.haircut,
            wx.LIST_FORMAT_LEFT),
    ]

    def __init__(self):
        wx.Dialog.__init__(self, None, wx.ID_ANY, title="List Control Example",
                           size=(500,300))

        # Create the list control:
        self.listctrl = listctrl = ListCtrl(self, self.Columns)

        # Initialize shown data records like this:
        # (The same syntax can also be used to later reset the list)
        listctrl.items = [
            Person("Olliver", "Afro", 6),
            Person("Franz", "Bowl cut", 10),
        ]

        # Do boring sizer stuff (ignore this)
        sizer = wx.BoxSizer(wx.VERTICAL)
        sizer.Add(listctrl, 1, wx.ALL|wx.EXPAND, 5)
        sizer.Add(wx.StaticLine(self, wx.HORIZONTAL), 0, wx.EXPAND, 5)
        close_button = wx.Button(self, wx.ID_CLOSE)
        sizer.Add(close_button, 0, wx.ALL|wx.ALIGN_CENTER, 5)
        self.Bind(wx.EVT_BUTTON, self.OnClose, close_button)
        self.SetSizer(sizer)
        self.Layout()
        self.Fit()

    def OnClose(self, event):
        self.Close()



if __name__ == "__main__":
    app = wx.App(False)
    win = Dialog()

    # Add multiple items:
    win.listctrl.items.extend([
        Person("Kaspar", "Mullet", 7),
        Person("Nimbus", "Chonmage", 7),
    ])

    win.ShowModal()

