public: yes
tags: [programming, gui, python, pyqt, gist]
summary: |
  Boilerplate for dealing with common scenarios such as exceptions and
  KeyboardInterrupts (Ctrl-C) in PyQt{4,5} applications.

Reliable PyQt applications
==========================

A few months ago, I transitioned from *wxWidgets* to *Qt* as my primary
framework for writing GUI applications in python. In hindsight, this change
was long overdue and I'm now very satisfied with heart-felt increase in power
that Qt's widgets bring over those of wx. For the most part, the change was
unproblematic and things just work. However, there are a few rough edges where
things could go a little smoother, but nothing that can't be fixed. For
serious applications, I recommend handling these scenarios. A simple piece of
boilerplate such as the code below will do fine. I did not see these
techniques advertised in PyQt tutorials or example code, hence the post.

.. contents:: :local:

PyQt{4,5} or PySide?
~~~~~~~~~~~~~~~~~~~~

The question whether to use PyQt4, PyQt5 or PySide can have significant impact
on which platforms, other applications, libraries and extensions your code may
be compatible with. When writing anything but a small script, there will
probably be that time when you wish you had based your code on another toolkit
to be able to use some particular awesome library, snippet or maybe even just
one specific method. What to do then? Maintain different branches for all the
backends?

The answer is that it's much simpler than that and it doesn't have to be a
static choice in your code. First, the PyQt4, PyQt5 and PySide APIs are not
so_ different_, so most things *just work* when replacing the import
statements.  Second, python modules are just regular objects, so the imported
Qt modules can be stored in global variables which can then act
polymorphically according to which module was imported. Third, python modules
can execute arbitrary code, so you can pick the actual backend at runtime
based on the environment or command line. This is best done in a dedicated
``.qt`` module which should be used to proxy all the Qt imports within your
application.

.. _so: http://pyqt.sourceforge.net/Docs/PyQt5/pyqt4_differences.html
.. _different: https://wiki.qt.io/Differences_Between_PySide_and_PyQt

Therefore, it may be enough to change your import statements to something like
the following:

.. code-block:: python

    from .qt import Qt, QtCore, QtGui

The ``.qt`` module in my application relies on qtconsole_ (which I use to
embed a ipython shell in my application):

.. code-block:: python
    :caption: example_app/qt.py
    :linenos:

    from qtconsole.qt_loaders import load_qt
    import os

    __all__ = ['QtCore', 'QtGui', 'QtSvg', 'QT_API', 'uic']

    api_pref = os.environ.get('PYQT_API') or 'pyqt,pyqt5'
    api_opts = api_pref.lower().split(',')

    QtCore, QtGui, QtSvg, QT_API = load_qt(api_opts)

    Qt = QtCore.Qt

    if QT_API == 'pyqt':
        from PyQt4 import uic
    elif QT_API == 'pyqt5':
        from PyQt5 import uic

If you don't want to depend on such heavy gear, you can of course deliver your
own loader code. Just take a peek at qtconsole's `implementation`_, so you
don't miss any important detail.

.. _qtconsole: https://qtconsole.readthedocs.io/en/stable/
.. _implementation: https://github.com/jupyter/qtconsole/blob/master/qtconsole/qt_loaders.py


KeyboardInterrupt (Ctrl-C)
~~~~~~~~~~~~~~~~~~~~~~~~~~

The thing that initially annoyed me the most when writing and testing my shiny
(tt) new application, was that I could not quit it by pressing Ctrl-C in the
console as I'm used to. This is particularly unpleasant if no window was
opened or the Qt loop continues for some reason even after the last window was
closed/hidden. Also, if you have another background thread running which is
not properly managed by your main window, the application will live on even
after the Qt event loop has stopped.

The issue is rooted in python's `interrupt handling`_ which only works while
the interpreter is active, and the Qt event loop's ignorance about the python
interpreter. The question has a more detailed explanation_ on the PyQt mailing
list.

Given there are plenty of cases where Ctrl-C comes in handy, you can find
solutions on stackoverflow_. My personal implementation is an adaptation of
the accepted answer that safe-guards against a few more edge-cases:

.. code-block:: python

    import signal
    from .qt import QtCore, QtGui


    # Call this function in your main after creating the QApplication
    def setup_interrupt_handling():
        """Setup handling of KeyboardInterrupt (Ctrl-C) for PyQt."""
        signal.signal(signal.SIGINT, _interrupt_handler)
        # Regularly run some (any) python code, so the signal handler gets a
        # chance to be executed:
        safe_timer(50, lambda: None)


    # Define this as a global function to make sure it is not garbage
    # collected when going out of scope:
    def _interrupt_handler(signum, frame):
        """Handle KeyboardInterrupt: quit application."""
        QtGui.QApplication.quit()


    def safe_timer(timeout, func, *args, **kwargs):
        """
        Create a timer that is safe against garbage collection and overlapping
        calls. See: http://ralsina.me/weblog/posts/BB974.html
        """
        def timer_event():
            try:
                func(*args, **kwargs)
            finally:
                QtCore.QTimer.singleShot(timeout, timer_event)
        QtCore.QTimer.singleShot(timeout, timer_event)


There is also an interesting solution based on ``signal.set_wakeup_fd``, but I
ruled this one out as not being cross-platform and introducing too much
complexity.

.. _interrupt handling: https://docs.python.org/3/library/signal.html#execution-of-python-signal-handlers
.. _explanation: https://riverbankcomputing.com/pipermail/pyqt/2008-May/019242.html
.. _stackoverflow: http://stackoverflow.com/questions/4938723/what-is-the-correct-way-to-make-my-pyqt-application-quit-when-killed-from-the-co


Handling exceptions (PyQt5)
~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you're using PyQt5, you may have noticed that uncaught python exceptions
cause the program to abort. This is probably not what you want in a GUI
application where an exception that appears as the result of some dialog can
very well be irrelevant for the rest of the program. In any case, you want
to define a consistent behaviour across PyQt4 and PyQt5. This is achieved by
explicitly setting an excepthook according to your needs:

.. code-block:: python

    import sys
    import traceback

    # then, in your main:
    sys.excepthook = traceback.print_exception

