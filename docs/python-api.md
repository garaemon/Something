# Python API: `something`

This file is generated from the docstrings in `Something/PythonExtensionPrelude.swift` by `Tools/PythonAPIDocs/generate_python_api_docs.py`. Do not edit it by hand. Change the docstring, then run `mise run docs`.

The Python API for extending the Something launcher.

Code in the scratch buffer and in the init file runs in the same interpreter as this
module, so a block that you run in the scratch buffer extends the running launcher
at once, as in the scratch buffer of Emacs. The init file is
~/Library/Application Support/Something/init.py. It runs at launch and again after
every reset of the interpreter, so what it registers is permanent.

A source is a function that returns the rows to list. This one lists a row per
window, and picking a row focuses that window:

    import something

    def row(w):
        return something.Candidate(w.app_name + " - " + w.title, w.focus)

    def rows():
        return [row(w) for w in something.windows()]

    something.add_source("python windows", rows)

The launcher asks every source for its rows each time it opens, and narrows them by
the query like its built-in rows.

## class `something.Window`

A window of another application.

Get windows from windows(). Do not create them.

Attributes:

- title: the title of the window, a str.
- app_name: the name of its application, a str.
- pid: the process identifier of its application, an int.

A window can be focused until windows() has been called twice more after the call
that returned it. A window that has closed since cannot be focused either.

### `Window.focus()`

Brings the window to the front and activates its application.

Returns None. The raise runs in the background, so a window that closed
since it was listed fails without an error.

Raises RuntimeError when the window is too old to focus.

## class `something.Candidate`

One row of the launcher, made by a source.

Candidate(title, action=None)

- title: the text of the row, which the query narrows. It is converted with str().
- action: a function without arguments that runs when the user picks the row,
or None for a row that cannot be picked. Its return value is ignored. An
exception that it raises goes to the log of the app.

## `something.windows()`

Lists the standard windows of the running applications.

Returns a list of Window, which is empty until the Accessibility permission is
granted. Only the windows on the current Space are listed.

## `something.add_source(name, candidates)`

Adds a source of rows to the launcher, or replaces the one with the same name.

- name: identifies the source. Adding a name again replaces its function and keeps
its place in the order, so that running the same scratch block twice adds no rows.
- candidates: a function without arguments that returns a list of Candidate. A
str in the list stands for a Candidate without an action. It runs each time the
launcher opens, not when you add the source. When it raises, the launcher logs the
error and lists the other sources as usual.

Returns None.

Raises TypeError when candidates is not callable.

## `something.remove_source(name)`

Removes the source that add_source added under name.

Does nothing when there is no such source. Returns None.
