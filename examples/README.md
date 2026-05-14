# Examples

Examples are split by responsibility so engine samples can grow without
coupling to one another.

```text
engines/<engine>/        engine adapters, runnable projects, and engine code
worlds/<world>/          reusable fixtures and authored world content
```

An engine sample should depend on Gloam through the public protocol, not by
reaching into server internals. Shared world fixtures should stay transport
neutral so Godot, Unity, Unreal, terminal, browser, or custom clients can reuse
the same content.
