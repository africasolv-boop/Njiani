# Design source

`Njiani Apps.dc.html` is the **source of visual truth** for both apps
(`ARCHITECTURE.md` decision D14). It supersedes the original pitch deck, which
was a clickable prototype rather than a design.

It is committed here so that every future session can see exactly what was
being implemented, without needing access to the Claude Design project. Open it
in a browser — `support.js` beside it is the runtime that renders it.

- 23 screens plus the component gallery, each keyed to a roadmap component
- A build note per screen: purpose, `njiani_core` widgets, states, rules, and
  English/Kiswahili strings
- The token swatch list that `test/design_conformance_test.dart` asserts against

**Do not edit these files here.** They are a copy. Changes belong in the Claude
Design project, after which the copy is refreshed and the conformance test
re-run.
