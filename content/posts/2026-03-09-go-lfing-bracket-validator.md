+++
date = '2026-03-09T11:47:31+05:30'
draft = true
title = 'Go-lfing: Bracket Validator'
tags = ['go', 'golf']
+++

---
## An oasis in desert
I'm a month into my sabbatical right now and I'm realising that doing nothing
gets boring pretty fast. I love coding challenges where I need to optimise for
something, and in my quest to find such problems to kill time, I came across
[this](https://www.youtube.com/post/UgkxzAlMqieZW9GTFwoi-c5vnhG8ntzmrVK-):
<blockquote>
Write a bracket validator that correctly handles (),{}, and [] in as few
characters as possible.
</blockquote>

The original problem was for python but I'll attempt it in Go.

<details>
	<summary>Go-lfing</summary>
	Code golf<sup>[<a id="anchor-0-src" href="#anchor-0-dest">0</a>]</sup>-ing
	in Go.
</details>

---

## Constraints and assumptions

1. I'll write a function that takes a string as input, and returns true if 
the string is a valid bracket pattern, otherwise false.
2. <span id="assumption-2"></span>The string will only contain characters from set "(){}[]".

## Iteration #0: Baseline (307)

```go
package g

func f(s string) bool {
	m := map[rune]rune{')': '(', '}': '{', ']': '['}
	b := []rune{}
	for _, c := range s {
		// if open bracket: push to stack
		if c == '(' || c == '{' || c == '[' {
			b = append(b, c)
		// if closing bracket: compare matching pair with top of the stack
		} else if l := len(b) - 1; l == -1 || m[c] != b[l] { 
			return false
		} else {
			b = b[:l]
		}
	}
	return len(b) == 0
}
```
This is a standard bracket validator solution. We use a stack to keep
track of the opening brackets, and then match the closing pairs. (I won't
go into the solution here; you can take your pick of hundreds of blogs/youtube
videos that already explain this). This code is formatted with `go fmt`, and I
did not try to make this code short in any way except using single-character
names for everything. 

So, the baseline is 307 characters. Let's see how much we can reduce this.

---
## Iteration #1 (301)

Runes can also be represented with their ascii values. (I'm being liberal
with using "ascii value" in rune context because the input string has only
ascii characters.)
```go
var r0 rune = '(' // '(' is 3 characters long
var r1 rune = 40  // 40 is 2 characters long
```
This saves us 1 character if ascii value is less than 100.
```diff
  ...
-	m := map[rune]rune{')': '(', '}': '{', ']': '['}
+	m := map[rune]rune{41: 40, 93: 91, 125: 123}
  ...
-		if c == '(' || c == '{' || c == '[' {
+		if c == 40 || c == 91 || c == 123 {
  ...

```
All in all, we save 6 characters.  

**Character count: 301(-6)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/8b7867424e34a6db97d52de098d8d8dc15d8ca88#diff-1366140ce5704c8e97606a6bde609a6297d518bbea62835d4cf522ea0bee7d08L1)

---

## Iteration #2: Index instead of append (294)
Instead of appending and shrinking the slice, we can use an index to keep track
of the top of the stack.

```diff
...
-	b := []rune{}
+	b := make([]rune, len(s))
+	l := -1
	for _, c := range s {
		if c == 40 || c == 91 || c == 123 {
- 			b = append(b, c)
+			l++
+			b[l] = c
-		} else if l := len(b) - 1; l == -1 || m[c] != b[l] {
+		} else if l == -1 || m[c] != b[l] {
			return false
		} else {
-			b = b[:l]
+			l--
...
```

**Character count: 294(-7)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/240b1a910ed833ce4b88544cf1a264d8085e24cf#diff-1366140ce5704c8e97606a6bde609a6297d518bbea62835d4cf522ea0bee7d08L1)

---

## Iteration #3: Getting rid of else block (285)
At first I replaced else block with goto:
```diff
		for ... {
			if ... {
				...
+				goto e
			} else if ... {
			...
-			} else {
-				l--
			}
+			l--
+	e:
		}
...
```
but then I realised, I can add an additional `l++` in if block to offset `l--`
and remove goto as well.
```diff
		for ... {
			if ... {
				...
+				l++
			} else if ... {
			...
-			} else {
-				l--
			}
+			l--
		}
...
```

**Character count: 285(-9)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/compare/240b1a910ed833ce4b88544cf1a264d8085e24cf..c0518555c5a4ec7efa83e2cef0d354a9dbc52089#diff-1366140ce5704c8e97606a6bde609a6297d518bbea62835d4cf522ea0bee7d08L8)

---
## Iteration #4: A little *bit* of magic
I love bit manipulation. I'm always looking for some bit magic in
the wild.

Let's take a look at the binary representations of all the characters:
```text
char | ascii | binary
----------------------
  (  |   40  | 00_10_10_00
  )  |   41  | 00_10_10_01

  {  |   91  | 01_01_10_11
  }  |   93  | 01_01_11_01

  [  |  123  | 01_11_10_11
  ]  |  125  | 01_11_11_01

```
We'll make two observations here:
1. `c&3 != 1` for the opening brackets. With this we can considerably shorten
the open bracket check in the if statement:  
	```diff
	// open bracket match
	- if c == 40 || c == 91 || c == 123 {
	+ if c&3 != 1 {
	```
2. `c>>6`
	1. = 0 for ')'.
	2. = 1 for '}' or ']'


	We can use this to get rid of the map for pair matching:
	```diff
	// matching pair check for closing bracket
	-	m := map[rune]rune{41: 40, 93: 91, 125: 123}
	...
	- 	} else if l < 0 || m[c] != b[l] {
	+ 	} else if l < 0 || c-1-c>>6 != b[l] {
	```
	<details>
		<summary>Detailed explanation</summary>

		With simple arithmetic, we can get the matching bracket from the closing
		bracket.

		c - 1 - (c>>6)
			= 40  for c = 41
			= 91  for c = 93
			= 123 for c = 125

		We then simply compare it with the top of the stack. If not equal, return.
		else if ... || c - 1 - c>>6 != b[l-1] {
			return false
		}
	</details>

**Character count: 221(-64)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/18c7e69d8524bc3db0d89527fa90dbd282f4b8cf)

