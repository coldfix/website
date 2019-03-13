tags: [deploy, python, offline, installation, conda, windows]
summary: |
  Deploying embeddable python windows applications with pip, conda and nsis.

Deploying python applications
=============================

I've been using python for years, but never quite figured out (until now) how
to create an easily deployable windows application without relying on internet
access at installation time. The user should be able to just unzip or install
in a certain location and it works.

There are a number of packagers such as PyInstaller_, cx_Freeze_, pyqtdeploy_,
py2exe_, nuitka_ which apparently work very well for many. For me they didn't.
Be it due to unclear documentation, complex package specification or build
process, or even build or runtime errors, I gave up quickly. Apart from that,
I have requirements that were usually not explained (or even supported):
multiple executables, package data files, source code installation of selected
packages (so it is possible to inspect and modify on the target machine). All
this would probably be possible to setup with more tenacity by learning more
about the specification scripts/languages, but I have found an easier solution
for me!

If you're looking through the windows downloads list at python.org_, you'll
notice that there is now an *embeddable zip file*. This contains a small
python distribution without any fuzz. It is just about 13MB big, after
extraction. Perfect for redistribution with your application. There is already
a great `blog article`_, but I will go in a bit more detail here. The plan is
as follows:

.. _PyInstaller: http://www.pyinstaller.org/
.. _cx_Freeze: http://cx-freeze.sourceforge.net/
.. _pyqtdeploy: http://pyqt.sourceforge.net/Docs/pyqtdeploy/
.. _py2exe: http://www.py2exe.org/
.. _nuitka: http://nuitka.net
.. _python.org: https://www.python.org/downloads/windows/
.. _blog article: https://devblogs.microsoft.com/python/cpython-embeddable-zip-file/

On the developer machine:

