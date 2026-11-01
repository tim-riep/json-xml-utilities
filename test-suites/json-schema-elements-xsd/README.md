# JSON Schema Test Suite as structural XSD 1.1 (generated)

One XSD 1.1 schema per test group of the
[JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite),
compiled from [`../json-schema-elements`](../json-schema-elements) by
[`xslt/json-schema-to-xsd.xslt`](../../xslt/json-schema-to-xsd.xslt) with
`instance-format=elements`. Do not edit these files; regenerate them.

- Source: upstream commit `3f05891cac5d51ffa068d7076d1372130e00c829`
- License: MIT, Copyright (c) 2012 Julian Berman, see [`LICENSE`](LICENSE)

## What the schemas look like

Instances are in the JSON elements format of
[`xslt/json-elements.xslt`](../../xslt/json-elements.xslt), so objects can be
described with ordinary element declarations. The schema

```json
{ "properties": { "foo": { "type": "integer" } }, "required": ["foo"],
  "additionalProperties": false }
```

becomes (abridged)

```xml
<xs:element name="json">
  <xs:alternative test="@type = 'object'" type="t1.object"/>
  <xs:alternative test="@type = 'array'" type="jx.array"/>
  …
  <xs:alternative type="xs:error"/>
</xs:element>
<xs:complexType name="t1.object">
  <xs:all>
    <xs:element name="foo">
      <xs:alternative test="@type = 'number'" type="t2.number"/>
      <xs:alternative type="xs:error"/>
    </xs:element>
  </xs:all>
  <xs:attribute name="type" type="xs:string" fixed="object" use="required"/>
</xs:complexType>
```

- `xs:alternative` on `@type` selects the type for each JSON type
  (`t<i>.<kind>` for a schema's own constraints, the generic `jx.<kind>`
  otherwise, `xs:error` for JSON types the schema rejects).
- `properties` / `required` are the elements of an `xs:all` group, with a
  wildcard unless `additionalProperties` is false; `items` is an `item`
  element; `minLength`, `maxLength`, `pattern` and `enum` are facets; `$ref`
  points to the target's types.
- Constraints XSD has no facet for (numeric limits, `multipleOf`, integers,
  `uniqueItems`, `minProperties`, …) are small `xs:assert`s on the type.
- Subschemas that combine or select schemas (`allOf`, `anyOf`, `oneOf`, `not`,
  `if`, `patternProperties`, `additionalProperties` with a schema,
  `prefixItems`, `contains`, `unevaluated*`, …) get a type `f<i>` whose
  assertion evaluates them, as the schemas in
  [`../json-schema-xsd`](../json-schema-xsd) do for everything.

Of the 2288 schemas, 492 have no assertion at all and 457 only the small
assertions on types. 1339 use assertions for subschemas, 1118 of them for the
whole document: most test groups exist to test exactly these keywords.

## Results

```bash
go run ./tools/jsonschema-testrunner -format elements
```

11845 of 11847 tests pass, the same as in the W3C representation (see
[`../json-schema-xsd`](../json-schema-xsd/README.md#results)); the 2 failures
are the `contentMediaType` tests of `draft7/optional/content`.

## Regenerate

From the repository root (`-allow-network` fetches the meta-schemas that 11
groups reference):

```bash
rm -rf test-suites/json-schema-elements-xsd/tests
go-xslt transform -s xslt/json-schema-to-xsd.xslt -it xsl:initial-template \
  -allow-dir test-suites -allow-network -d test-suites/json-schema-elements-xsd \
  -p instance-format=elements -p input-dir=../test-suites/json-schema-elements/ \
  -p "files=$(cd test-suites/json-schema-elements && find tests -name schema.xml | sort)"
```
