# JSON Schema Test Suite as XSD 1.1 (generated)

One XSD 1.1 schema per test group of the
[JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite),
compiled from [`../json-schema-xml`](../json-schema-xml) by
[`xslt/json-schema-to-xsd.xslt`](../../xslt/json-schema-to-xsd.xslt).
Do not edit these files; regenerate them.

- Source: upstream commit `3f05891cac5d51ffa068d7076d1372130e00c829`
- License: MIT, Copyright (c) 2012 Julian Berman, see [`LICENSE`](LICENSE)

## Layout

`tests/<version>/<name>/<group>/schema.xsd` belongs to
`../json-schema-xml/tests/<version>/<name>/<group>/schema.xml` and validates
the `data` of the `test-<test>.xml` files next to it, as a document of its own
in the XML representation of `fn:json-to-xml()`. For example, the JSON value
`{"foo": 1}` is the instance

```xml
<map xmlns="http://www.w3.org/2005/xpath-functions">
  <number key="foo">1</number>
</map>
```

The schemas use XPath 3.1 in `xs:assert` and need a validator that accepts
it, such as [go-xslt](https://github.com/tim-riep/go-xslt):

```bash
go-xslt validate -xsd 1.1 -x tests/draft2020-12/ref/01/schema.xsd instance.xml
```

## Results

Each test's `data` validated against its group's schema with go-xslt v0.4.1
and compared with the expected `valid`, by the test runner in
[`tools/jsonschema-testrunner`](../../tools/jsonschema-testrunner). From the
repository root:

```bash
go run ./tools/jsonschema-testrunner
```

Options: `-filter draft2020-12/ref` runs only tests whose path contains the
text, `-v` prints every failed test, `-failures file` writes them to a file,
`-xml` and `-xsd` point to other directories. The exit status is 1 if a test
fails; with `-known test-suites/known-failures.json` the failures listed
there are expected (currently none), and the exit status is 1 only for other
failures or for a listed test that passes.

The workflow [`.github/workflows/conformance.yml`](../../.github/workflows/conformance.yml)
runs daily (and on pushes to main and pull requests): it regenerates all
generated files with the go-xslt version of `go.mod` and checks that the
committed ones are up to date, runs the test suite in both XML
representations with that version and with the latest go-xslt release, and,
on the daily run, also with the current main branch of the upstream test
suite.

The same test suite in the JSON elements format, with XSDs that describe
objects as element declarations, is in
[`../json-schema-elements-xsd`](../json-schema-elements-xsd).

| Tests | Passed |
|---|---|
| draft3 | 437 / 437 |
| draft3 optional | 145 / 145 |
| draft4 | 614 / 614 |
| draft4 optional | 394 / 394 |
| draft6 | 837 / 837 |
| draft6 optional | 523 / 523 |
| draft7 | 925 / 925 |
| draft7 optional | 933 / 933 |
| draft2019-09 | 1257 / 1257 |
| draft2019-09 optional | 1053 / 1053 |
| draft2020-12 | 1298 / 1298 |
| draft2020-12 optional | 1057 / 1057 |
| v1 | 2087 / 2087 |
| v1 optional | 287 / 287 |
| **Total** | **11847 / 11847** |

All tests pass, including the optional ones; `contentMediaType:
application/json` (draft-07) is checked by a JSON parser written in XPath.

Format tests (`optional/format/`, `v1/format/`) are compiled with format
assertion on; everywhere else `format` is an annotation.

## Regenerate

From the repository root (`-allow-network` fetches the meta-schemas that 11
groups reference):

```bash
rm -rf test-suites/json-schema-xsd/tests
go-xslt transform -s xslt/json-schema-to-xsd.xslt -it xsl:initial-template \
  -allow-dir test-suites -allow-network -d test-suites/json-schema-xsd \
  -p "files=$(cd test-suites/json-schema-xml && find tests -name schema.xml | sort)"
```
