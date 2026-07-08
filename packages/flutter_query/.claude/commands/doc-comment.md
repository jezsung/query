# Write Doc Comments

Write or improve documentation comments following Effective Dart Documentation guidelines below.

## Comments

### DO format comments like sentences

Capitalize the first word (unless it's case-sensitive identifier), end with a period.

```dart
// Not if anything comes before it.
if (_chunks.isNotEmpty) return false;
```

### DON'T use block comments for documentation

```dart
// Good
void greet(String name) {
  // Assume we have a valid name.
  print('Hi, $name!');
}

// Bad
void greet(String name) {
  /* Assume we have a valid name. */
  print('Hi, $name!');
}
```

## Doc Comments

### DO use `///` doc comments to document members and types

```dart
// Good
/// The number of characters in this chunk when unsplit.
int get length => ...

// Bad
// The number of characters in this chunk when unsplit.
int get length => ...
```

### CONSIDER writing a library-level doc comment

```dart
/// A really great test library.
@TestOn('browser')
library;
```

### DO start doc comments with a single-sentence summary

```dart
// Good
/// Deletes the file at [path] from the file system.
void delete(String path) {
  ...
}

// Bad - too much detail upfront
/// Depending on the state of the file system and the user's permissions,
/// certain operations may or may not be possible. If there is no file at
/// [path] or it can't be accessed, this function throws either [IOError]
/// or [PermissionError], respectively. Otherwise, this deletes the file.
void delete(String path) {
  ...
}
```

### DO separate the first sentence into its own paragraph

```dart
// Good
/// Deletes the file at [path].
///
/// Throws an [IOError] if the file could not be found. Throws a
/// [PermissionError] if the file is present but could not be deleted.
void delete(String path) {
  ...
}

// Bad
/// Deletes the file at [path]. Throws an [IOError] if the file could not
/// be found. Throws a [PermissionError] if the file is present but could
/// not be deleted.
void delete(String path) {
  ...
}
```

### AVOID redundancy with surrounding context

```dart
// Good
class RadioButtonWidget extends Widget {
  /// Sets the tooltip to [lines].
  ///
  /// The lines should be word wrapped using the current font.
  void tooltip(List<String> lines) {
    ...
  }
}

// Bad - restates obvious context
class RadioButtonWidget extends Widget {
  /// Sets the tooltip for this radio button widget to the list of strings in
  /// [lines].
  void tooltip(List<String> lines) {
    ...
  }
}
```

### PREFER starting comments of a function or method with third-person verbs if its main purpose is a side effect

```dart
/// Connects to the server and fetches the query results.
Stream<QueryResult> fetchResults(Query query) => ...

/// Starts the stopwatch if not already running.
void start() => ...
```

### PREFER starting a non-boolean variable or property comment with a noun phrase

```dart
/// The current day of the week, where `0` is Sunday.
int weekday;

/// The number of checked buttons on the page.
int get checkedCount => ...
```

### PREFER starting a boolean variable or property comment with "Whether" followed by a noun or gerund phrase

```dart
/// Whether the modal is currently displayed to the user.
bool isVisible;

/// Whether the modal should confirm the user's intent on navigation.
bool get shouldConfirm => ...

/// Whether resizing the current browser window will also resize the modal.
bool get canResize => ...
```

### PREFER a noun phrase or non-imperative verb phrase for a function or method if returning a value is its primary purpose

```dart
/// The [index]th element of this iterable in iteration order.
E elementAt(int index);

/// Whether this iterable contains an element equal to [element].
bool contains(Object? element);
```

### DON'T write documentation for both the getter and setter of a property

```dart
// Good - only document the getter
/// The pH level of the water in the pool.
///
/// Ranges from 0-14, representing acidic to basic, with 7 being neutral.
int get phLevel => ...
set phLevel(int level) => ...

// Bad - documenting both (setter docs will be discarded)
/// The depth of the water in the pool, in meters.
int get waterDepth => ...

/// Updates the water depth to a total of [meters] in height.
set waterDepth(int meters) => ...
```

### PREFER starting library or type comments with noun phrases

```dart
/// A chunk of non-breaking output text terminated by a hard or soft newline.
///
/// ...
class Chunk {
   ...
}
```

### CONSIDER including code samples in doc comments

````dart
/// The lesser of two numbers.
///
/// ```dart
/// min(5, 3) == 3
/// ```
num min(num a, num b) => ...
````

### DO use square brackets in doc comments to refer to in-scope identifiers

```dart
/// Throws a [StateError] if ...
///
/// Similar to [anotherMethod()], but ...

/// Similar to [Duration.inDays], but handles fractional days.

/// To create a point, call [Point.new] or use [Point.polar] to ...
```

### DO use prose to explain parameters, return values, and exceptions

```dart
// Bad - JavaDoc style
/// Defines a flag with the given name and abbreviation.
///
/// @param name The name of the flag.
/// @param abbr The abbreviation for the flag.
/// @returns The new flag.
/// @throws ArgumentError If there is already an option with
///     the given name or abbreviation.
Flag addFlag(String name, String abbreviation) => ...

// Good - prose style
/// Defines a flag with the given [name] and [abbreviation].
///
/// The [name] and [abbreviation] strings must not be empty.
///
/// Returns a new flag.
///
/// Throws a [DuplicateFlagException] if there is already an option named
/// [name] or there is already an option using the [abbreviation].
Flag addFlag(String name, String abbreviation) => ...
```

### DO put doc comments before metadata annotations

```dart
// Good
/// A button that can be flipped on and off.
@Component(selector: 'toggle')
class ToggleComponent {}

// Bad
@Component(selector: 'toggle')
/// A button that can be flipped on and off.
class ToggleComponent {}
```

## Markdown

### PREFER backtick fences for code blocks

````dart
// Good
/// You can use [CodeBlockExample] like this:
///
/// ```dart
/// var example = CodeBlockExample();
/// print(example.isItGreat); // "Yes."
/// ```

// Bad - four-space indentation
/// You can use [CodeBlockExample] like this:
///
///     var example = CodeBlockExample();
///     print(example.isItGreat); // "Yes."
````

### AVOID using markdown excessively

Formatting exists to illuminate your content, not replace it. Words are what matter.

### AVOID using HTML for formatting

HTML is rarely necessary; if content is too complex for Markdown, reconsider expressing it.

## Writing

### PREFER brevity

Be clear, precise, and concise.

### AVOID abbreviations and acronyms unless obvious

Avoid "i.e.", "e.g.", "et al." and similar terms.

### PREFER using "this" instead of "the" to refer to a member's instance

```dart
class Box {
  /// The value this box wraps.
  Object? _value;

  /// Whether this box contains a value.
  bool get hasValue => _value != null;
}
```

$ARGUMENTS