---
## Iteration #5: Eliminate out of bounds check

A little bit of tweaking can eliminate the out of bounds check in the else if
condition(`l < 0`):
```diff
-	b := make([]rune, len(s))
+	b := make([]rune, len(s)+1)
-	l := -1
+	l := 1
	for _, c := range s {
		if c&3 != 1 {
-			l++
			b[l] = c
-			l++
+			l+=2
-		} else if l < 0 || c-1-c>>6 != b[l] {
+		} else if c-1-c>>6 != b[l-1] {
			return false
		}
		l--
	}
-	return l == 0
+	return l == 1
```

We start the stack from index 1 instead of 0. When l becomes 0 (i.e. stack is
empty) and we encounter a closing bracket(i.e. invalid matching),
`c-1-c>>6 != b[0]` will hold true for all closing brackets, because b[0] = 0.
This will lead to an early return and therefore removes the need for explicit
out of bounds check.

**Character count: 211(-10)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/ece78c9d2961e7e9251235e7bef36132b9fba2d0)

---

## Iteration #5.5: Little Drops of Water

1. `false` can be written as `0>1` which saves 2 characters.
	```diff
	- return false
	+ return 0>1
	```
2. Since i = 0 state leads to an early return in else if, the final return
return can be written as
	```diff
	- return l == 1
	+ return l < 2
	```
	This saves 1 character.
3. `c-1-c>>6 != b[l-1]` can be replaced with another condition that holds true by
virtue of assumption <a href="#constraints-and-assumptions">#2</a>:
	```diff
	-	} else if c-1-c>>6 != b[l-1] {
	+	} else if c^b[l-1] > 6 {
	```

	<details>
    <summary>Detailed explanation</summary>

    I'll just list all possible pairings:  

		 41 ^  40 = 1
		 93 ^  91 = 6
		125 ^ 123 = 6

		41 ^ 91  = 114
		41 ^ 123 = 82
		93 ^ 40  = 117
		93 ^ 123 = 38
		125 ^ 40 = 85
		125 ^ 91 = 38

	As you can see, for matching pairs the xor is < 7.
  </details>
