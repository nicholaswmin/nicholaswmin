# just another post

21-11-2023

This is another sample post, written in **Markdown**.

You can add as many as you want in this folder but ensure each post:

- has an `h1` heading at the very top
- has an empty line following it
- and a date on the 3rd line

... just like this post.

Posts have special attributes:

- they appear in the post list, on the homepage.
- they include syntax highlighting via [pygments][pygments]

For example, this is a Fibonacci series function in:

### Python

```python
def F(n): if n == 0:
return 0 if n == 1:
return 1 else:
return F(n-1) + F(n-2)
```

### Javascript

```js
function fibonacci(n) {
   return n < 1 ? 0
        : n <= 2 ? 1
        : fibonacci(n - 1) + fibonacci(n - 2)
}
```

### Swift

```swift
extension Player: Codable, Equatable {}

import Foundation
let encoder = JSONEncoder()
try encoder.encode(player)

print(player)
```

and here's some bash code:

```bash
chmod 755 myscript.sh && cd alpine
```

[pygments]: https://pygments.org/
