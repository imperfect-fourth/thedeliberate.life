+++
date = '2026-02-11T14:46:13+05:30'
draft = true
tags = ['Go']
title = 'Logical shifts and Arithmetic shifts'
+++

---
Here's a small exercise for you. What's the output for the following piece of
Go code:

```go
n := int64(1)
fmt.Println((n<<63) >> 63)
```

Take your time. Think about this hard. Ready?
<details>
  <summary>Reveal answer</summary>
-1
</details>

Wait what? You don't believe me? Check it out for yourself on the [Go playground](https://go.dev/play/p/FjcKgYH2bmx).

This should have been a no-op. Then why did we not get 1?

---
## So, what's happening?

Let's do this again, but this time with **uint64** instead of **int64**.

```go
u := uint64(1)
fmt.Println((u<<63) >> 63) // 1
```

The different behaviour with **uint** and **int** is because Go does a
[logical shift](https://en.wikipedia.org/wiki/Logical_shift)
for unsigned integers, but an [arithmetic shift](https://en.wikipedia.org/wiki/Arithmetic_shift)
for signed.

---
### Logical shifts
Let's first understand the simple logical shift in unsigned integers.

```golang
u := uint8(129) // 0b10000001
u <<= 7         // 0b10000000
u >>= 1         // 0b01000000
u >>= 6         // 0b00000001
```
Right-shifts "empty" the most significant bits, which are filled-in with 0. Similarly, left-shifts "empty" the least significant bits which are filled-in with 0.

Everything as expected.

---
### Arithmetic shifts

First thing to note is that signed integers are stored in 2's complement<sup>[<a id="anchor-2-src" href="#anchor-2-dst">1</a>]</sup>
form, where the most significant bit is the sign bit(1 for negative and 0 for positive integers).

Second is that, a right-shift is essentially a division by 2, and a left-shift
is multiplication by 2.

For a positive integer, the behaviour is same as logical shift(emptied bits are filled-in with 0.)
```golang
n := int8(15) // 0b00001111 (signed bit is 0)
n >>= 2       // 0b00000011 (signed bit is 0. n = 3, 15/2² = 3)
```

For a negative integer,
```golang
n := int8(1) // 0b00000001 (signed bit is 0)
n <<= 7      // 0b10000000 (signed bit is now 1. n = -128)

// signed bit "preserved" on right-shift
n >>= 1      // 0b11000000 (signed bit is 1. n = -64)
n >>= 6      // 0b11111111 (signed bit is 1. n = -1)
```

Simply put, arithmetic shifts "preserve"<sup>[<a id="anchor-1-src" href="#anchor-1-dst">**\***</a>]</sup>
"signed-ness", whereas logical shifts don't.

And here's how the math works out. 7-bit left-shift is equivalent to multiply by 2⁷:
```text
1 * 2⁷ = 128
```
128 is outside of int8 range, so the value essentially overflows to -128.

7-bit right-shift is equivalent to division by 2⁷, and we get:
```text
-128 / 2⁷ = -1
```

---
### What about left shifts?

There are arithmetic left-shifts and logical left-shifts as well, but the
behaviour ends up being the same. Here's an example.

```golang
// unsigned
n := uint8(193) // 0b11000001
n <<= 1         // 0b10000010 (n = 130)
n <<= 1         // 0b00000100 (n = 4)

// signed
n := int8(-63) // 0b11000001
n <<= 1        // 0b10000010 (n = -126)
n <<= 1        // 0b00000100 (n = 4)
```
In both cases, the signed bit is lost after the second left-shift. The values
overflow as intended.

[<a id="anchor-1-dst" href="#anchor-1-src">*</a>] So, technically,
arithmetic shifts don't "preserve" the signed bit in right-shift. The behaviour
is simply the outcome of signed integer arithmetic in 2's complement form.

---
[<a id="anchor-2-dst" href="#anchor-2-src">1</a>]: [Two's complement](https://en.wikipedia.org/wiki/Two%27s_complement)
