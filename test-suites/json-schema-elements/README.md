# JSON Schema Test Suite in the JSON elements format (generated)

The tests of the [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite)
from [`../json-schema/tests`](../json-schema/tests), split into one XML file per
schema and per test case like [`../json-schema-xml`](../json-schema-xml), but in
the JSON elements format of [`xslt/json-elements.xslt`](../../xslt/json-elements.xslt):
object members are elements named after their keys, and the JSON type is the
attribute `type` (absent for strings). Do not edit these files; regenerate them.

- Source: [`../json-schema/`](../json-schema/), upstream commit
  `3f05891cac5d51ffa068d7076d1372130e00c829`
- License: MIT, Copyright (c) 2012 Julian Berman, see [`LICENSE`](LICENSE)

## Layout

| File | Content |
|---|---|
| `tests/<version>/<name>/<group>/schema.xml` | the group's schema, document element `json` |
| `tests/<version>/<name>/<group>/test-<test>.xml` | one test case: `description`, `data`, `valid` |

For example, a test case:

```xml
<json type="object">
  <description>match</description>
  <data type="object">
    <bar type="number">3</bar>
  </data>
  <valid type="boolean">true</valid>
</json>
```

Keys that are not XML names are encoded as `_xHHHH_` (`$ref` is `_x0024_ref`,
`first name` is `first_x0020_name`); see `json-elements.xslt`.

## Regenerate

With [go-xslt](https://github.com/tim-riep/go-xslt), from the repository root:

```bash
rm -rf test-suites/json-schema-elements/tests
go-xslt transform -s xslt/json-schema-test-suite-to-xml.xslt \
  -it xsl:initial-template -allow-dir test-suites/json-schema \
  -d test-suites/json-schema-elements -p format=elements \
  -p "files=$(cd test-suites/json-schema && find tests -name '*.json' | sort)"
```
