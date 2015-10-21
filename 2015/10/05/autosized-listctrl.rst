public: yes
tags: [python, wx, listctrl, gui, programming]
summary: |
  A ListCtrl subclass for wxPython that autosizes columns to their minimal
  size requirements.

Create a ListCtrl with autosized columns (wxPython)
===================================================

When making a GUI with a list control, it is a common requirement to have all
text and titles visible by default. At the same time you may want some minimal
size for each column and scale them in proportion if the control is resized.

Neither of the wxPython builtin classes ListCtrl_ or ListView_ do provide such
advanced capability. Although you can specify ``LIST_AUTOSIZE`` or
``LIST_AUTOSIZE_USEHEADER`` as column size, this leads to a hardly
satisfactory experience: either column headers or text may be clipped,
depending on which of these constants you choose. Furthermore, using this
mechanism naively will lead to all columns just taking minimal space without
taking into account global properties of the list control. If the list control
is larger than the sum of the column sizes, the columns will appear bunched up
on the left leaving empty space on the right of the control which can be quite
ugly.

One might hope that another class that is shipped with wxPython might address
this problem. Indeed, there is a mixin class called ListCtrlAutoWidthMixin_.
But beware, this utility only sounds like it would do the right thing but in
fact is used for something completely different: resizing the columns to take
up all the space when the list control is resized.

The truth is: if you want a list control that shows all its content and
doesn't do major any *no-nos*, you currently have to come up with a custom
solution.

I recently had to write a piece of software like that so here I share the
result with any interested parties. The module can be `downloaded from here`_
and is free to use and modify without limitations.

Note that the code makes some opinionated choices how rows must be added to or
removed from the list control. The API is designed with the goal to separate
the tasks of formatting items from the management of list membership. This is
of course secondary and it shouldn't be too hard to extract only the
auto-sizing functionality without having to use the suggested data model.

.. code-block:: python
    :caption: Generic usage example
    :linenos:

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
                lambda person: person.name,
                wx.LIST_FORMAT_LEFT),
            ColumnInfo(
                "Erdős",
                lambda person: person.erdos_number,
                wx.LIST_FORMAT_RIGHT),
            ColumnInfo(
                "Haircut",
                lambda person: person.haircut,
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


.. _ListCtrl: http://wxpython.org/Phoenix/docs/html/ListCtrl.html
.. _ListView: http://wxpython.org/Phoenix/docs/html/ListView.html
.. _ListCtrlAutoWidthMixin: http://wxpython.org/Phoenix/docs/html/lib.mixins.listctrl.ListCtrlAutoWidthMixin.html
.. _downloaded from here: ../listctrl.py

