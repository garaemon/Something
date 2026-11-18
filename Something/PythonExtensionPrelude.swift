/// The Python source of the `something` module, the API that scratch code and the init file
/// use to extend the launcher.
///
/// It stays thin on purpose: the native module `_something_native` offers a few flat
/// functions, and the classes live here in Python, so that no native pocketpy type is needed.
enum PythonExtensionPrelude {
    static let source = #"""
        import json
        import _something_native as _native

        class Window:
            """A window of another application. Valid until the next windows() call but one."""

            def __init__(self, handle, title, app_name, pid):
                self._handle = handle
                self.title = title
                self.app_name = app_name
                self.pid = pid

            def focus(self):
                if not _native.focus_window(self._handle):
                    raise RuntimeError("the window is gone, or its list is too old")

            def __repr__(self):
                return "Window(" + repr(self.app_name) + ", " + repr(self.title) + ")"

        class Candidate:
            """One launcher row. action is a function without arguments, or None."""

            def __init__(self, title, action=None):
                self.title = title
                self.action = action

        def windows():
            records = json.loads(_native.list_windows())
            return [Window(w["handle"], w["title"], w["app_name"], w["pid"]) for w in records]

        # Insertion order is the display order, and a source added again keeps its place.
        _sources = {}
        # Only the latest two generations of actions stay callable, so that memory stays
        # bounded and a row listed just before a refresh still works.
        _state = {"generation": 0, "actions": {}}

        def add_source(name, candidates):
            if not callable(candidates):
                raise TypeError("candidates must be a function that returns a list")
            _sources[name] = candidates

        def remove_source(name):
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
            return json.dumps({"generation": generation, "items": items, "errors": errors})

        def _run_action(generation, index):
            actions = _state["actions"].get(generation)
            if actions is None or index < 0 or index >= len(actions):
                return False
            actions[index]()
            return True
        """#
}