```

**Character count: 201(-10)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/4ff4255157060ff77f970575899ca8b44ad441d1)

---
## Iteration #6: Minify

I finally minified the code because at this point I couldn't think of any other
improvements.
```go
package g;func f(s string)bool{b,l:=make([]rune,len(s)+1),1;for _,c:=range s{if c&3!=1{b[l]=c;l+=2}else if c^b[l-1]>6{return 0>1};l--};return l<2}
```
**Character count: 147(-54)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/83181cd097c9714d9adbe1062630d4e401034693)

---
## Iteration #7: Remove early return

Instead of doing an early return, I used an accumulator(I'm showing un-minified
diff, although I was working with minified code at this point.):
```diff
+	z := 0<1
	for ... {
		if ... {
			...
-			l += 2
+			l++
-		} else if c^b[l-1] > 6 {
-			return 0>1
+		} else {
+			z = z && c^b[l-1] < 7
+			l--
		}
-		l--
	}
- return l < 2
+ return l < 2 && z
```

**Character count: 144(-3)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/fe98a8aa0b3fbe1f356a65361007a5ae2bc112a0)

---
## Iteration #8: Make it short, not fast
Iteration #7 was a breakthrough. Even though the code is much less efficient, it is
better in the context of the challenge. This gave me a mental shift: make it
short, not fast (said no one ever).

There's another solution for bracket validation, but it is much much worse than
this stack based solution(again, I'm showing the un-minified version):
```go
import "strings"
func f(s string) bool {
	r := strings.NewReplacer("()","","{}","","[]","")
	l := 0
	for l != len(s) {
		l = len(s)
		s = r.Replace(s)
	}
	return l == 0
}
```
What it does is that it keeps replacing "()", "{}", "[]" in the string with
empty string, until there are no matches. If the string is empty in the end,
the original string was valid.

<details>
<summary>Detailed explanation</summary>
Proof is left as an exercise for the reader.
</details>

Also, importing to global namespace saves a few characters:
```diff
-	import "strings"
+	import."strings"
...
-	r := strings.NewReplacer("()","","{}","","[]","")
+	r := NewReplacer("()","","{}","","[]","")
```

This version (minified) saved a whopping 1 character over the previous one.  

**Character count: 143(-1)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/e81c056cd54a16574e8ff6ad257a9ff47b269720)

---
## Iteration #9: Make it worse!
I'll let the diff speak for itself:

```diff
func f(s string) bool {
-	r := NewReplacer("()","","{}","","[]","")
	l := 0
	for l != len(s) {
		l = len(s)
-		s = r.Replace(s)
+		s = NewReplacer("()","","{}","","[]","").Replace(s)
	}
	return l == 0
}
```
**Character count: 139(-4)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/cc9a12496586c61bf2ae6729342061b82aac1ce3)

---
## Iteration #10: Eliminate len
```diff
-	l := 0
+	z := ""
-	for l != len(s) {
+	for z != s {
-		l = len(s)
+		z = s
		s = NewReplacer("()","","{}","","[]","").Replace(s)
	}
-	return l == 0
+	return s == ""
```
**Character count: 132(-7)**  
[[git diff]](https://github.com/imperfect-fourth/go-lfing/commit/e999d8c4107d66591b03a9d09e8684dee87b701e)

---
## All good things must come to an end.

This gave me a reprieve from my boredom for a couple of days. I begin my quest
anew for more mentally stimulating challenges.

---
## PS

If someone showed you this code and said that this does bracket validation,
would you believe them?
```go
package g

func f(s string) bool {
	b, l := make([]rune, len(s)+1), 1
	for _, c := range s {
		if c&3 != 1 {
			b[l] = c
			l += 2
		} else if c^b[l-1] > 6 {
			return 0>1
		}
		l--
	}
	return l < 2
}
```
---

\[<a id="anchor-0-dest" href="#anchor-0-src">0</a>]: https://en.wikipedia.org/wiki/Code_golf
