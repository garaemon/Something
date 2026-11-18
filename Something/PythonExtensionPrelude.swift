/// The Python source of the `something` module, the API that scratch code and the init file
/// use to extend the launcher.
///
/// It stays thin on purpose: the native module `_something_native` offers a few flat
/// functions, and the classes live here in Python, so that no native pocketpy type is needed.
enum PythonExtensionPrelude {
    static let source = #"""
        """The Python API for extending the Something launcher.

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
        """

        import json as _json
        import _something_native as _native

        class Window:
            """A window of another application.

            Get windows from windows(). Do not create them.

            Attributes:

            - title: the title of the window, a str.
            - app_name: the name of its application, a str.
            - pid: the process identifier of its application, an int.

            A window can be focused until windows() has been called twice more after the call
            that returned it. A window that has closed since cannot be focused either.
            """

            def __init__(self, handle, title, app_name, pid):
                self._handle = handle
                self.title = title
                self.app_name = app_name
                self.pid = pid

            def focus(self):
                """Brings the window to the front and activates its application.

                Returns None. The raise runs in the background, so a window that closed
                since it was listed fails without an error.

                Raises RuntimeError when the window is too old to focus.
                """
                if not _native.focus_window(self._handle):
                    raise RuntimeError("the window is gone, or its list is too old")

            def __repr__(self):
                return "Window(" + repr(self.app_name) + ", " + repr(self.title) + ")"

        class Candidate:
            """One row of the launcher, made by a source.

            Candidate(title, action=None)

            - title: the text of the row, which the query narrows. It is converted with str().
            - action: a function without arguments that runs when the user picks the row,
            or None for a row that cannot be picked. Its return value is ignored. An
            exception that it raises goes to the log of the app.
            """

            def __init__(self, title, action=None):
                self.title = title
                self.action = action

        def windows():
            """Lists the standard windows of the running applications.

            Returns a list of Window, which is empty until the Accessibility permission is
            granted. Only the windows on the current Space are listed.
            """
            records = _json.loads(_native.list_windows())
            return [Window(w["handle"], w["title"], w["app_name"], w["pid"]) for w in records]

        # Insertion order is the display order, and a source added again keeps its place.
        _sources = {}
        # Only the latest two generations of actions stay callable, so that memory stays
        # bounded and a row listed just before a refresh still works.
        _state = {"generation": 0, "actions": {}}

        def add_source(name, candidates):
            """Adds a source of rows to the launcher, or replaces the one with the same name.

            - name: identifies the source. Adding a name again replaces its function and keeps
            its place in the order, so that running the same scratch block twice adds no rows.
            - candidates: a function without arguments that returns a list of Candidate. A
            str in the list stands for a Candidate without an action. It runs each time the
            launcher opens, not when you add the source. When it raises, the launcher logs the
            error and lists the other sources as usual.

            Returns None.

            Raises TypeError when candidates is not callable.
            """
            if not callable(candidates):
                raise TypeError("candidates must be a function that returns a list")
            _sources[name] = candidates

        def remove_source(name):
            """Removes the source that add_source added under name.

            Does nothing when there is no such source. Returns None.
            """
            if name in _sources:
                _sources.pop(name)

        def _collect():
            generation = _state["generation"] + 1
            actions = []
            items = []
            errors = []
            for name in list(_sources.keys()):
                try:
                    rows = _sources[name]()
                    new_rows = []
                    for row in rows:
                        if not isinstance(row, Candidate):
                            row = Candidate(str(row))
                        new_rows.append((str(row.title), row.action))
                except Exception as e:
                    message = type(e).__name__ + ": " + str(e)
                    errors.append({"source": str(name), "message": message})
                    continue
                for title, action in new_rows:
                    index = None
                    if action is not None:
                        index = len(actions)
                        actions.append(action)
                    items.append({"source": str(name), "title": title, "action": index})
            _state["generation"] = generation
            _state["actions"][generation] = actions
            _state["actions"].pop(generation - 2, None)
            return _json.dumps({"generation": generation, "items": items, "errors": errors})

        def _run_action(generation, index):
            actions = _state["actions"].get(generation)
            if actions is None or index < 0 or index >= len(actions):
                return False
            actions[index]()
            return True
        """#
}
