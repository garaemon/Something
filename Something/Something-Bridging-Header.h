#include "pocketpy.h"

// Swift imports neither function-like macros, such as RuntimeError(...) and
// py_checkint(), nor variadic functions, such as py_exception(). These wrappers
// are the non-variadic functions that the native functions of the launcher
// extension API call instead. Each raises a Python exception and returns false,
// like the macros do.

/// Raises RuntimeError with `message`, which is not a format string.
static inline bool something_raise_runtime_error(const char* message) {
    return py_exception(tp_RuntimeError, "%s", message);
}

/// Raises TypeError with `message`, which is not a format string.
static inline bool something_raise_type_error(const char* message) {
    return py_exception(tp_TypeError, "%s", message);
}

/// Returns true when `value` is an int, and raises TypeError otherwise.
static inline bool something_check_int(py_Ref value) {
    return py_checktype(value, tp_int);
}
