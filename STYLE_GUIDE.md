# Swift Style Guide

The app sources follow the [Google Swift Style Guide](https://google.github.io/swift/), with these exceptions:

- Indent with 4 spaces instead of 2, to match the Xcode default and the existing code.
- Pass a closure with its argument label, such as `SettingsSource(openSettings: { ... })`, when the label says what the closure does. A trailing closure hides that label. Keep trailing closures where the label adds nothing, such as `map`, `filter`, and SwiftUI builders like `VStack { ... }` and `.onAppear { ... }`. No tool checks this rule, so reviewers do.

Two tools enforce the guide:

- [swift-format](https://github.com/swiftlang/swift-format) formats the code. Xcode ships it, so it needs no install. `.swift-format` holds its settings.
- [SwiftLint](https://github.com/realm/SwiftLint) checks the rules that swift-format does not. `.swiftlint.yml` holds its settings.

Both tools skip `SomethingTests`.

## Commands

Format the app sources in place:

```bash
mise run format
```

Check the app sources with both tools. Any finding fails the task, and CI runs it on every pull request:

```bash
mise run lint
```

## Formatting

swift-format applies these rules:

- Keep lines at 100 columns or fewer. URLs in comments may exceed the limit.
- Indent continuation lines instead of aligning them with the previous line.
- Write the arguments or parameters of a call or declaration either all on one line or one per line. A vertical list breaks before the first element, and the closing `)` goes on its own line.
- Put `{` on the same line as the statement that opens it.
- Sort imports.
- Put two spaces before an end-of-line `//` comment.

## Rules

SwiftLint checks these rules in addition to its defaults:

- Add a trailing comma after the last element of an array or dictionary literal that spans several lines.
- Put an attribute that takes arguments, such as `@NSApplicationDelegateAdaptor(AppDelegate.self)`, on its own line above the declaration.
- Write `Type(arguments)`, not `Type.init(arguments)`.
- Do not use implicitly unwrapped optionals (`Type!`).
- Do not put an access modifier on an `extension`. Put it on each member instead.
- Do not use `#colorLiteral` or `#imageLiteral`.
- Use `//` and `///` comments, never `/* */` or `/** */`.

No tool checks these rules of the guide, so reviewers do:

- Write `case .pair(let first, let second)`, not `case let .pair(first, second)`.
- Add a comment that states the invariant behind each force unwrap (`!`) and force cast (`as!`).

Swift itself rejects some patterns that other C-family languages allow:

- Braces after `if`, `guard`, `else`, `for`, and `while` are always required.

## Exceptions to the Tools

- Keep a one-element array literal on one line, or bind the element to a constant first. swift-format removes the trailing comma of a multi-line one-element literal, and SwiftLint then reports the missing comma.
- Mark an intentional exception with `// swiftlint:disable:next <rule>` and a comment that states the reason.
