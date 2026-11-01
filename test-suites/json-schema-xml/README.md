# JSON Schema Test Suite as XML (generated)

The tests of the [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite)
from [`../json-schema/tests`](../json-schema/tests), split into one XML file per
schema and per test case. Do not edit these files; regenerate them.

- Source: [`../json-schema/`](../json-schema/), upstream commit
  `3f05891cac5d51ffa068d7076d1372130e00c829`
- License: MIT, Copyright (c) 2012 Julian Berman, see [`LICENSE`](LICENSE)

## Layout

For every test file `tests/<version>/<name>.json` and every test group in it
(numbered from `01`):

| File | Content |
|---|---|
| `tests/<version>/<name>/<group>/schema.xml` | the group's schema |
| `tests/<version>/<name>/<group>/test-<test>.xml` | one test case: `description`, `data`, `valid` (and `comment` where present) |

All files use the W3C XML representation of JSON produced by `fn:json-to-xml()`
(namespace `http://www.w3.org/2005/xpath-functions`). Numbers keep their
original lexical form, and strings or keys with characters that XML cannot
hold keep their JSON escapes, marked with `escaped="true"` or
`escaped-key="true"`. A comment at the top of each file names its source.

## Regenerate

With [go-xslt](https://github.com/tim-riep/go-xslt), from the repository root:

```bash
rm -rf test-suites/json-schema-xml/tests
go-xslt transform -s xslt/json-schema-test-suite-to-xml.xslt \
  -it xsl:initial-template -allow-dir test-suites/json-schema \
  -d test-suites/json-schema-xml \
  -p "files=$(cd test-suites/json-schema && find tests -name '*.json' | sort)"
```

`find` does not follow the `tests/latest` symlink, so that alias of
`draft2020-12` is not converted twice.
