# JSON Schema Test Suite (vendored)

This directory contains the test data of the official
[JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite).

- Upstream: https://github.com/json-schema-org/JSON-Schema-Test-Suite
- Branch: `main`
- Commit: [`3f05891cac5d51ffa068d7076d1372130e00c829`](https://github.com/json-schema-org/JSON-Schema-Test-Suite/tree/3f05891cac5d51ffa068d7076d1372130e00c829) (2026-10-31)
- License: MIT, Copyright (c) 2012 Julian Berman, see [`LICENSE`](LICENSE)

## Contents

Only the JSON test data was copied; the upstream tooling (`bin/`, CI
configuration, `package.json`, …) and its Markdown documentation were not.

| Path | Description |
|---|---|
| `tests/` | Validation tests per specification version (`draft3` … `draft2020-12`, `v1`); `tests/latest` is a symlink to `draft2020-12` |
| `remotes/` | Schemas that tests reference remotely, upstream served from `http://localhost:1234/` |
| `output-tests/` | Tests for the output formats |
| `annotations/` | Annotation tests and their schemas |
| `test-schema.json` | Schema of the files in `tests/` |
| `output-test-schema.json` | Schema of the files in `output-tests/` |

The files are unchanged. To update, copy the same paths from a newer upstream
commit and update the commit above.