0. download and extract embeddable python to ``pkg/``
1. install your python modules to ``pkg/lib/site-packages``
2. add launchers for your application ``pkg/*.exe``
3. zip up the ``pkg/`` directory, or create an installer (e.g. with nsis)

On the user machine:

4. extract or install the application
5. profit

.. contents::
    :depth: 1


Build environment
~~~~~~~~~~~~~~~~~

On the developer machine, I strongly recommend using miniconda_ (or anaconda)
as build environment. This will make it very easy to acquire non-python
dependencies and manage python environments.

Let's start by setting up our own python environment in a local folder. Open a
conda terminal and type:

.. code-block:: bat

    call conda create -p py37 python=3.7 wheel
    call conda activate .\py37

In the interactive terminal you don't have to type ``call`` here, but it
becomes necessary when putting this in a ``.bat`` script. For consistency, I
write it on other command executions as well.

.. _miniconda: https://docs.conda.io/en/latest/miniconda.html


Embeddable python
~~~~~~~~~~~~~~~~~

Next, acquire the embeddable python runtime:

.. code-block:: bat

    set ZIP=python-3.7.2.post1-embed-amd64.zip
    set URL=https://www.python.org/ftp/python/3.7.2/%ZIP%
    call conda install pywget 7za
    call python -m wget %URL%
    call 7za x -y -opkg %ZIP%

I like to extract everything into a ``pkg`` directory, that can later just be
zipped up and distributed.

If you are hesitant to ship python along with the application (as I initially
was), there are many advantages to this, such as:

- the user doesn't have to install python manually
- no interference from other installations
- no package conflicts with other applications


Python packages
~~~~~~~~~~~~~~~

If your application has any python dependencies, you will probably want to
install them as *site-packages*. In order to allow python to find the
site-packages directory, we have to take care of the following detail:

.. code-block:: bat

    echo import site>>pkg\python37._pth

Do **not** add quotes or spaces around 'import site' as you might do on linux!
It will mess up the required format!

I prefer to do a two stage setup: First, download or create wheels for all
required python packages, and then install the wheels into a target folder.
This makes it easier to skip the whole download/wheel building step if you
mess something up and in principle allows redistributing the wheels directly
for installation on the target machine:

.. code-block:: bat

    pip wheel -r requirements.txt -w wheels
    pip install -r requirements.txt -f wheels ^
          -t pkg\Lib\site-packages --no-index
    rd /s /q pkg\Lib\site-packages\bin

You can put only the name and version of your application in the requirements
file, in which case pip will automatically install dependencies in the newest
available version. If you want to lock dependencies from a tested
configuration, the requirements file can be generated with ``pip freeze >
requirements.txt``.

Depending on your needs, there may be extra steps here. For example, if you
haven't uploaded your package to PyPI, you might need additional build
instructions or may need to bundle additional files.


Application EXEs
~~~~~~~~~~~~~~~~

We will now add an ``app.exe`` that launches your application. In the simplest
case, where clicking your exe should do the same as typing ``python -m app``
on the command line, the following code is enough:

.. code-block:: C
    :caption: launcher.c

    #define COMMAND L"python -m app"

    #include "python.h"
    #include <windows.h>

    int WINAPI WinMain(
            HINSTANCE hInstance,
            HINSTANCE hPrevInstance,
            LPTSTR lpCmdLine,
            int nCmdShow)
    {
        int argc;
        wchar_t** wargv = CommandLineToArgvW(COMMAND, &argc);
        return Py_Main(argc, wargv);
    }

For more advanced use cases, read `Embedding Python in Another Application`_.

You can compile and link this against ``python37.dll`` with the compiler of
your choice. It is advisable to use the compiler that is officially used to
build python on windows, see `Which Microsoft Visual C++ compiler to use with
a specific Python version?`_ or `Windows Compilers`_.

For unrelated reasons, I personally use mingwpy_ instead. This package can be
conveniently installed via conda, however is available only up to python 3.4,
one has to create a separate environment with mingwpy in it:

.. code-block:: bat

    call conda create -p py34 python=3.4
    call conda install -p py34 mingwpy -c conda-forge
    set "gcc=py34\Scripts\gcc.exe"

Next, compile as follows:

.. code-block:: bat

    set "cflags=-Ipy37\include"
    set "lflags=-Lpy37\libs -lpython37 -mwindows"

    call %gcc% %cflags% launcher.c %lflags% -o pkg\app.exe

The ``-mwindows`` flag is used to prevent a console window from popping up
with your application (assuming you run a GUI application, otherwise just
remove this flag). If you want to pop up a console window only in certain
cases, you could use the AllocConsole_ function in the WinAPI.

If you are following my (rather bad) example to use mingwpy, also read the
section on `CRT issues`_. Apart from that you now have a fully functional and
portable application in the ``pkg/`` folder that you can start using, or zip
it up and transport to another machine.

.. _Embedding Python in Another Application: https://docs.python.org/3/extending/embedding.html
.. _Which Microsoft Visual C++ compiler to use with a specific Python version?: https://wiki.python.org/moin/WindowsCompilers#Which_Microsoft_Visual_C.2B-.2B-_compiler_to_use_with_a_specific_Python_version_.3F
.. _Windows Compilers: https://github.com/conda/conda-build/wiki/Windows-Compilers
.. _mingwpy: https://mingwpy.github.io/
.. _AllocConsole: https://docs.microsoft.com/en-us/windows/console/allocconsole


CRT issues
~~~~~~~~~~

Note that the version of mingw used above is tailored to python 3.4 and
therefore links against ``msvcr100.dll`` that is not included with python 3.7
– which will result in startup errors if the DLL is not already present on the
target machine by some happy accident. This problem can be alleviated by
copying the DLL to your package distribution:

.. code-block:: bat

    copy py34\msvcr100.dll pkg\

Furthermore, you have to make absolutetly sure not to pass CRT objects from
your C code to python, this *will* crash your application at runtime.

If you are still unwilling to use the official compiler, I will now show the
*don't-do-this-at-home* solution:

gcc can be instructed not to link against its default set of standard runtime
libraries by passing the ``-nostdlib`` flag. However, in this case, no startup
code will be executed, you are completely on your own with CRT initialization
and global variable initialization. This is therefore not recommended if you
are not aware that things can go terribly wrong... Let's get going!

Change your launcher's main function to ``WinMainCRTStartup``, e.g.:

.. code-block:: C
    :caption: launcher-nostdlib.c

    #define COMMAND L"python -m app"

    #include "python.h"
    #include <windows.h>

    void WINAPI WinMainCRTStartup()
    {
        int argc;
        wchar_t** wargv = CommandLineToArgvW(COMMAND, &argc);
        ExitProcess(Py_Main(argc, wargv));
    }

and add ``-nostdlib -lkernel32 -lshell32`` to your linker flags:

.. code-block:: bat

    set "cflags=-Ipy37\include"
    set "lflags=-Lpy37\libs -lpython37 -nostdlib -lkernel32 -lshell32 -mwindows"

    call %gcc% %cflags% launcher-nostdlib.c %lflags% -o pkg\app.exe


Bonus: EXE Icon
~~~~~~~~~~~~~~~

In order to add an icon to your EXE, first create a ``app.rc`` file with the
name of your icon, e.g.:

.. code-block:: C
    :caption: app.rc

    id ICON "app.ico"

then compile this to a ``.res`` file:

.. code-block:: bat

    call py34\Scripts\windres.exe app.rc -O coff -o app.res

All that is left to do, is to add ``app.res`` to the list of source files on
your gcc command line when building the EXE, e.g.:

.. code-block:: bat

    call %gcc% %cflags% launcher.c app.res %lflags% -o pkg\app.exe

While we're at it, you may also consider adding a version header about your
application to the EXE (see VERSIONINFO_, StringFileInfo_, and VarFileInfo_
for further documentation):

.. code-block:: C
    :caption: app.rc

    1 VERSIONINFO
    FILEVERSION     1,0,0,0
    PRODUCTVERSION  1,0,0,0
    BEGIN
        BLOCK "StringFileInfo"
        BEGIN
            BLOCK "040904E4"                    // US English
            BEGIN
                VALUE "CompanyName",            "Awesome Corp"
                VALUE "FileDescription",        "Awesome App"
                VALUE "FileVersion",            "1.0.0.0"
                VALUE "InternalName",           "app"
                VALUE "LegalCopyright",         "Awesome Corp 2019"
                VALUE "OriginalFilename",       "app.exe"
                VALUE "ProductName",            "app"
                VALUE "ProductVersion",         "1.0.0.0"
            END
        END
        BLOCK "VarFileInfo"
        BEGIN
            VALUE "Translation", 0x409, 1252    // US English
        END
    END

.. _VERSIONINFO: https://docs.microsoft.com/en-us/windows/desktop/menurc/versioninfo-resource
.. _StringFileInfo: https://docs.microsoft.com/en-us/windows/desktop/menurc/stringfileinfo-block
.. _VarFileInfo: https://docs.microsoft.com/en-us/windows/desktop/menurc/varfileinfo-block


Bonus: NSIS Installer
~~~~~~~~~~~~~~~~~~~~~

If you like to provide an installer, consider using NSIS_, it's simple and
powerful. A minimal nsis script that extracts the application at a target
directory might look like this:

.. code-block:: nsi
    :caption: app.nsi

    !define app_name "app"
    !define app_version "1.0.0"

    OutFile "${app_name}_${app_version}_setup.exe"
    InstallDir "D:\${app_name}"

    Page directory
    Page instfiles

    Section
        SetOutPath "$INSTDIR"
        File /r "pkg\*"
    SectionEnd

It can be compiled as follows:

.. code-block:: bat

    call conda install -c nsis nsis
    call makensis app.nsi

.. _NSIS: https://nsis.sourceforge.io/Main_Page
