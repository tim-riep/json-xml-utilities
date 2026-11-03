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
<xs:include schemaLocation="../../../../json-elements.xsd"/>
<xs:element name="json">
  <xs:alternative test="@type = 'object'" type="root.object"/>
  <xs:alternative test="@type = 'array'" type="jx.array"/>
  …
  <xs:alternative type="xs:error"/>
</xs:element>
<xs:complexType name="root.object">
  <xs:all>
    <xs:element name="foo">
      <xs:alternative test="@type = 'number'" type="properties.foo.number"/>
      <xs:alternative type="xs:error"/>
    </xs:element>
  </xs:all>
  <xs:attribute name="type" type="xs:string" fixed="object" use="required"/>
</xs:complexType>
```

Types are named after the path of their schema (`properties.foo.number`,
`defs.node.object` for `$defs/node`, `root.object` for the schema itself), so
recursive schemas such as a tree of nodes become recursive types.

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

## Other schema documents

A schema that refers to another schema document gets that document as an XSD
of its own, included with `xs:include`:

| Path | Content |
|---|---|
| `remotes/<dialect>/<path>.xsd` | a remote schema (`http://localhost:1234/<path>.json`, from [`../json-schema/remotes`](../json-schema/remotes)) or a meta-schema (`remotes/<dialect>/json-schema.org/...`), types named `<path>.<...>`, e.g. `integer.root.number` |
| `json-elements.xsd` | the generic types `jx.object`, `jx.array`, `jx.string`, `jx.number`, `jx.boolean`, `jx.null`, `jx.any` |

A remote XSD holds the types of all schemas of its document, so every test
group that refers to it uses the same file. The dialect is part of the path
because a remote without `$schema` is read in the dialect of the schema that
refers to it.

## Results

```bash
go run ./tools/jsonschema-testrunner -format elements
```

All 11847 tests pass, as in the W3C representation (see
[`../json-schema-xsd`](../json-schema-xsd/README.md#results)).

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
