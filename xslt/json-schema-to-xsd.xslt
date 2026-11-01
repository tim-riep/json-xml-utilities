<?xml version="1.0" encoding="UTF-8"?>
<!--
  json-schema-to-xsd.xslt

  Compiles a JSON Schema into an XSD 1.1 schema.

  Input and output
  ================
  The input is a JSON Schema as XML, in the W3C representation of
  fn:json-to-xml() (namespace http://www.w3.org/2005/xpath-functions, for
  example a schema.xml of test-suites/json-schema-xml) or in the JSON elements
  format of json-elements.xslt (document element json, for example a
  schema.xml of test-suites/json-schema-elements).

  The output is an XSD 1.1 schema for JSON instances in the XML representation
  chosen with the parameter instance-format:

    xpath     (default) the W3C representation; the instance document is the
              JSON value itself, so its root element is one of map, array,
              string, number, boolean or null
    elements  the JSON elements format; the root element is json, object
              members are elements named after their keys, and the JSON type
              is the attribute type

  Structure (instance-format elements)
  ====================================
  Schemas become element declarations and types wherever XSD can express them:
  properties and required become the elements of an xs:all group (plus a
  wildcard unless additionalProperties is false), items an item element,
  type an xs:alternative per JSON type on @type, minLength, maxLength,
  pattern and enum facets, and $ref named types, so recursive schemas are
  recursive types. Constraints on the node itself that XSD lacks (numeric
  limits, multipleOf, uniqueItems, minProperties, ...) are small xs:asserts on
  the type. Subschemas that combine or select schemas (allOf, anyOf, oneOf,
  not, if, patternProperties, additionalProperties with a schema, contains,
  prefixItems, unevaluated*, $ref next to other keywords from 2019-09 on, ...)
  are evaluated by an assertion as described below; with $dynamicRef or
  $recursiveRef, the whole document is. The parameter structure=no turns the
  structural part off.

  Types are named after the path of their schema in its document:
  properties.foo.number, defs.node.object ($defs/node), root.string (the
  schema itself); .assert is the type whose assertion evaluates the schema.
  Every other schema document a schema refers to (a remote schema, a
  meta-schema) gets an XSD of its own, included with xs:include:

    remotes/<dialect>/<path of its URI>.xsd   types named <path>.<...>,
                                              e.g. integer.root.number
    json-elements.xsd                         the generic types jx.object,
                                              jx.string, ... for unconstrained
                                              JSON types

  These are written next to the output: in batch mode into the output
  directory, in single mode with xsl:result-document (go-xslt: -d, the same
  directory as -o, which must exist). A remote XSD contains the types of all
  schemas of its document, so it is the same for every schema that refers
  to it.

  How the assertions work
  =======================
  Every subschema becomes an XPath 3.1 inline function
  function($S, $n, $dyn) that evaluates it against the instance node $n and
  returns map { 'v': valid, 'p': evaluated property names, 'i': evaluated item
  positions }. The functions are kept in the map $S, so $ref and recursive
  schemas are plain calls ($S?key($S, $n, $dyn)). $dyn is the dynamic scope
  (the schema resources entered so far, outermost first) for $dynamicRef and
  $recursiveRef; 'p' and 'i' carry the annotations unevaluatedProperties and
  unevaluatedItems need. In the xpath format the whole schema is a single
  xs:assert on the root element, and the XSD does not constrain the element
  structure.

  This needs a processor that accepts XPath 3.1 in assertions, such as
  go-xslt (https://github.com/tim-riep/go-xslt).

  Dialect
  =======
  From draft 2019-09 on, a recognised $schema decides the dialect. Otherwise
  (no or an unknown $schema, and always for schemas up to draft-07 that do not
  declare one) the parameter default-dialect applies. In batch mode it is
  taken from the directory name (tests/<dialect>/...).
  Supported: draft3, draft4, draft6, draft7, draft2019-09, draft2020-12, v1.

  References
  ==========
  $ref, $dynamicRef and $recursiveRef are resolved at compile time against
  $id/id, $anchor, $dynamicAnchor and JSON pointers. A URI below remotes-base
  (default http://localhost:1234/) is read from the file of the same path
  below remotes-dir, e.g. http://localhost:1234/foo/bar/baz.json from
  remotes/foo/bar/baz.json. Any other http(s) URI that is not defined in the
  schema itself (such as a meta-schema) is retrieved from the network when the
  processor allows it (go-xslt: -allow-network).

  Formats
  =======
  format is an annotation unless format assertion is switched on: by the
  parameter format-assertion, by a meta-schema with the format-assertion
  vocabulary, or in batch mode for the format test folders of the suite
  (optional/format/ and v1/format/). Supported: date, time, date-time,
  duration, email, idn-email, hostname, idn-hostname (with Punycode and the
  IDNA2008 contextual and Bidi rules), ipv4, ipv6, uri, uri-reference, iri,
  iri-reference, uri-template, json-pointer, relative-json-pointer, uuid,
  regex, and the draft-03 names host-name, ip-address, color.

  Vocabularies
  ============
  A custom meta-schema ($schema) whose $vocabulary lacks the validation
  vocabulary turns off the validation keywords.

  Limits
  ======
  - Control characters such as U+000B are kept in strings (go-xslt holds them
    as XML 1.1 does) and written as codepoints-to-string() in the assertions;
    U+0000 becomes U+FFFD.
  - content* keywords are annotations (draft-07: contentEncoding base64 is
    checked, contentMediaType is not: XPath cannot test whether a string is
    JSON without failing).
  - Patterns are translated from ECMA-262 to XPath regular expressions; lookahead,
    lookbehind and backreferences are not available there.

  Parameters
  ==========
    default-dialect  dialect when $schema does not decide (default draft2020-12)
    base-uri         retrieval URI of the input schema
                     (default http://json-schema.test/schema.json)
    remotes-base     URI prefix of the remote schemas (default http://localhost:1234/)
    remotes-dir      directory for remotes-base, relative to this stylesheet
                     or absolute (default ../test-suites/json-schema/remotes/)
    files            batch mode: whitespace-separated paths of schema.xml files,
                     relative to input-dir; each is written as <path>.xsd
                     (schema.xml -> schema.xsd) into the output directory
    input-dir        batch mode: directory of the files (default
                     ../test-suites/json-schema-xml/)
    format-assertion 'yes' validates format (default: annotation only)
    instance-format  xpath (default) or elements, see above
    structure        elements format: 'no' evaluates everything by assertions

  Run with go-xslt
  ================
  Single schema:

    go-xslt transform -s xslt/json-schema-to-xsd.xslt -allow-dir test-suites \
      -p default-dialect=draft7 -o schema.xsd \
      test-suites/json-schema-xml/tests/draft7/ref/01/schema.xml

    mkdir out && go-xslt transform -s xslt/json-schema-to-xsd.xslt \
      -allow-dir test-suites -p instance-format=elements -p default-dialect=draft7 \
      -d out -o out/schema.xsd \
      test-suites/json-schema-elements/tests/draft7/refRemote/01/schema.xml

  Whole test suite (batch mode):

    go-xslt transform -s xslt/json-schema-to-xsd.xslt -it xsl:initial-template \
      -allow-dir test-suites -allow-network -d test-suites/json-schema-xsd \
      -p "files=$(cd test-suites/json-schema-xml && find tests -name schema.xml | sort)"

  The test suite in the JSON elements format:

    go-xslt transform -s xslt/json-schema-to-xsd.xslt -it xsl:initial-template \
      -allow-dir test-suites -allow-network -d test-suites/json-schema-elements-xsd \
      -p instance-format=elements -p input-dir=../test-suites/json-schema-elements/ \
      -p "files=$(cd test-suites/json-schema-elements && find tests -name schema.xml | sort)"

  Validate an instance:

    go-xslt validate -xsd 1.1 -x schema.xsd instance.xml
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:array="http://www.w3.org/2005/xpath-functions/array"
    xmlns:err="http://www.w3.org/2005/xqt-errors"
    xmlns:c="urn:json-xml-utilities:json-schema-to-xsd"
    xmlns:je="urn:json-xml-utilities:json-elements"
    exclude-result-prefixes="map array err c je">

  <xsl:import href="json-elements.xslt"/>

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:param name="default-dialect" as="xs:string" select="'draft2020-12'"/>
  <xsl:param name="base-uri" as="xs:string" select="'http://json-schema.test/schema.json'"/>
  <xsl:param name="remotes-base" as="xs:string" select="'http://localhost:1234/'"/>
  <xsl:param name="remotes-dir" as="xs:string" select="'../test-suites/json-schema/remotes/'"/>
  <xsl:param name="files" as="xs:string" select="''"/>
  <xsl:param name="input-dir" as="xs:string" select="'../test-suites/json-schema-xml/'"/>
  <xsl:param name="format-assertion" as="xs:string" select="'no'"/>
  <xsl:param name="instance-format" as="xs:string" select="'xpath'"/>
  <xsl:param name="structure" as="xs:string" select="'yes'"/>

  <!-- instances in the JSON elements format of json-elements.xslt -->
  <xsl:variable name="elements" as="xs:boolean" select="$instance-format eq 'elements'"/>

  <xsl:variable name="remotes-uri" as="xs:anyURI" select="c:dir-uri($remotes-dir)"/>
  <xsl:variable name="input-uri" as="xs:anyURI" select="c:dir-uri($input-dir)"/>

  <xsl:variable name="dialects" as="map(xs:string, xs:integer)" select="map {
      'draft3': 3, 'draft4': 4, 'draft6': 6, 'draft7': 7,
      'draft2019-09': 2019, 'draft2020-12': 2020, 'v1': 2100 }"/>

  <xsl:variable name="meta-schemas" as="map(xs:string, xs:integer)" select="map {
      'http://json-schema.org/draft-03/schema': 3,
      'http://json-schema.org/draft-04/schema': 4,
      'http://json-schema.org/draft-06/schema': 6,
      'http://json-schema.org/draft-07/schema': 7,
      'https://json-schema.org/draft/2019-09/schema': 2019,
      'https://json-schema.org/draft/2020-12/schema': 2020,
      'https://json-schema.org/v1': 2100 }"/>

  <!-- ================================================================== -->
  <!-- Entry points                                                       -->
  <!-- ================================================================== -->

  <!-- Single schema: the source document is the schema. -->
  <xsl:template match="/">
    <xsl:variable name="result" select="c:compile(*, c:dialect-number($default-dialect), $base-uri,
        '', $format-assertion = ('yes', 'true', '1'), 'schema.xsd')"/>
    <xsl:sequence select="$result?main"/>
    <!-- the included documents, next to the output (go-xslt: -d) -->
    <xsl:for-each select="map:keys($result?files)">
      <xsl:result-document href="{.}">
        <xsl:sequence select="$result?files(.)"/>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!-- Batch mode: compile every file named in $files. -->
  <xsl:template name="xsl:initial-template">
    <xsl:variable name="paths" as="xs:string*" select="tokenize(normalize-space($files), ' ')"/>
    <xsl:if test="empty($paths)">
      <xsl:message terminate="yes" error-code="c:NOINPUT"
        >No input: give a schema document or set the parameter files.</xsl:message>
    </xsl:if>
    <xsl:variable name="results" as="map(*)*">
      <xsl:for-each select="$paths">
        <xsl:variable name="path" select="."/>
        <xsl:variable name="dialect" as="xs:string"
            select="(analyze-string($path, '(^|/)tests/([^/]+)/')//fn:group[@nr = 2]/string(), $default-dialect)[1]"/>
        <xsl:map>
          <xsl:map-entry key="'path'" select="$path"/>
          <xsl:map-entry key="'xsd'">
            <xsl:try select="c:compile(doc(resolve-uri($path, $input-uri))/*,
                c:dialect-number($dialect), $base-uri, $path,
                $format-assertion = ('yes', 'true', '1') or matches($path, '/format/[^/]+/[^/]+/[^/]+$'),
                replace($path, '\.xml$', '') || '.xsd')">
              <xsl:catch>
                <xsl:message select="'Cannot compile ' || $path || ': ' || $err:code || ' ' || $err:description"/>
              </xsl:catch>
            </xsl:try>
          </xsl:map-entry>
        </xsl:map>
      </xsl:for-each>
    </xsl:variable>
    <xsl:for-each select="$results[exists(?xsd)]">
      <xsl:result-document href="{replace(?path, '\.xml$', '')}.xsd">
        <xsl:sequence select="?xsd?main"/>
      </xsl:result-document>
    </xsl:for-each>
    <!-- included documents (remote schemas, generic types): each once -->
    <xsl:variable name="files" select="map:merge($results[exists(?xsd)] ! ?xsd?files, map { 'duplicates': 'use-first' })"/>
    <xsl:for-each select="sort(map:keys($files))">
      <xsl:result-document href="{.}">
        <xsl:sequence select="$files(.)"/>
      </xsl:result-document>
    </xsl:for-each>
    <xsl:message select="'Compiled ' || count($results[exists(?xsd)]) || ' of '
        || count($paths) || ' schemas.'"/>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- Compiler                                                           -->
  <!-- ================================================================== -->

  <!-- map { 'main': the XSD, 'files': map { location: XSD } of the other
       documents it includes (elements format), locations relative to the
       main XSD's $location }. -->
  <xsl:function name="c:compile" as="map(*)">
    <xsl:param name="root" as="element()"/>
    <xsl:param name="dialect" as="xs:integer"/>
    <xsl:param name="base" as="xs:string"/>
    <xsl:param name="source" as="xs:string"/>
    <xsl:param name="format" as="xs:boolean"/>
    <xsl:param name="location" as="xs:string"/>

    <!-- a schema in the JSON elements format is read as the W3C representation -->
    <xsl:variable name="root" as="element()"
        select="if ($root/self::json) then je:to-xpath-json($root)/* else $root"/>
    <xsl:variable name="d" select="c:detect-dialect($root, $dialect)"/>
    <xsl:variable name="entries" as="map(*)*"
        select="c:closure(c:walk($root, c:strip-fragment($base), (), $d, true(), map { 'noval': false(), 'fmt': $format }), (), $dialect, $format)"/>
    <xsl:variable name="reg" as="map(*)" select="c:registry($entries)"/>

    <xsl:variable name="functions" as="map(xs:string, xs:string)" select="map:merge(
        $entries ! map:entry(c:fkey(?n), c:schema-body(., $reg)), map { 'duplicates': 'use-first' })"/>
    <xsl:variable name="index" as="map(xs:string, xs:integer)" select="map:merge(
        for $i in 1 to count($entries) return map:entry(c:fkey($entries[$i]?n), $i), map { 'duplicates': 'use-first' })"/>

    <xsl:variable name="dynamic-anchors" as="xs:string*">
      <xsl:for-each-group select="$entries[exists(?danchors)]" group-by="?res">
        <xsl:sequence select="c:lit(current-grouping-key()) || ': map { '
            || string-join(distinct-values(current-group() ! (for $a in ?danchors
                   return c:lit($a) || ': ' || c:lit(c:fkey(?n)))), ', ') || ' }'"/>
      </xsl:for-each-group>
    </xsl:variable>
    <xsl:variable name="recursive-anchors" as="xs:string*"
        select="distinct-values($entries[?ranchor] ! (c:lit(?res) || ': ' || c:lit(c:fkey(?n))))"/>
    <xsl:variable name="program" as="map(*)" select="map {
        'functions': $functions, 'index': $index,
        'da': $dynamic-anchors, 'ra': $recursive-anchors,
        'formats': some $e in $entries satisfies ($e?fmt and c:kw($e?n, 'format') = $format-names) }"/>

    <xsl:variable name="description" select="'Generated by json-schema-to-xsd.xslt'
        || (if ($source) then ' from ' || $source else '') || ' (dialect ' || c:dialect-name($d) || '). '"/>

    <xsl:choose>
      <xsl:when test="$elements">
        <xsl:sequence select="c:xsd-elements($root, $entries, $reg, $program,
            $description || 'Validates a JSON instance in the JSON elements format of json-elements.xslt.', $location)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:map>
        <xsl:map-entry key="'files'" select="map {}"/>
        <xsl:map-entry key="'main'">
        <xs:schema targetNamespace="http://www.w3.org/2005/xpath-functions"
            elementFormDefault="qualified" vc:minVersion="1.1"
            xmlns:vc="http://www.w3.org/2007/XMLSchema-versioning">
          <xs:annotation>
            <xs:documentation>
              <xsl:value-of select="$description || 'Validates a JSON instance in the XML representation of fn:json-to-xml().'"/>
            </xs:documentation>
          </xs:annotation>
          <xs:complexType name="json" mixed="true">
            <xs:sequence>
              <xs:any namespace="##any" processContents="skip" minOccurs="0" maxOccurs="unbounded"/>
            </xs:sequence>
            <xs:anyAttribute namespace="##any" processContents="skip"/>
            <xs:assert test="{c:assertion($program, c:fkey($root))}"/>
          </xs:complexType>
          <xsl:for-each select="('map', 'array', 'string', 'number', 'boolean', 'null')">
            <xs:element name="{.}" type="fn:json"/>
          </xsl:for-each>
        </xs:schema>
        </xsl:map-entry>
        </xsl:map>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The assertion that evaluates the schema with function key $key on the
       context node: the helper bindings, the functions it can reach, and the
       call. -->
  <xsl:function name="c:assertion" as="xs:string">
    <xsl:param name="program" as="map(*)"/>
    <xsl:param name="key" as="xs:string"/>
    <xsl:variable name="keys" select="c:reachable($program?functions,
        ($key, ($program?da, $program?ra) ! analyze-string(., 'k_[A-Za-z0-9]+_k')/fn:match/string()), ())"/>
    <xsl:sequence select="c:renumber(string-join((
        'let ' || string-join(c:helpers(('$T', '$num', '$str', '$key', '$isint', '$mult', '$eq', '$xmlesc')), ', '),
        if ($program?formats) then normalize-space($format-functions) else (),
        '$DA := map { ' || string-join($program?da, ', ') || ' }',
        '$RA := map { ' || string-join($program?ra, ', ') || ' }',
        '$S := map { ' || string-join($keys ! (c:lit(.) || ': function($S, $n, $dyn) { ' || $program?functions(.) || ' }'), ', ')
          || ' } return $S(' || c:lit($key) || ')($S, ., ())?v'), ', '),
        map:merge(for $i in 1 to count($keys) return map:entry($keys[$i], $i)))"/>
  </xsl:function>

  <!-- The function keys reachable from $todo. -->
  <xsl:function name="c:reachable" as="xs:string*">
    <xsl:param name="functions" as="map(xs:string, xs:string)"/>
    <xsl:param name="todo" as="xs:string*"/>
    <xsl:param name="done" as="xs:string*"/>
    <xsl:variable name="new" select="distinct-values($todo)[not(. = $done)]"/>
    <xsl:sequence select="if (empty($new)) then $done else c:reachable($functions,
        $new ! (analyze-string($functions(.), 'k_[A-Za-z0-9]+_k')/fn:match/string()), ($done, $new))"/>
  </xsl:function>

  <!-- Function keys k_<generate-id>_k to stable names s<position>. -->
  <xsl:function name="c:renumber" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="index" as="map(xs:string, xs:integer)"/>
    <xsl:sequence select="string-join(analyze-string($text, 'k_[A-Za-z0-9]+_k')/* !
        (if (self::fn:match) then 's' || $index(string(.)) else string(.)))"/>
  </xsl:function>

  <!-- The let bindings of the helper functions $names and of the helpers
       they use, in dependency order. -->
  <xsl:function name="c:helpers" as="xs:string*">
    <xsl:param name="names" as="xs:string*"/>
    <xsl:variable name="all" as="map(xs:string, xs:string)" select="map:merge((
        map {
          '$T': 'map { ''v'': true() }',
          '$num': 'function($n) { let $s := normalize-space(string($n)) return if (not(matches($s, ''[eE]''))) then xs:decimal($s) '
            || 'else let $m := xs:decimal(replace($s, ''[eE].*$'', '''')), $e := xs:integer(replace($s, ''^.*[eE]\+?'', '''')) '
            || 'return if (abs($e) gt 1000) then xs:double($s) '
            || 'else if ($e ge 0) then $m * xs:decimal(''1'' || string-join((1 to $e) ! ''0'')) '
            || 'else $m div xs:decimal(''1'' || string-join((1 to -$e) ! ''0'')) }',
          '$unesc': 'function($s) { string-join(analyze-string($s, ''\\u[dD][89abAB][0-9a-fA-F]{2}\\u[dD][c-fC-F][0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\.'')/* ! '
            || '(if (self::fn:non-match) then string(.) else let $t := string(.), '
            || '$c := if (string-length($t) eq 12) then 65536 + ($hex(substring($t, 3, 4)) - 55296) * 1024 + $hex(substring($t, 9, 4)) - 56320 '
            || 'else if (string-length($t) eq 6) then $hex(substring($t, 3)) '
            || 'else (map { ''b'': 8, ''f'': 12, ''n'': 10, ''r'': 13, ''t'': 9 }(substring($t, 2)), string-to-codepoints(substring($t, 2)))[1] '
            || 'return codepoints-to-string(if ($c eq 0 or ($c ge 55296 and $c le 57343) or $c = (65534, 65535)) then 65533 else $c))) }',
          '$hex': 'function($h) { fold-left(string-to-codepoints(upper-case($h)), 0, function($a, $c) { $a * 16 + (if ($c ge 65) then $c - 55 else $c - 48) }) }',
          '$str': 'function($n) { if ($n/@escaped = ''true'') then $unesc(string($n)) else string($n) }',
          '$isint': 'function($n) { let $x := $num($n) return $x = floor($x) }',
          '$mult': 'function($x, $m) { if ($x instance of xs:double or $m instance of xs:double) then (let $q := xs:double($x) div xs:double($m) return $q = floor($q)) else ($x mod $m = 0) }'
        },
        if ($elements) then map {
          '$key': 'function($n) { let $m := local-name($n) return if ($m eq ''_x_'') then '''' else if (not(contains($m, ''_x''))) then $m '
            || 'else string-join(analyze-string($m, ''_x([0-9A-Fa-f]{8}|[0-9A-Fa-f]{4})_'')/* ! '
            || '(if (self::fn:match) then codepoints-to-string($hex(string(fn:group))) else string(.))) }',
          '$xmlesc': 'function($s) { replace(replace($s, ''&amp;'', ''&amp;amp;''), ''&lt;'', ''&amp;lt;'') }',
          '$eq': 'function($eq, $a, $b) { let $t := string($a/@type) return if ($t ne string($b/@type)) then false() '
            || 'else if ($t eq ''number'') then $num($a) = $num($b) '
            || 'else if ($t eq '''') then $str($a) eq $str($b) '
            || 'else if ($t eq ''boolean'') then normalize-space($a) eq normalize-space($b) '
            || 'else if ($t eq ''null'') then true() '
            || 'else if ($t eq ''array'') then count($a/*) eq count($b/*) and (every $i in 1 to count($a/*) satisfies $eq($eq, $a/*[$i], $b/*[$i])) '
            || 'else count($a/*) eq count($b/*) and (every $x in $a/* satisfies (some $y in $b/*[local-name() eq local-name($x)] satisfies $eq($eq, $x, $y))) }'
        } else map {
          '$key': 'function($n) { if ($n/@escaped-key = ''true'') then $unesc(string($n/@key)) else string($n/@key) }',
          '$eq': 'function($eq, $a, $b) { if (local-name($a) ne local-name($b)) then false() '
            || 'else if ($a/self::fn:number) then $num($a) = $num($b) '
            || 'else if ($a/self::fn:string) then $str($a) eq $str($b) '
            || 'else if ($a/self::fn:boolean) then xs:boolean(normalize-space($a)) eq xs:boolean(normalize-space($b)) '
            || 'else if ($a/self::fn:null) then true() '
            || 'else if ($a/self::fn:array) then count($a/*) eq count($b/*) and (every $i in 1 to count($a/*) satisfies $eq($eq, $a/*[$i], $b/*[$i])) '
            || 'else count($a/*) eq count($b/*) and (every $x in $a/* satisfies (some $y in $b/* satisfies ($key($x) eq $key($y) and $eq($eq, $x, $y)))) }'
        }))"/>
    <xsl:variable name="deps" select="map {
        '$str': '$unesc', '$unesc': '$hex', '$isint': '$num', '$key': if ($elements) then '$hex' else '$unesc',
        '$eq': ('$num', '$str', '$key') }"/>
    <xsl:variable name="closure" select="c:helper-closure($names, $deps)"/>
    <xsl:sequence select="('$T', '$num', '$hex', '$unesc', '$str', '$key', '$isint', '$mult', '$xmlesc', '$eq')
        [. = $closure][map:contains($all, .)] ! (. || ' := ' || $all(.))"/>
  </xsl:function>

  <xsl:function name="c:helper-closure" as="xs:string*">
    <xsl:param name="names" as="xs:string*"/>
    <xsl:param name="deps" as="map(*)"/>
    <xsl:variable name="more" select="distinct-values(($names, $names ! $deps(.)))"/>
    <xsl:sequence select="if (count($more) eq count(distinct-values($names))) then $more else c:helper-closure($more, $deps)"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- Structural XSD for the JSON elements format                       -->
  <!-- ================================================================== -->

  <!--
    In the JSON elements format, object members are elements named after
    their keys and the JSON type is the attribute type (absent for strings).
    Each schema then becomes element declarations and types:

    - an element (the document element json, a member, an array item) gets
      one xs:alternative per JSON type, selected by @type, pointing to the
      type of that kind for its schema (t<i>.object, t<i>.number, ...), or to
      xs:error for kinds the schema does not allow;
    - objects are xs:all groups of their properties (minOccurs 1 for
      required ones) plus a wildcard unless additionalProperties is false;
    - arrays are sequences of item elements (prefixItems as nested optional
      sequences);
    - strings get minLength, maxLength, pattern and enumeration facets,
      booleans an enumeration;
    - what has no XSD equivalent but concerns only the node itself
      (numeric limits, multipleOf, uniqueItems, minProperties, ...) is a small
      xs:assert on the type;
    - schemas that combine or select other schemas (allOf, anyOf, oneOf, not,
      if, patternProperties, additionalProperties with a schema, contains,
      unevaluated*, ...) become a type f<i> whose assertion evaluates the
      whole subschema, as in the xpath format;
    - $ref without other validation keywords points to the target's types,
      so recursive schemas are recursive types.
    Schemas with $dynamicRef or $recursiveRef depend on the dynamic scope and
    are evaluated by one assertion on the document element.
  -->

  <xsl:function name="c:xsd-elements" as="map(*)">
    <xsl:param name="root" as="element()"/>
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:param name="reg" as="map(*)"/>
    <xsl:param name="program" as="map(*)"/>
    <xsl:param name="description" as="xs:string"/>
    <xsl:param name="location" as="xs:string"/>

    <xsl:variable name="dynamic" select="$structure ne 'yes' or exists($entries[
        exists(($program?ra, $program?da)) and exists(c:kw(?n, ('$dynamicRef', '$recursiveRef')))])"/>
    <!-- the URI of each schema document ('' for the input), by its root -->
    <xsl:variable name="docs" as="map(xs:string, xs:string)" select="map:merge((
        map:entry(generate-id($root), ''),
        $entries[empty(?n/parent::*)][not(?n is $root)] ! map:entry(generate-id(?n), head(?uris))),
        map { 'duplicates': 'use-first' })"/>
    <xsl:variable name="ctx" select="map {
        'reg': $reg, 'program': $program, 'dynamic': $dynamic, 'docs': $docs,
        'names': c:type-names($entries, $docs) }"/>

    <xsl:choose>
      <xsl:when test="$dynamic">
        <xsl:variable name="body" as="element()*">
          <xs:element name="json" type="{c:tname($root, $ctx)}.assert"/>
          <xsl:sequence select="c:fallback-type($root, $ctx)"/>
        </xsl:variable>
        <xsl:sequence select="map { 'main': c:xsd-file($body, (), $description, $location, $ctx), 'files': map {} }"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="typed" as="element()*" select="c:all-typed(c:typed-nodes($root, $ctx, ()), $entries, $ctx, ())"/>
        <xsl:variable name="remote-docs" select="distinct-values($typed ! c:doc-of(., $ctx))[. ne '']"/>
        <xsl:variable name="hrefs" as="map(xs:string, xs:string)" select="map:merge((
            map:entry('', $location),
            $remote-docs ! map:entry(., c:remote-href(., $entries, $ctx))))"/>
        <xsl:variable name="files" as="map(xs:string, element(xs:schema))*">
          <xsl:for-each select="('', $remote-docs)">
            <xsl:variable name="doc" select="."/>
            <xsl:variable name="nodes" select="$typed[c:doc-of(., $ctx) eq $doc]"/>
            <xsl:variable name="body" as="element()*">
              <xsl:if test="$doc eq ''">
                <xs:element name="json">
                  <xsl:sequence select="c:element-type($root, $ctx)"/>
                </xs:element>
              </xsl:if>
              <xsl:for-each select="$nodes">
                <xsl:sequence select="if (c:class-of(., $ctx) eq 'fallback') then c:fallback-type(., $ctx)
                    else (c:kind-types(., $ctx), if (c:string-constraints(.)) then c:fallback-type(., $ctx) else ())"/>
              </xsl:for-each>
            </xsl:variable>
            <!-- the documents whose types the declarations use -->
            <xsl:variable name="uses" select="distinct-values((
                (if ($doc eq '') then $root else ()), $nodes[c:class-of(., $ctx) eq 'struct'] ! c:element-schemas(., $ctx))
                ! c:typed(., $ctx)[c:class-of(., $ctx) = ('struct', 'fallback')] ! c:doc-of(., $ctx))[. ne $doc]"/>
            <xsl:sequence select="map:entry($hrefs($doc), c:xsd-file($body, $uses ! $hrefs(.),
                if ($doc eq '') then $description else 'Generated by json-schema-to-xsd.xslt from ' || $doc
                  || ' for schemas that refer to it.', $hrefs($doc), $ctx))"/>
          </xsl:for-each>
        </xsl:variable>
        <xsl:sequence select="map {
            'main': $files[map:contains(., $location)]($location),
            'files': map:merge(($files[not(map:contains(., $location))],
                map:entry('json-elements.xsd', c:generic-xsd()))) }"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- A schema document: includes of the other documents and of the generic
       types it uses, then the declarations. -->
  <xsl:function name="c:xsd-file" as="element(xs:schema)">
    <xsl:param name="body" as="element()*"/>
    <xsl:param name="includes" as="xs:string*"/>
    <xsl:param name="description" as="xs:string"/>
    <xsl:param name="location" as="xs:string"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xs:schema vc:minVersion="1.1" xmlns:vc="http://www.w3.org/2007/XMLSchema-versioning">
      <xs:annotation>
        <xs:documentation>
          <xsl:value-of select="$description"/>
        </xs:documentation>
      </xs:annotation>
      <xsl:if test="exists(($body//@type, $body//@base)[starts-with(., 'jx.')])">
        <xs:include schemaLocation="{c:relative-path($location, 'json-elements.xsd')}"/>
      </xsl:if>
      <xsl:for-each select="sort($includes)">
        <xs:include schemaLocation="{c:relative-path($location, .)}"/>
      </xsl:for-each>
      <xsl:sequence select="$body"/>
    </xs:schema>
  </xsl:function>

  <xsl:function name="c:generic-xsd" as="element(xs:schema)">
    <xs:schema>
      <xs:annotation>
        <xs:documentation>Types for any value of a JSON type in the JSON elements format of json-elements.xslt, included by the schemas json-schema-to-xsd.xslt generates.</xs:documentation>
      </xs:annotation>
      <xsl:sequence select="$generic-types"/>
    </xs:schema>
  </xsl:function>

  <!-- The typed nodes, plus those of every schema document they reach (a
       document's file has the types of all its schemas, so that it is the
       same whichever schema refers to it). -->
  <xsl:function name="c:all-typed" as="element()*">
    <xsl:param name="typed" as="element()*"/>
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:param name="done-docs" as="xs:string*"/>
    <xsl:variable name="new-docs" select="distinct-values($typed ! c:doc-of(., $ctx))[. ne ''][not(. = $done-docs)]"/>
    <xsl:sequence select="if (empty($new-docs)) then $typed
        else c:all-typed(c:typed-nodes($entries[c:doc-of(?n, $ctx) = $new-docs] ! ?n, $ctx, $typed),
            $entries, $ctx, ($done-docs, $new-docs))"/>
  </xsl:function>

  <xsl:function name="c:doc-of" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:sequence select="($ctx?docs(generate-id($n/ancestor-or-self::*[last()])), '')[1]"/>
  </xsl:function>

  <!-- remotes/<dialect>/<path of the URI>.xsd -->
  <xsl:function name="c:remote-href" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="d" select="head($entries[c:doc-of(?n, $ctx) eq $uri][empty(?n/parent::*)])?d"/>
    <xsl:sequence select="'remotes/' || c:dialect-name($d) || '/' || c:doc-path($uri) || '.xsd'"/>
  </xsl:function>

  <xsl:function name="c:doc-path" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:variable name="p" select="if (starts-with($uri, $remotes-base)) then substring-after($uri, $remotes-base)
        else replace($uri, '^[A-Za-z][A-Za-z0-9+.\-]*://', '')"/>
    <xsl:variable name="p" select="replace(replace(replace($p, '\.json$', ''), '[^A-Za-z0-9._/\-]', '_'), '\.\.', '__')"/>
    <xsl:sequence select="if ($p eq '' or ends-with($p, '/')) then $p || 'index' else $p"/>
  </xsl:function>

  <xsl:function name="c:relative-path" as="xs:string">
    <xsl:param name="from" as="xs:string"/>
    <xsl:param name="to" as="xs:string"/>
    <xsl:variable name="f" select="tokenize($from, '/')[position() lt last()]"/>
    <xsl:variable name="t" select="tokenize($to, '/')"/>
    <xsl:variable name="common" select="(for $i in 1 to min((count($f), count($t) - 1))
        return if ($f[$i] eq $t[$i]) then () else $i, min((count($f), count($t) - 1)) + 1)[1] - 1"/>
    <xsl:sequence select="string-join(((1 to count($f) - $common) ! '..', subsequence($t, $common + 1)), '/')"/>
  </xsl:function>

  <!-- Type names: the path of the schema in its document (properties.foo,
       $defs/node is defs.node, the document itself root), prefixed with the
       document's path for other documents (integer.root). -->
  <xsl:function name="c:type-names" as="map(xs:string, xs:string)">
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:param name="docs" as="map(xs:string, xs:string)"/>
    <xsl:variable name="named" as="map(*)*">
      <xsl:for-each select="$entries">
        <xsl:variable name="n" select="?n"/>
        <xsl:variable name="doc" select="($docs(generate-id($n/ancestor-or-self::*[last()])), '')[1]"/>
        <xsl:variable name="path" select="string-join($n/ancestor-or-self::*[parent::*] ! (
            if (parent::fn:array) then string(count(preceding-sibling::*))
            else (replace(replace(c:key(.), '^\$', ''), '[^A-Za-z0-9_\-]', '_')[. ne ''], '_')[1]), '.')"/>
        <xsl:variable name="name" select="(if ($doc eq '') then '' else replace(c:doc-path($doc), '/', '.') || '.')
            || (if ($path eq '') then 'root' else $path)"/>
        <xsl:sequence select="map { 'id': generate-id($n), 'name': if (matches($name, '^[A-Za-z_]')) then $name else '_' || $name }"/>
      </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="unique" as="map(*)*">
      <xsl:for-each-group select="$named" group-by="?id">
        <xsl:sequence select="current-group()[1]"/>
      </xsl:for-each-group>
    </xsl:variable>
    <xsl:sequence select="map:merge(
        for $g in distinct-values($unique ! ?name), $i in 1 to count($unique[?name eq $g])
        return map:entry($unique[?name eq $g][$i]?id, $g || (if ($i gt 1) then '_' || $i else '')))"/>
  </xsl:function>

  <xsl:function name="c:tname" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:sequence select="$ctx?names(generate-id($n))"/>
  </xsl:function>

  <!-- jx.<kind>: any value of a JSON type; jx.any: anything. -->
  <xsl:variable name="generic-types" as="element()*">
    <xs:complexType name="jx.object">
      <xs:sequence>
        <xs:any processContents="skip" namespace="##local" minOccurs="0" maxOccurs="unbounded"/>
      </xs:sequence>
      <xs:attribute name="type" type="xs:string" fixed="object" use="required"/>
    </xs:complexType>
    <xs:complexType name="jx.array">
      <xs:sequence>
        <xs:element name="item" type="jx.any" minOccurs="0" maxOccurs="unbounded"/>
      </xs:sequence>
      <xs:attribute name="type" type="xs:string" fixed="array" use="required"/>
    </xs:complexType>
    <xs:complexType name="jx.string">
      <xs:simpleContent>
        <xs:extension base="xs:string">
          <xs:attribute name="escaped" type="xs:string"/>
        </xs:extension>
      </xs:simpleContent>
    </xs:complexType>
    <xs:complexType name="jx.number">
      <xs:simpleContent>
        <xs:extension base="jx.number.value">
          <xs:attribute name="type" type="xs:string" fixed="number" use="required"/>
        </xs:extension>
      </xs:simpleContent>
    </xs:complexType>
    <xs:simpleType name="jx.number.value">
      <xs:restriction base="xs:string">
        <xs:pattern value="-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+\-]?[0-9]+)?"/>
      </xs:restriction>
    </xs:simpleType>
    <xs:complexType name="jx.boolean">
      <xs:simpleContent>
        <xs:extension base="jx.boolean.value">
          <xs:attribute name="type" type="xs:string" fixed="boolean" use="required"/>
        </xs:extension>
      </xs:simpleContent>
    </xs:complexType>
    <xs:simpleType name="jx.boolean.value">
      <xs:restriction base="xs:string">
        <xs:enumeration value="true"/>
        <xs:enumeration value="false"/>
      </xs:restriction>
    </xs:simpleType>
    <xs:complexType name="jx.null">
      <xs:attribute name="type" type="xs:string" fixed="null" use="required"/>
    </xs:complexType>
    <xs:complexType name="jx.any" mixed="true">
      <xs:sequence>
        <xs:any processContents="skip" minOccurs="0" maxOccurs="unbounded"/>
      </xs:sequence>
      <xs:anyAttribute processContents="skip"/>
    </xs:complexType>
  </xsl:variable>


  <!-- Keywords that select or combine subschemas: their schema is evaluated
       by an assertion (per dialect, as in c:keywords). -->
  <xsl:function name="c:fallback-keywords" as="xs:string*">
    <xsl:param name="d" as="xs:integer"/>
    <xsl:sequence select="'patternProperties',
        if ($d eq 3) then ('extends', 'disallow') else ('allOf', 'anyOf', 'oneOf', 'not'),
        if ($d ge 6) then ('contains', 'propertyNames') else (),
        if ($d ge 7) then 'if' else (),
        if ($d eq 7) then 'contentEncoding' else (),
        if ($d ge 2019) then ('dependentSchemas', 'unevaluatedItems', 'unevaluatedProperties') else (),
        if ($d eq 2019) then '$recursiveRef' else (),
        if ($d ge 2020) then '$dynamicRef' else (),
        if ($d ge 2100) then 'propertyDependencies' else ()"/>
  </xsl:function>

  <!-- Keywords that constrain the instance (all others are annotations). -->
  <xsl:variable name="validation-keywords" as="xs:string*" select="
      'type', 'enum', 'const', 'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum',
      'multipleOf', 'divisibleBy', 'minLength', 'maxLength', 'pattern', 'minItems', 'maxItems',
      'uniqueItems', 'items', 'prefixItems', 'additionalItems', 'minProperties', 'maxProperties',
      'required', 'properties', 'additionalProperties', 'dependencies', 'dependentRequired'"/>

  <!-- true, false, alias ($ref only), struct or fallback. -->
  <xsl:function name="c:class" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="e" select="$ctx?reg?info(generate-id($n))"/>
    <xsl:variable name="d" select="$e?d"/>
    <xsl:variable name="keys" select="$n/self::fn:map/*/c:key(.)"/>
    <xsl:variable name="validating" select="if (empty($e)) then () else $keys[. = ($validation-keywords, c:fallback-keywords($d))
        or (. eq 'format' and $e?fmt and c:kw($n, 'format') = $format-names)]"/>
    <xsl:sequence select="
        if ($n/self::fn:boolean) then (if ($n = 'true') then 'true' else 'false')
        else if (empty($e) or $e?noval) then 'fallback'
        else if ($keys = '$ref' and ($d le 7 or empty($validating))) then 'alias'
        else if ($keys = '$ref') then 'fallback'
        else if (empty($validating)) then 'true'
        else if ($keys = c:fallback-keywords($d) or $keys = 'format') then 'fallback'
        else if (exists(c:kw($n, 'additionalProperties')[not(c:trivial(.))])) then 'fallback'
        else if (exists(c:array-parts($n, $ctx)?prefix)) then 'fallback'
        else if (exists(c:kw($n, 'dependencies')/*[c:is-schema(.)])) then 'fallback'
        else if ($d eq 3 and exists(c:kw($n, 'type')/self::fn:array/fn:map)) then 'fallback'
        else if (exists((c:kw($n, 'enum')/*, c:kw($n, 'const'))/self::fn:string[@escaped = 'true'][not(je:xml-safe(c:str(.)))])) then 'fallback'
        else 'struct'"/>
  </xsl:function>

  <!-- A boolean schema or the empty schema. -->
  <xsl:function name="c:trivial" as="xs:boolean">
    <xsl:param name="n" as="element()"/>
    <xsl:sequence select="exists($n/self::fn:boolean) or exists($n/self::fn:map[empty(*)])"/>
  </xsl:function>

  <!-- The schema a node stands for, following $ref aliases; () for a cycle. -->
  <xsl:function name="c:effective" as="element()?">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:param name="seen" as="xs:string*"/>
    <xsl:choose>
      <xsl:when test="generate-id($n) = $seen"/>
      <xsl:when test="c:class($n, $ctx) eq 'alias'">
        <xsl:variable name="e" select="$ctx?reg?info(generate-id($n))"/>
        <xsl:sequence select="c:effective(c:target(c:resolve(c:str(c:kw($n, '$ref')), $e?base), $ctx?reg, true()),
            $ctx, ($seen, generate-id($n)))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$n"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The class of the schema a node stands for. -->
  <xsl:function name="c:class-of" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="eff" select="c:effective($n, $ctx, ())"/>
    <xsl:sequence select="if (empty($eff)) then 'fallback' else c:class($eff, $ctx)"/>
  </xsl:function>

  <!-- The node whose types an element of schema $n uses. -->
  <xsl:function name="c:typed" as="element()">
    <xsl:param name="n" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:sequence select="(c:effective($n, $ctx, ()), $n)[1]"/>
  </xsl:function>

  <!-- The schemas that need type definitions, reachable from $todo. -->
  <xsl:function name="c:typed-nodes" as="element()*">
    <xsl:param name="todo" as="element()*"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:param name="done" as="element()*"/>
    <xsl:variable name="new" as="element()*" select="($todo ! c:typed(., $ctx))[not(. intersect $done)]
        [c:class-of(., $ctx) = ('struct', 'fallback')]/."/>
    <xsl:sequence select="if (empty($new)) then $done
        else c:typed-nodes($new[c:class-of(., $ctx) eq 'struct'] ! c:element-schemas(., $ctx), $ctx, ($done, $new))"/>
  </xsl:function>

  <!-- The schemas of the member and item elements of a struct schema. -->
  <xsl:function name="c:element-schemas" as="element()*">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="a" select="c:array-parts($s, $ctx)"/>
    <xsl:sequence select="c:kw($s, 'properties')/self::fn:map/*[c:is-schema(.)],
        c:kw($s, 'additionalProperties')[c:is-schema(.)], $a?prefix, $a?rest"/>
  </xsl:function>

  <!-- prefix (schemas of the first items) and rest (schema of the others). -->
  <xsl:function name="c:array-parts" as="map(*)">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="d" select="$ctx?reg?info(generate-id($s))?d"/>
    <xsl:variable name="items" select="c:kw($s, 'items')"/>
    <xsl:sequence select="
        if ($d le 2019) then map {
          'prefix': $items/self::fn:array/*[c:is-schema(.)],
          'rest': if ($items/self::fn:array) then c:kw($s, 'additionalItems')[c:is-schema(.)] else $items[c:is-schema(.)] }
        else map { 'prefix': c:kw($s, 'prefixItems')/self::fn:array/*[c:is-schema(.)], 'rest': $items[c:is-schema(.)] }"/>
  </xsl:function>

  <!-- The type of an element declaration for schema $n: a type attribute or
       one xs:alternative per JSON type. -->
  <xsl:function name="c:element-type" as="node()*">
    <xsl:param name="n" as="element()?"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="t" select="if (empty($n)) then () else c:typed($n, $ctx)"/>
    <xsl:variable name="class" select="if (empty($n)) then 'true' else c:class-of($n, $ctx)"/>
    <xsl:choose>
      <xsl:when test="$class eq 'true'">
        <xsl:attribute name="type" select="'jx.any'"/>
      </xsl:when>
      <xsl:when test="$class eq 'false'">
        <xsl:attribute name="type" select="'xs:error'"/>
      </xsl:when>
      <xsl:when test="$class eq 'fallback'">
        <xsl:attribute name="type" select="c:tname($t, $ctx) || '.assert'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="i" select="c:tname($t, $ctx)"/>
        <xsl:variable name="kinds" select="c:kinds($t, $ctx)"/>
        <xsl:for-each select="('object', 'array', 'number', 'boolean', 'null')[. = $kinds]">
          <xs:alternative test="@type = '{.}'" type="{c:kind-type-name($t, ., $ctx)}"/>
        </xsl:for-each>
        <xsl:if test="'string' = $kinds and c:string-constraints($t)">
          <xs:alternative test="not(@type) and @escaped = 'true'" type="{$i}.assert"/>
        </xsl:if>
        <xsl:if test="'string' = $kinds">
          <xs:alternative test="not(@type)" type="{c:kind-type-name($t, 'string', $ctx)}"/>
        </xsl:if>
        <xs:alternative type="xs:error"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="c:element" as="element(xs:element)">
    <xsl:param name="name" as="xs:string"/>
    <xsl:param name="schema" as="element()?"/>
    <xsl:param name="min" as="xs:integer"/>
    <xsl:param name="max" as="xs:integer?"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xs:element name="{$name}">
      <xsl:if test="$min ne 1">
        <xsl:attribute name="minOccurs" select="$min"/>
      </xsl:if>
      <xsl:if test="empty($max) or $max ne 1">
        <xsl:attribute name="maxOccurs" select="if (empty($max)) then 'unbounded' else $max"/>
      </xsl:if>
      <xsl:sequence select="c:element-type($schema, $ctx)"/>
    </xs:element>
  </xsl:function>

  <!-- t<i>.<kind> if the schema constrains values of that kind, else the
       generic jx.<kind>. -->
  <xsl:function name="c:kind-type-name" as="xs:string">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="kind" as="xs:string"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:sequence select="if (c:constrains($s, $kind, $ctx)) then c:tname($s, $ctx) || '.' || $kind else 'jx.' || $kind"/>
  </xsl:function>

  <xsl:function name="c:constrains" as="xs:boolean">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="kind" as="xs:string"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="d" select="$ctx?reg?info(generate-id($s))?d"/>
    <xsl:variable name="types" select="c:kw($s, 'type')/(self::fn:string | fn:string)/c:str(.)"/>
    <xsl:variable name="values" select="(c:kw($s, 'enum')/*, c:kw($s, 'const'))[c:kind-of(.) eq $kind]"/>
    <xsl:sequence select="exists($values) or (
        if ($kind eq 'object') then exists(c:kw($s, ('properties', 'required', 'minProperties', 'maxProperties',
            'dependencies', 'dependentRequired'))) or c:kw($s, 'additionalProperties') = 'false'
        else if ($kind eq 'array') then exists(c:kw($s, ('items', 'additionalItems', 'minItems', 'maxItems', 'uniqueItems')))
        else if ($kind eq 'string') then c:string-constraints($s)
        else if ($kind eq 'number') then exists(c:kw($s, ('minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum',
            'multipleOf', 'divisibleBy'))) or ($types = 'integer' and not($types = ('number', 'any')))
        else false())"/>
  </xsl:function>

  <!-- The JSON types a struct schema allows. -->
  <xsl:function name="c:kinds" as="xs:string*">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="all" select="('object', 'array', 'string', 'number', 'boolean', 'null')"/>
    <xsl:variable name="types" select="c:kw($s, 'type')/(self::fn:string | fn:string)/c:str(.)"/>
    <xsl:variable name="by-type" select="if (empty(c:kw($s, 'type')) or $types = 'any') then $all
        else $all[. = ($types, if ($types = 'integer') then 'number' else ())]"/>
    <xsl:variable name="values" select="c:kw($s, 'enum')/*, c:kw($s, 'const')"/>
    <xsl:variable name="by-value" select="if (empty(c:kw($s, ('enum', 'const')))) then $all
        else distinct-values($values ! c:kind-of(.))"/>
    <xsl:variable name="const-kind" select="c:kw($s, 'const') ! c:kind-of(.)"/>
    <xsl:sequence select="$by-type[. = $by-value][empty($const-kind) or . = $const-kind]"/>
  </xsl:function>

  <xsl:function name="c:kind-of" as="xs:string">
    <xsl:param name="v" as="element()"/>
    <xsl:sequence select="if ($v/self::fn:map) then 'object' else local-name($v)"/>
  </xsl:function>

  <!-- A struct schema with constraints on strings (escaped strings then go
       to its fallback type). -->
  <xsl:function name="c:string-constraints" as="xs:boolean">
    <xsl:param name="s" as="element()"/>
    <xsl:sequence select="exists((c:kw($s, ('minLength', 'maxLength', 'pattern')),
        (c:kw($s, 'enum')/*, c:kw($s, 'const'))/self::fn:string))"/>
  </xsl:function>

  <!-- An integer from a JSON number (2.0 is 2), or () if it is none. -->
  <xsl:function name="c:int" as="xs:integer?">
    <xsl:param name="n" as="element()?"/>
    <xsl:variable name="v" select="$n/self::fn:number/normalize-space(.)"/>
    <xsl:sequence select="if (exists($v) and $v castable as xs:decimal and xs:decimal($v) = floor(xs:decimal($v)))
        then xs:integer(xs:decimal($v)) else ()"/>
  </xsl:function>

  <!-- An xs:assert for a test on $n (the element), with the helpers it uses. -->
  <xsl:function name="c:local-assert" as="element(xs:assert)?">
    <xsl:param name="tests" as="xs:string*"/>
    <xsl:if test="exists($tests)">
      <xsl:variable name="expr" select="string-join($tests ! ('(' || . || ')'), ' and ')"/>
      <xsl:variable name="helpers" select="c:helpers(distinct-values(analyze-string($expr, '\$[a-z]+')/fn:match/string()))"/>
      <xs:assert test="{'let ' || string-join(('$n := .', $helpers), ', ') || ' return ' || $expr}"/>
    </xsl:if>
  </xsl:function>

  <!-- t<i>.<kind> for each kind a struct schema allows. -->
  <xsl:function name="c:kind-types" as="element()*">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:variable name="i" select="c:tname($s, $ctx)"/>
    <xsl:variable name="e" select="$ctx?reg?info(generate-id($s))"/>
    <xsl:variable name="d" select="$e?d"/>
    <xsl:variable name="kinds" select="c:kinds($s, $ctx)"/>
    <xsl:variable name="values" select="c:kw($s, 'enum')/*, c:kw($s, 'const')"/>
    <!-- values of one kind in enum and const, which must all hold -->
    <xsl:variable name="value-tests" select="function($kind) {
        (if (exists(c:kw($s, 'enum'))) then '(some $e in (' || string-join(c:kw($s, 'enum')/*[c:kind-of(.) eq $kind] ! c:constant(.), ', ')
            || ') satisfies $eq($eq, $n, $e))' else (),
         c:kw($s, 'const')[c:kind-of(.) eq $kind] ! ('$eq($eq, $n, ' || c:constant(.) || ')')) }"/>

    <xsl:if test="$kinds = 'object' and c:constrains($s, 'object', $ctx)">
      <xsl:variable name="props" select="c:kw($s, 'properties')/self::fn:map/*[c:is-schema(.)]"/>
      <xsl:variable name="required" select="distinct-values((
          if ($d ge 4) then c:kw($s, 'required')/self::fn:array/fn:string/c:str(.) else (),
          if ($d eq 3) then $props[c:kw(., 'required') = 'true']/c:key(.) else ()))"/>
      <xsl:variable name="additional" select="c:kw($s, 'additionalProperties')"/>
      <xsl:variable name="closed" select="$additional/self::fn:boolean = 'false'"/>
      <xs:complexType name="{$i}.object">
        <xs:all>
          <xsl:for-each select="$props">
            <xsl:sequence select="c:element(je:name(c:key(.)), ., if (c:key(.) = $required) then 1 else 0, 1, $ctx)"/>
          </xsl:for-each>
          <xsl:for-each select="$required[not(. = $props/c:key(.))]">
            <xsl:sequence select="c:element(je:name(.), ($additional, $s/../*[false()])[1], 1, 1, $ctx)"/>
          </xsl:for-each>
          <xsl:if test="not($closed)">
            <xs:any processContents="skip" namespace="##local" notQName="##definedSibling"
                minOccurs="0" maxOccurs="unbounded"/>
          </xsl:if>
        </xs:all>
        <xsl:sequence select="c:type-attribute('object')"/>
        <xsl:sequence select="c:local-assert((
            c:kw($s, 'minProperties')/c:int(.) ! ('count($n/*) ge ' || .),
            c:kw($s, 'maxProperties')/c:int(.) ! ('count($n/*) le ' || .),
            (c:kw($s, 'dependencies')/self::fn:map/*, if ($d ge 2019) then c:kw($s, 'dependentRequired')/self::fn:map/fn:array else ())
              [self::fn:array or self::fn:string]
              ! ('not(exists($n/*[$key(.) eq ' || c:lit(c:key(.)) || '])) or (every $r in ('
                 || c:string-list(self::fn:array/* | self::fn:string) || ') satisfies exists($n/*[$key(.) eq $r]))'),
            $value-tests('object')))"/>
      </xs:complexType>
    </xsl:if>

    <xsl:if test="$kinds = 'array' and c:constrains($s, 'array', $ctx)">
      <xsl:variable name="parts" select="c:array-parts($s, $ctx)"/>
      <xsl:variable name="rest" select="($parts?rest, $s/../*[false()])[1]"/>
      <xsl:variable name="no-rest" select="exists($rest) and c:class-of($rest, $ctx) eq 'false'"/>
      <xsl:variable name="min" select="c:int(c:kw($s, 'minItems'))"/>
      <xsl:variable name="max" select="c:int(c:kw($s, 'maxItems'))"/>
      <xsl:variable name="counted" select="empty($parts?prefix) and not($no-rest)
          and (empty($min) or empty($max) or $min le $max)"/>
      <xs:complexType name="{$i}.array">
        <xs:sequence>
          <xsl:choose>
            <xsl:when test="$counted">
              <xsl:sequence select="c:element('item', $rest, ($min, 0)[1], $max, $ctx)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:sequence select="c:item-sequence($parts?prefix, if ($no-rest) then () else ($rest, $s)[1], $no-rest, exists($rest), $ctx)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xs:sequence>
        <xsl:sequence select="c:type-attribute('array')"/>
        <xsl:sequence select="c:local-assert((
            if ($counted) then () else ($min ! ('count($n/*) ge ' || .), $max ! ('count($n/*) le ' || .)),
            if (c:kw($s, 'uniqueItems') = 'true')
              then 'every $i in 1 to count($n/*) - 1 satisfies every $j in $i + 1 to count($n/*) satisfies not($eq($eq, $n/*[$i], $n/*[$j]))'
              else (),
            $value-tests('array')))"/>
      </xs:complexType>
    </xsl:if>

    <xsl:if test="$kinds = 'string' and c:constrains($s, 'string', $ctx)">
      <xsl:variable name="pattern" select="c:kw($s, 'pattern')/self::fn:string/c:str(.)"/>
      <xsl:variable name="xsd-pattern" select="$pattern ! c:xsd-pattern(.)"/>
      <xsl:variable name="strings" select="$values[c:kind-of(.) eq 'string']"/>
      <xsl:variable name="enum" select="if (exists(c:kw($s, 'const'))) then c:kw($s, 'const')[self::fn:string]
          else c:kw($s, 'enum')/self::fn:array/fn:string"/>
      <xsl:variable name="facets" as="element()*">
        <xsl:for-each select="c:kw($s, 'minLength')/c:int(.)">
          <xs:minLength value="{.}"/>
        </xsl:for-each>
        <xsl:for-each select="c:kw($s, 'maxLength')/c:int(.)">
          <xs:maxLength value="{.}"/>
        </xsl:for-each>
        <xsl:for-each select="$xsd-pattern">
          <xs:pattern value="{.}"/>
        </xsl:for-each>
        <xsl:for-each select="$enum">
          <xs:enumeration value="{c:str(.)}"/>
        </xsl:for-each>
      </xsl:variable>
      <xsl:if test="exists($facets)">
        <xs:simpleType name="{$i}.string.value">
          <xs:restriction base="xs:string">
            <xsl:sequence select="$facets"/>
          </xs:restriction>
        </xs:simpleType>
      </xsl:if>
      <xs:complexType name="{$i}.string">
        <xs:simpleContent>
          <xs:extension base="{if (exists($facets)) then $i || '.string.value' else 'xs:string'}">
            <xsl:if test="not(c:string-constraints($s))">
              <xs:attribute name="escaped" type="xs:string"/>
            </xsl:if>
            <xsl:sequence select="c:local-assert((
                if (exists($pattern) and empty($xsd-pattern)) then 'matches(string($n), ' || c:regex($pattern) || ')' else (),
                c:kw($s, 'const')[self::fn:string][exists(c:kw($s, 'enum'))] ! ('string($n) = (' || c:string-list(c:kw($s, 'enum')/self::fn:array/fn:string) || ')')))"/>
          </xs:extension>
        </xs:simpleContent>
      </xs:complexType>
    </xsl:if>

    <xsl:if test="$kinds = 'number' and c:constrains($s, 'number', $ctx)">
      <xsl:variable name="excl-min" select="$d le 4 and c:kw($s, 'exclusiveMinimum') = 'true'"/>
      <xsl:variable name="excl-max" select="$d le 4 and c:kw($s, 'exclusiveMaximum') = 'true'"/>
      <xsl:variable name="types" select="c:kw($s, 'type')/(self::fn:string | fn:string)/c:str(.)"/>
      <xs:complexType name="{$i}.number">
        <xs:simpleContent>
          <xs:extension base="jx.number.value">
            <xsl:sequence select="c:type-attribute('number')"/>
            <xsl:sequence select="c:local-assert((
                if ($types = 'integer' and not($types = ('number', 'any')))
                  then (if ($d le 4) then 'not(contains($n, ''.'')) and $isint($n)' else '$isint($n)') else (),
                c:kw($s, 'minimum')/self::fn:number ! ('$num($n) ' || (if ($excl-min) then 'gt ' else 'ge ') || c:number(.)),
                c:kw($s, 'maximum')/self::fn:number ! ('$num($n) ' || (if ($excl-max) then 'lt ' else 'le ') || c:number(.)),
                if ($d ge 6) then (
                  c:kw($s, 'exclusiveMinimum')/self::fn:number ! ('$num($n) gt ' || c:number(.)),
                  c:kw($s, 'exclusiveMaximum')/self::fn:number ! ('$num($n) lt ' || c:number(.))) else (),
                c:kw($s, if ($d eq 3) then 'divisibleBy' else 'multipleOf')/self::fn:number ! ('$mult($num($n), ' || c:number(.) || ')'),
                if (exists(c:kw($s, 'enum')/self::fn:array/fn:number))
                  then string-join(c:kw($s, 'enum')/self::fn:array/fn:number ! ('$num($n) = ' || c:number(.)), ' or ') else (),
                c:kw($s, 'const')[self::fn:number] ! ('$num($n) = ' || c:number(.))))"/>
          </xs:extension>
        </xs:simpleContent>
      </xs:complexType>
    </xsl:if>

    <xsl:if test="$kinds = 'boolean' and c:constrains($s, 'boolean', $ctx)">
      <xsl:variable name="booleans" select="distinct-values(
          if (exists(c:kw($s, 'const'))) then c:kw($s, 'const')[self::fn:boolean]/normalize-space(.)
          else c:kw($s, 'enum')/self::fn:array/fn:boolean/normalize-space(.))"/>
      <xs:complexType name="{$i}.boolean">
        <xs:simpleContent>
          <xsl:choose>
            <xsl:when test="exists($values)">
              <xs:restriction base="{$i}.boolean.base">
                <xsl:for-each select="$booleans">
                  <xs:enumeration value="{.}"/>
                </xsl:for-each>
              </xs:restriction>
            </xsl:when>
            <xsl:otherwise>
              <xs:extension base="jx.boolean.value">
                <xsl:sequence select="c:type-attribute('boolean')"/>
              </xs:extension>
            </xsl:otherwise>
          </xsl:choose>
        </xs:simpleContent>
      </xs:complexType>
      <xsl:if test="exists($values)">
        <xs:complexType name="{$i}.boolean.base">
          <xs:simpleContent>
            <xs:extension base="jx.boolean.value">
              <xsl:sequence select="c:type-attribute('boolean')"/>
            </xs:extension>
          </xs:simpleContent>
        </xs:complexType>
      </xsl:if>
    </xsl:if>

    <xsl:if test="$kinds = 'null' and c:constrains($s, 'null', $ctx)">
      <xs:complexType name="{$i}.null">
        <xsl:sequence select="c:type-attribute('null')"/>
      </xs:complexType>
    </xsl:if>
  </xsl:function>

  <xsl:function name="c:type-attribute" as="element(xs:attribute)">
    <xsl:param name="kind" as="xs:string"/>
    <xs:attribute name="type" type="xs:string" fixed="{$kind}" use="required"/>
  </xsl:function>

  <!-- Items for prefix schemas: (p1, (p2, (..., rest*)?)?)? -->
  <xsl:function name="c:item-sequence" as="element()*">
    <xsl:param name="prefix" as="element()*"/>
    <xsl:param name="rest" as="element()?"/>
    <xsl:param name="no-rest" as="xs:boolean"/>
    <xsl:param name="has-rest" as="xs:boolean"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xsl:choose>
      <xsl:when test="empty($prefix)">
        <xsl:if test="not($no-rest)">
          <xsl:sequence select="c:element('item', if ($has-rest) then $rest else (), 0, (), $ctx)"/>
        </xsl:if>
      </xsl:when>
      <xsl:otherwise>
        <xs:sequence minOccurs="0">
          <xsl:sequence select="c:element('item', head($prefix), 1, 1, $ctx)"/>
          <xsl:sequence select="c:item-sequence(tail($prefix), $rest, $no-rest, $has-rest, $ctx)"/>
        </xs:sequence>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- f<i>: any content, checked by an assertion that evaluates the schema. -->
  <xsl:function name="c:fallback-type" as="element(xs:complexType)">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="ctx" as="map(*)"/>
    <xs:complexType name="{c:tname($s, $ctx)}.assert" mixed="true">
      <xs:sequence>
        <xs:any processContents="skip" minOccurs="0" maxOccurs="unbounded"/>
      </xs:sequence>
      <xs:anyAttribute processContents="skip"/>
      <xs:assert test="{c:assertion($ctx?program, c:fkey($s))}"/>
    </xs:complexType>
  </xsl:function>

  <!-- A JSON Schema pattern (ECMA-262, unanchored search) as an XSD pattern
       facet (implicitly anchored), or () if it cannot be written as one. -->
  <xsl:function name="c:xsd-pattern" as="xs:string?">
    <xsl:param name="re" as="xs:string"/>
    <xsl:variable name="x" select="c:regex-raw($re)"/>
    <xsl:variable name="start" select="starts-with($x, '^')"/>
    <xsl:variable name="end" select="matches($x, '(^|[^\\])(\\\\)*\$$')"/>
    <xsl:variable name="core" select="if ($end) then substring(replace($x, '^\^', ''), 1, string-length(replace($x, '^\^', '')) - 1)
        else replace($x, '^\^', '')"/>
    <!-- XSD regular expressions have no anchors, groups with (?, reluctant
         quantifiers or back-references; a top-level | would change the
         meaning of the added .* -->
    <xsl:variable name="stripped" select="replace(replace($core, '\\.', 'e'), '\[(\\.|[^\]\\])*\]', 'c')"/>
    <xsl:if test="je:xml-safe($x) and not(matches($stripped, '[\^$]|\(\?|[*+?}]\?'))
        and ($start and $end or not(c:top-level-alternation($stripped)))">
      <xsl:sequence select="(if ($start) then '' else '[\s\S]*') || (if ($start and $end) then $core else '(' || $core || ')')
          || (if ($end) then '' else '[\s\S]*')"/>
    </xsl:if>
  </xsl:function>

  <xsl:function name="c:top-level-alternation" as="xs:boolean">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="fold-left(string-to-codepoints($s), [0, false()], function($st, $c) {
        if ($c eq 40) then [$st(1) + 1, $st(2)]
        else if ($c eq 41) then [$st(1) - 1, $st(2)]
        else if ($c eq 124 and $st(1) eq 0) then [$st(1), true()]
        else $st })(2)"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- Formats                                                            -->
  <!-- ================================================================== -->

  <xsl:variable name="format-names" as="xs:string*" select="
      'date', 'time', 'date-time', 'duration', 'email', 'idn-email', 'hostname', 'idn-hostname',
      'ipv4', 'ipv6', 'uri', 'uri-reference', 'iri', 'iri-reference', 'uri-template',
      'json-pointer', 'relative-json-pointer', 'uuid', 'regex', 'host-name', 'ip-address', 'color'"/>

  <!-- XPath bindings of the format checks, part of the assertion's let
       clause; $F maps each format name to a function($s) as xs:boolean. -->
  <xsl:variable name="format-functions" as="xs:string">
    <xsl:text>
$fmt_date := function($s) { matches($s, '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') and $s castable as xs:date },
$fmt_time := function($s, $leap) {
  let $re := '^([0-9]{2}):([0-9]{2}):([0-9]{2})(\.[0-9]+)?([Zz]|([+\-])([0-9]{2}):([0-9]{2}))$'
  return matches($s, $re) and (
    let $h := xs:integer(replace($s, $re, '$1')), $m := xs:integer(replace($s, $re, '$2')),
        $sec := xs:integer(replace($s, $re, '$3')), $sg := replace($s, $re, '$6'),
        $oh := if ($sg eq '') then 0 else xs:integer(replace($s, $re, '$7')),
        $om := if ($sg eq '') then 0 else xs:integer(replace($s, $re, '$8'))
    return $h le 23 and $m le 59 and $oh le 23 and $om le 59
      and ($sec le 59 or ($leap and $sec eq 60
        and ($h * 60 + $m - (if ($sg eq '-') then -1 else 1) * ($oh * 60 + $om) + 1440) mod 1440 eq 1439))) },
$fmt_datetime := function($s, $leap, $ext) {
  let $name := '([A-Za-z_][A-Za-z0-9._+\-]{0,13}|\.[A-Za-z0-9_+\-][A-Za-z0-9._+\-]{0,12}|\.\.[A-Za-z0-9._+\-]{1,12})',
      $tag := '\[!?[a-z_][a-z0-9_\-]*=[A-Za-z0-9]+(\-[A-Za-z0-9]+)*\]',
      $t := if ($ext and ends-with($s, ']'))
            then replace($s, concat('(\[!?(', $name, '(/', $name, ')*|[+\-][0-9]{2}:[0-9]{2})\](', $tag, ')*|(', $tag, ')+)$'), '')
            else $s
  return matches($t, '^[0-9]{4}-[0-9]{2}-[0-9]{2}[Tt]') and $fmt_date(substring($t, 1, 10)) and $fmt_time(substring($t, 12), $leap) },
$fmt_durtime := '[0-9]+H([0-9]+M([0-9]+S)?)?|[0-9]+M([0-9]+S)?|[0-9]+S',
$fmt_duration := function($s) {
  matches($s, concat('^P(([0-9]+D|[0-9]+M([0-9]+D)?|[0-9]+Y([0-9]+M([0-9]+D)?)?)(T(', $fmt_durtime, '))?|T(', $fmt_durtime, ')|[0-9]+W)$')) },
$fmt_ipv4 := function($s) { matches($s, '^(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}$') },
$fmt_ipv6 := function($s) {
  let $last := tokenize($s, ':')[last()], $v4 := contains($last, '.'),
      $t := if ($v4) then substring($s, 1, string-length($s) - string-length($last)) || '0:0' else $s,
      $g := function($p) { $p eq '' or (every $x in tokenize($p, ':') satisfies matches($x, '^[0-9A-Fa-f]{1,4}$')) },
      $n := function($p) { if ($p eq '') then 0 else count(tokenize($p, ':')) }
  return (not($v4) or $fmt_ipv4($last)) and matches($t, '^[0-9A-Fa-f:]+$') and (
    if (contains($t, '::'))
    then (let $h := substring-before($t, '::'), $r := substring-after($t, '::')
          return not(contains($r, '::')) and $g($h) and $g($r) and $n($h) + $n($r) le 7)
    else count(tokenize($t, ':')) eq 8 and $g($t)) },
$puny_adapt := function($delta, $count, $first) {
  let $d := if ($first) then $delta idiv 700 else $delta idiv 2, $d := $d + $d idiv $count,
      $loop := function($loop, $d, $k) { if ($d gt 455) then $loop($loop, $d idiv 35, $k + 36) else $k + (36 * $d) idiv ($d + 38) }
  return $loop($loop, $d, 0) },
$puny_t := function($k, $bias) { if ($k le $bias) then 1 else if ($k ge $bias + 26) then 26 else $k - $bias },
$puny_decode := function($s) {
  let $basic := if (contains($s, '-')) then replace($s, '-[^-]*$', '') else '',
      $rest := if (contains($s, '-')) then substring($s, string-length($basic) + 2) else $s,
      $digit := function($c) { if ($c ge 48 and $c le 57) then $c - 22 else if ($c ge 65 and $c le 90) then $c - 65 else if ($c ge 97 and $c le 122) then $c - 97 else -1 },
      $var := function($var, $in, $i, $w, $k, $bias) {
        if (empty($in)) then () else
        let $dg := $digit(head($in)) return if ($dg lt 0) then () else
        let $i := $i + $dg * $w, $t := $puny_t($k, $bias)
        return if ($dg lt $t) then ($i, tail($in)) else $var($var, tail($in), $i, $w * (36 - $t), $k + 36, $bias) },
      $loop := function($loop, $in, $out, $i, $n, $bias) {
        if (empty($in)) then $out else
        let $r := $var($var, $in, $i, 1, 36, $bias) return if (empty($r)) then -1 else
        let $len := count($out) + 1, $bias := $puny_adapt(head($r) - $i, $len, $i eq 0),
            $n := $n + head($r) idiv $len, $pos := head($r) mod $len
        return if ($n gt 1114111) then -1
          else $loop($loop, tail($r), (subsequence($out, 1, $pos), $n, subsequence($out, $pos + 1)), $pos + 1, $n, $bias) }
  return if (matches($basic, '[^\p{IsBasicLatin}]') or ($rest eq '' and $basic eq '')) then -1
    else $loop($loop, string-to-codepoints($rest), string-to-codepoints($basic), 0, 128, 72) },
$puny_encode := function($cps) {
  let $basic := $cps[. lt 128], $b := count($basic),
      $chr := function($d) { codepoints-to-string(if ($d lt 26) then $d + 97 else $d + 22) },
      $emit := function($emit, $q, $k, $bias) {
        let $t := $puny_t($k, $bias) return if ($q lt $t) then $chr($q)
          else $chr($t + ($q - $t) mod (36 - $t)) || $emit($emit, ($q - $t) idiv (36 - $t), $k + 36, $bias) },
      $outer := function($outer, $n, $delta, $bias, $h, $out) {
        if ($h ge count($cps)) then $out else
        let $m := min($cps[. ge $n]), $delta := $delta + ($m - $n) * ($h + 1),
            $st := fold-left($cps, [$delta, $bias, $h, $out], function($st, $c) {
              if ($c lt $m) then [$st(1) + 1, $st(2), $st(3), $st(4)]
              else if ($c eq $m) then [0, $puny_adapt($st(1), $st(3) + 1, $st(3) eq $b), $st(3) + 1, $st(4) || $emit($emit, $st(1), 36, $st(2))]
              else $st })
        return $outer($outer, $m + 1, $st(1) + 1, $st(2), $st(3), $st(4)) }
  return $outer($outer, 128, 0, 72, $b, codepoints-to-string($basic) || (if ($b gt 0) then '-' else '')) },
$idn_label := function($l) {
  $l ne '' and not(matches($l, '^\p{M}')) and not(starts-with($l, '-')) and not(ends-with($l, '-'))
  and substring($l, 3, 2) ne '--'
  and matches($l, '^[\p{Ll}\p{Lo}\p{Lm}\p{Mn}\p{Mc}\p{Nd}\-&#xDF;&#x3C2;&#xF0B;&#x3007;&#x6FD;&#x6FE;&#xB7;&#x375;&#x5F3;&#x5F4;&#x30FB;&#x200C;&#x200D;]+$')
  and not(matches($l, '[&#x640;&#x7FA;&#x302E;&#x302F;&#x3031;-&#x3035;&#x303B;]'))
  and not(matches($l, '(^|[^l])&#xB7;|&#xB7;([^l]|$)'))
  and not(matches($l, '&#x375;(\P{IsGreek}|$)'))
  and not(matches($l, '(^|\P{IsHebrew})[&#x5F3;&#x5F4;]'))
  and (not(contains($l, '&#x30FB;')) or matches(replace($l, '&#x30FB;', ' '), '[\p{IsHiragana}\p{IsKatakana}\p{IsCJKUnifiedIdeographs}]'))
  and not(matches($l, '[&#x660;-&#x669;]') and matches($l, '[&#x6F0;-&#x6F9;]'))
  and not(matches($l, '(^|[^&#x94D;&#x9CD;&#xA4D;&#xACD;&#xB4D;&#xBCD;&#xC4D;&#xCCD;&#xD3B;&#xD3C;&#xD4D;&#xDCA;&#xE3A;&#xEBA;&#xF84;&#x1039;&#x103A;&#x1714;&#x1734;&#x17D2;&#x1A60;&#x1B44;&#x1BAA;&#x1BAB;&#x1BF2;&#x1BF3;&#x2D7F;&#xA806;&#xA8C4;&#xA953;&#xA9C0;&#xAAF6;&#xABED;])&#x200D;'))
  and not(matches($l, '(^|[^&#x94D;&#x9CD;&#xA4D;&#xACD;&#xB4D;&#xBCD;&#xC4D;&#xCCD;&#xD3B;&#xD3C;&#xD4D;&#xDCA;&#xE3A;&#xEBA;&#xF84;&#x1039;&#x103A;&#x1714;&#x1734;&#x17D2;&#x1A60;&#x1B44;&#x1BAA;&#x1BAB;&#x1BF2;&#x1BF3;&#x2D7F;&#xA806;&#xA8C4;&#xA953;&#xA9C0;&#xAAF6;&#xABED;\p{IsArabic}])&#x200C;|[^&#x94D;&#x9CD;&#xA4D;&#xACD;&#xB4D;&#xBCD;&#xC4D;&#xCCD;&#xD3B;&#xD3C;&#xD4D;&#xDCA;&#xE3A;&#xEBA;&#xF84;&#x1039;&#x103A;&#x1714;&#x1734;&#x17D2;&#x1A60;&#x1B44;&#x1BAA;&#x1BAB;&#x1BF2;&#x1BF3;&#x2D7F;&#xA806;&#xA8C4;&#xA953;&#xA9C0;&#xAAF6;&#xABED;]&#x200C;(\P{IsArabic}|$)')) },
$idn_bidi := function($labels) {
  not(some $l in $labels satisfies matches($l, '[&#x5BE;&#x5C0;&#x5C3;&#x5C6;&#x5D0;-&#x5F4;&#x608;&#x60B;&#x60D;&#x61B;-&#x64A;&#x66D;-&#x66F;&#x671;-&#x6D5;&#x6E5;&#x6E6;&#x6EE;&#x6EF;&#x6FA;-&#x70D;&#x710;&#x712;-&#x72F;&#x74D;-&#x7A5;&#x7B1;&#x7C0;-&#x7EA;&#x7F4;&#x7F5;&#x7FA;-&#x815;&#x81A;&#x824;&#x828;&#x830;-&#x858;&#x860;-&#x88E;&#x8A0;-&#x8C9;&#xFB1D;&#xFB1F;-&#xFB28;&#xFB2A;-&#xFD3D;&#xFD50;-&#xFDFC;&#xFE70;-&#xFEFC;&#x660;-&#x669;&#x66B;&#x66C;]'))
  or (every $l in $labels satisfies (
    if (matches($l, '^[&#x5BE;&#x5C0;&#x5C3;&#x5C6;&#x5D0;-&#x5F4;&#x608;&#x60B;&#x60D;&#x61B;-&#x64A;&#x66D;-&#x66F;&#x671;-&#x6D5;&#x6E5;&#x6E6;&#x6EE;&#x6EF;&#x6FA;-&#x70D;&#x710;&#x712;-&#x72F;&#x74D;-&#x7A5;&#x7B1;&#x7C0;-&#x7EA;&#x7F4;&#x7F5;&#x7FA;-&#x815;&#x81A;&#x824;&#x828;&#x830;-&#x858;&#x860;-&#x88E;&#x8A0;-&#x8C9;&#xFB1D;&#xFB1F;-&#xFB28;&#xFB2A;-&#xFD3D;&#xFD50;-&#xFDFC;&#xFE70;-&#xFEFC;]'))
    then matches($l, '^[&#x5BE;&#x5C0;&#x5C3;&#x5C6;&#x5D0;-&#x5F4;&#x608;&#x60B;&#x60D;&#x61B;-&#x64A;&#x66D;-&#x66F;&#x671;-&#x6D5;&#x6E5;&#x6E6;&#x6EE;&#x6EF;&#x6FA;-&#x70D;&#x710;&#x712;-&#x72F;&#x74D;-&#x7A5;&#x7B1;&#x7C0;-&#x7EA;&#x7F4;&#x7F5;&#x7FA;-&#x815;&#x81A;&#x824;&#x828;&#x830;-&#x858;&#x860;-&#x88E;&#x8A0;-&#x8C9;&#xFB1D;&#xFB1F;-&#xFB28;&#xFB2A;-&#xFD3D;&#xFD50;-&#xFDFC;&#xFE70;-&#xFEFC;&#x660;-&#x669;&#x66B;&#x66C;0-9&#x6F0;-&#x6F9;\p{Mn}\-&#x200C;&#x200D;]*[&#x5BE;&#x5C0;&#x5C3;&#x5C6;&#x5D0;-&#x5F4;&#x608;&#x60B;&#x60D;&#x61B;-&#x64A;&#x66D;-&#x66F;&#x671;-&#x6D5;&#x6E5;&#x6E6;&#x6EE;&#x6EF;&#x6FA;-&#x70D;&#x710;&#x712;-&#x72F;&#x74D;-&#x7A5;&#x7B1;&#x7C0;-&#x7EA;&#x7F4;&#x7F5;&#x7FA;-&#x815;&#x81A;&#x824;&#x828;&#x830;-&#x858;&#x860;-&#x88E;&#x8A0;-&#x8C9;&#xFB1D;&#xFB1F;-&#xFB28;&#xFB2A;-&#xFD3D;&#xFD50;-&#xFDFC;&#xFE70;-&#xFEFC;&#x660;-&#x669;&#x66B;&#x66C;0-9&#x6F0;-&#x6F9;]\p{Mn}*$')
      and not(matches($l, '[0-9&#x6F0;-&#x6F9;]') and matches($l, '[&#x660;-&#x669;&#x66B;&#x66C;]'))
    else matches($l, '^\p{L}') and not(matches($l, '[&#x5BE;&#x5C0;&#x5C3;&#x5C6;&#x5D0;-&#x5F4;&#x608;&#x60B;&#x60D;&#x61B;-&#x64A;&#x66D;-&#x66F;&#x671;-&#x6D5;&#x6E5;&#x6E6;&#x6EE;&#x6EF;&#x6FA;-&#x70D;&#x710;&#x712;-&#x72F;&#x74D;-&#x7A5;&#x7B1;&#x7C0;-&#x7EA;&#x7F4;&#x7F5;&#x7FA;-&#x815;&#x81A;&#x824;&#x828;&#x830;-&#x858;&#x860;-&#x88E;&#x8A0;-&#x8C9;&#xFB1D;&#xFB1F;-&#xFB28;&#xFB2A;-&#xFD3D;&#xFD50;-&#xFDFC;&#xFE70;-&#xFEFC;&#x660;-&#x669;&#x66B;&#x66C;]'))
      and matches($l, '[\p{L}0-9&#x6F0;-&#x6F9;]\p{Mn}*$'))) },
$fmt_hostname := function($s, $idn) {
  let $m := if ($idn) then replace(lower-case(normalize-unicode($s, 'NFKC')), '[&#x200B;&#xAD;&#xFE00;-&#xFE0F;]', '') else $s,
      $labels := tokenize($m, if ($idn) then '[.&#x3002;]' else '\.'),
      $checked := for $l in $labels return (
        if (starts-with(lower-case($l), 'xn--'))
        then (let $u := $puny_decode(lower-case(substring($l, 5)))
              return if ($u = -1 or empty($u) or (every $c in $u satisfies $c lt 128)
                         or $puny_encode($u) ne lower-case(substring($l, 5))
                         or not(matches($l, '^[A-Za-z0-9\-]+$')) or string-length($l) gt 63) then ()
                     else [$l, codepoints-to-string($u)])
        else if (matches($l, '^[\p{IsBasicLatin}]*$'))
        then (if (matches($l, '^[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?$') and substring($l, 3, 2) ne '--') then [$l, $l] else ())
        else if ($idn) then (let $a := 'xn--' || $puny_encode(string-to-codepoints($l))
                             return if (string-length($a) le 63) then [$a, $l] else ())
        else ())
  return $s ne '' and count($checked) eq count($labels)
    and string-length(string-join(for $c in $checked return $c(1), '.')) le 253
    and (every $c in $checked satisfies ($c(1) eq $c(2) or $idn_label($c(2))))
    and $idn_bidi(for $c in $checked return $c(2)) },
$fmt_mailbox := function($s, $intl) {
  let $d := tokenize($s, '@')[last()], $l := substring($s, 1, string-length($s) - string-length($d) - 1),
      $atom := if ($intl) then '[A-Za-z0-9!#$%&amp;''*+/=?^_`{|}~\-\P{IsBasicLatin}]+' else '[A-Za-z0-9!#$%&amp;''*+/=?^_`{|}~\-]+',
      $quoted := if ($intl) then '^"([ !#-\[\]-~\P{IsBasicLatin}]|\\[ -~])*"$' else '^"([ !#-\[\]-~]|\\[ -~])*"$'
  return contains($s, '@')
    and (matches($l, '^' || $atom || '(\.' || $atom || ')*$') or matches($l, $quoted))
    and ($fmt_hostname($d, $intl)
      or (matches($d, '^\[.*\]$') and (let $ip := substring($d, 2, string-length($d) - 2)
          return $fmt_ipv4($ip) or (lower-case(substring($ip, 1, 5)) eq 'ipv6:' and $fmt_ipv6(substring($ip, 6)))))) },
$fmt_uriref := function($s, $iri) {
  let $c := if ($iri) then '([A-Za-z0-9\-._~:/?#\[\]@!$&amp;''()*+,;=\P{IsBasicLatin}]|%[0-9A-Fa-f]{2})*'
                      else '([A-Za-z0-9\-._~:/?#\[\]@!$&amp;''()*+,;=]|%[0-9A-Fa-f]{2})*',
      $scheme := matches($s, '^[A-Za-z][A-Za-z0-9+.\-]*:'),
      $rest := if ($scheme) then replace($s, '^[A-Za-z][A-Za-z0-9+.\-]*:', '') else $s
  return matches($s, '^' || $c || '$')
    and count(tokenize($s, '#')) le 2
    and ($scheme or not(contains(replace($s, '[/?#].*$', ''), ':')))
    and (if (starts-with($rest, '//'))
         then (let $auth := replace(substring($rest, 3), '[/?#].*$', ''),
                   $after := substring($rest, 3 + string-length($auth)),
                   $user := if (contains($auth, '@')) then substring-before($auth, '@') else '',
                   $hp := if (contains($auth, '@')) then substring-after($auth, '@') else $auth
               return not(matches($user, '[\[\]]')) and not(contains($hp, '@')) and not(matches($after, '[\[\]]'))
                 and (if (starts-with($hp, '['))
                      then (contains($hp, ']') and $fmt_ipv6(substring-before(substring($hp, 2), ']'))
                            and matches(substring-after($hp, ']'), '^(:[0-9]*)?$'))
                      else (not(matches($hp, '[\[\]]')) and matches($hp, '^[^:]*(:[0-9]*)?$'))))
         else not(matches($rest, '[\[\]]'))) },
$fmt_template := function($s) {
  let $v := '([A-Za-z0-9_]|%[0-9A-Fa-f]{2})(\.?([A-Za-z0-9_]|%[0-9A-Fa-f]{2}))*(:[1-9][0-9]{0,3}|\*)?'
  return matches($s, '^([^ "%&lt;&gt;\\^`{|}\p{Cc}]|%[0-9A-Fa-f]{2}|\{[+#./;?&amp;=,!@|]?' || $v || '(,' || $v || ')*\})*$') },
$fmt_regex := function($s) {
  not(matches($s, '(^|[^\\])(\\\\)*\\a'))
  and not(matches($s, '(^|[^\\])(\\\\)*\(\?[^:=!&lt;]'))
  and not(matches($s, '(^|[^\\])(\\\\)*\(\?&lt;[^=!A-Za-z_$]'))
  and not(matches($s, '^[*+?]|(^|[^\\])(\\\\)*(\([*+]|\|[*+?])'))
  and (every $r in analyze-string($s, '(^|[^\\])\[(\\.|[^\]\\])*\]')/fn:match ! string(.)
       satisfies (every $m in analyze-string($r, '([^\\\[])-([^\\\]])')/fn:match
                  satisfies string-to-codepoints(string($m/fn:group[@nr = 1])) le string-to-codepoints(string($m/fn:group[@nr = 2]))))
  and (
    let $st := fold-left(string-to-codepoints($s), [0, false(), false()], function($st, $c) {
      if ($st(3)) then [$st(1), $st(2), false()]
      else if ($c eq 92) then [$st(1), $st(2), true()]
      else if ($st(2)) then [$st(1), $c ne 93, false()]
      else if ($c eq 91) then [$st(1), true(), false()]
      else if ($c eq 40) then [$st(1) + 1, false(), false()]
      else if ($c eq 41) then [$st(1) - (if ($st(1) gt 0) then 1 else 1000), false(), false()]
      else $st })
    return $st(1) eq 0 and not($st(2)) and not($st(3))) },
$F := map {
  'date': $fmt_date, 'time': $fmt_time(?, true()), 'date-time': $fmt_datetime(?, true(), false()),
  'time#v1': $fmt_time(?, false()), 'date-time#v1': $fmt_datetime(?, true(), true()),
  'time#draft3': function($s) { matches($s, '^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$') },
  'color#draft3': function($s) { matches($s, '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$') or $s = ('aqua', 'black', 'blue', 'fuchsia',
      'gray', 'green', 'lime', 'maroon', 'navy', 'olive', 'orange', 'purple', 'red', 'silver', 'teal', 'white', 'yellow') },
  'duration': $fmt_duration,
  'email': $fmt_mailbox(?, false()), 'idn-email': $fmt_mailbox(?, true()),
  'hostname': $fmt_hostname(?, false()), 'host-name': $fmt_hostname(?, false()),
  'hostname#rfc1123': function($s) { $s ne '' and string-length($s) le 253
      and (every $l in tokenize($s, '\.') satisfies matches($l, '^[A-Za-z0-9]([A-Za-z0-9\-]{0,61}[A-Za-z0-9])?$')) }, 'idn-hostname': $fmt_hostname(?, true()),
  'ipv4': $fmt_ipv4, 'ip-address': $fmt_ipv4, 'ipv6': $fmt_ipv6,
  'uri': function($s) { matches($s, '^[A-Za-z][A-Za-z0-9+.\-]*:') and $fmt_uriref($s, false()) },
  'uri-reference': $fmt_uriref(?, false()),
  'iri': function($s) { matches($s, '^[A-Za-z][A-Za-z0-9+.\-]*:') and $fmt_uriref($s, true()) },
  'iri-reference': $fmt_uriref(?, true()),
  'uri-template': $fmt_template,
  'json-pointer': function($s) { matches($s, '^(/([^/~]|~[01])*)*$') },
  'relative-json-pointer': function($s) { matches($s, '^(0|[1-9][0-9]*)(#|(/([^/~]|~[01])*)*)$') },
  'uuid': function($s) { matches($s, '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') },
  'regex': $fmt_regex }</xsl:text>
  </xsl:variable>

  <!-- ================================================================== -->
  <!-- Walking schemas: base URIs, resources, anchors                     -->
  <!-- ================================================================== -->

  <!-- The keywords whose values are subschemas, per dialect:
       'one' a schema, 'list' an array of schemas, 'map' an object of schemas,
       'one-or-list' either. -->
  <xsl:function name="c:subschema-keywords" as="map(xs:string, xs:string)">
    <xsl:param name="d" as="xs:integer"/>
    <xsl:sequence select="map:merge((
        map { 'additionalProperties': 'one', 'properties': 'map', 'patternProperties': 'map',
              'dependencies': 'map', 'definitions': 'map' },
        if ($d le 2019) then map { 'items': 'one-or-list', 'additionalItems': 'one' }
                        else map { 'items': 'one', 'prefixItems': 'list' },
        if ($d eq 3) then map { 'extends': 'one-or-list', 'type': 'list', 'disallow': 'list' }
                     else map { 'allOf': 'list', 'anyOf': 'list', 'oneOf': 'list', 'not': 'one' },
        if ($d ge 6) then map { 'contains': 'one', 'propertyNames': 'one' } else (),
        if ($d ge 7) then map { 'if': 'one', 'then': 'one', 'else': 'one' } else (),
        if ($d ge 2100) then map { 'propertyDependencies': 'map-map' } else (),
        if ($d ge 2019) then map { '$defs': 'map', 'dependentSchemas': 'map',
              'unevaluatedItems': 'one', 'unevaluatedProperties': 'one', 'contentSchema': 'one' } else ()
      ))"/>
  </xsl:function>

  <xsl:function name="c:is-schema" as="xs:boolean">
    <xsl:param name="n" as="element()?"/>
    <xsl:sequence select="exists($n/(self::fn:map | self::fn:boolean))"/>
  </xsl:function>

  <xsl:function name="c:subschemas" as="element()*">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="d" as="xs:integer"/>
    <xsl:variable name="kw" select="c:subschema-keywords($d)"/>
    <xsl:for-each select="$s/self::fn:map/*">
      <xsl:variable name="kind" select="$kw(c:key(.))"/>
      <xsl:choose>
        <xsl:when test="empty($kind)"/>
        <xsl:when test="c:is-schema(.) and $kind = ('one', 'one-or-list')">
          <xsl:sequence select="."/>
        </xsl:when>
        <xsl:when test="self::fn:array and $kind = ('list', 'one-or-list')">
          <xsl:sequence select="*[c:is-schema(.)]"/>
        </xsl:when>
        <xsl:when test="self::fn:map and $kind eq 'map'">
          <xsl:sequence select="*[c:is-schema(.)]"/>
        </xsl:when>
        <xsl:when test="self::fn:map and $kind eq 'map-map'">
          <xsl:sequence select="fn:map/*[c:is-schema(.)]"/>
        </xsl:when>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <!-- Walks a schema and its subschemas. One map per schema:
       n (node), base (base URI), res (URI of the schema resource), d (dialect),
       uris (URIs that identify this node as a resource), anchors (absolute
       URIs with plain-name fragment), danchors ($dynamicAnchor names),
       ranchor ($recursiveAnchor: true). -->
  <xsl:function name="c:walk" as="map(*)*">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="base" as="xs:string"/>
    <xsl:param name="res" as="xs:string?"/>
    <xsl:param name="d" as="xs:integer"/>
    <xsl:param name="is-resource" as="xs:boolean"/>
    <xsl:param name="vocab" as="map(*)"/>

    <xsl:variable name="m" select="$s/self::fn:map"/>
    <xsl:variable name="has-id" select="exists($m) and not($d le 7 and exists(c:kw($m, '$ref')))"/>
    <xsl:variable name="id" as="xs:string?"
        select="if ($has-id) then c:kw($m, if ($d le 4) then 'id' else '$id')/self::fn:string/c:str(.) else ()"/>
    <xsl:variable name="meta" as="element()?"
        select="if (exists($id) or $is-resource) then c:custom-meta-schema($s) else ()"/>
    <xsl:variable name="d" select="if (exists($meta)) then c:detect-dialect($meta, $d)
        else if (exists($id) or $is-resource) then c:detect-dialect($s, $d) else $d"/>
    <!-- A custom meta-schema whose $vocabulary lacks the validation vocabulary
         turns off the validation keywords of the resource; one with the
         format-assertion vocabulary turns on format assertions. -->
    <xsl:variable name="vocabularies" select="c:kw($meta, '$vocabulary')/*/c:key(.)"/>
    <xsl:variable name="vocab" select="
        if (exists($meta) and $d ge 2019 and exists($vocabularies)) then map {
            'noval': not($vocabularies[ends-with(., '/vocab/validation')]),
            'fmt': $vocab?fmt or exists($vocabularies[ends-with(., '/vocab/format-assertion')]) }
        else $vocab"/>
    <xsl:variable name="id-uri" as="xs:string?"
        select="if (exists($id) and not(starts-with($id, '#'))) then c:resolve($id, $base) else ()"/>
    <xsl:variable name="new-base" select="if (exists($id-uri)) then c:strip-fragment($id-uri) else $base"/>
    <xsl:variable name="id-fragment" select="if (exists($id-uri)) then substring-after($id-uri, '#')
        else if (exists($id)) then substring($id, 2) else ''"/>
    <xsl:variable name="new-res" select="if (exists($id-uri) or empty($res)) then $new-base else $res"/>

    <xsl:map>
      <xsl:map-entry key="'n'" select="$s"/>
      <xsl:map-entry key="'base'" select="$new-base"/>
      <xsl:map-entry key="'res'" select="$new-res"/>
      <xsl:map-entry key="'d'" select="$d"/>
      <xsl:map-entry key="'vocab'" select="$vocab"/>
      <xsl:map-entry key="'noval'" select="$vocab?noval"/>
      <xsl:map-entry key="'fmt'" select="$vocab?fmt"/>
      <xsl:map-entry key="'uris'" select="distinct-values((
          if ($is-resource) then $base else (), if (exists($id-uri)) then $new-base else ()))"/>
      <xsl:map-entry key="'anchors'" select="(
          if ($id-fragment ne '' and $d le 7) then $new-base || '#' || $id-fragment else (),
          if ($d ge 2019) then (c:kw($m, '$anchor'), c:kw($m, '$dynamicAnchor'))/self::fn:string
              ! ($new-base || '#' || c:str(.)) else ())"/>
      <xsl:map-entry key="'danchors'"
          select="if ($d ge 2020) then c:kw($m, '$dynamicAnchor')/self::fn:string/c:str(.) else ()"/>
      <xsl:map-entry key="'ranchor'"
          select="$d eq 2019 and c:kw($m, '$recursiveAnchor')/self::fn:boolean = 'true'"/>
    </xsl:map>
    <xsl:for-each select="c:subschemas($s, $d)">
      <xsl:sequence select="c:walk(., $new-base, $new-res, $d, false(), $vocab)"/>
    </xsl:for-each>
  </xsl:function>

  <xsl:function name="c:registry" as="map(*)">
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:sequence select="map {
        'info': map:merge($entries ! map:entry(generate-id(?n), .), map { 'duplicates': 'use-first' }),
        'res': map:merge($entries ! (let $e := . return ?uris ! map:entry(., $e?n)),
            map { 'duplicates': 'use-first' }),
        'anchors': map:merge($entries ! (let $e := . return ?anchors ! map:entry(., $e?n)),
            map { 'duplicates': 'use-first' })
      }"/>
  </xsl:function>

  <!-- Absolute URIs of all references in the entries. -->
  <xsl:function name="c:references" as="xs:string*">
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:sequence select="distinct-values($entries ! (let $e := . return
        ($e?n/self::fn:map/*[c:key(.) = ('$ref', '$dynamicRef', '$recursiveRef')]/self::fn:string)
        ! c:resolve(c:str(.), $e?base)))"/>
  </xsl:function>

  <!-- Adds remote documents and JSON-pointer targets outside the known
       keywords until all references can be resolved. -->
  <xsl:function name="c:closure" as="map(*)*">
    <xsl:param name="entries" as="map(*)*"/>
    <xsl:param name="tried" as="xs:string*"/>
    <xsl:param name="dialect" as="xs:integer"/>
    <xsl:param name="format" as="xs:boolean"/>
    <xsl:variable name="reg" select="c:registry($entries)"/>
    <xsl:variable name="refs" select="c:references($entries)"/>
    <xsl:variable name="missing" select="distinct-values($refs ! c:strip-fragment(.))
        [not(map:contains($reg?res, .)) and not(. = $tried)]"/>
    <xsl:choose>
      <xsl:when test="exists($missing)">
        <xsl:variable name="loaded" as="map(*)*">
          <xsl:for-each select="$missing">
            <xsl:variable name="doc" select="c:load(.)"/>
            <xsl:if test="exists($doc)">
              <xsl:sequence select="c:walk($doc, ., (), c:detect-dialect($doc, $dialect), true(), map { 'noval': false(), 'fmt': $format })"/>
            </xsl:if>
          </xsl:for-each>
        </xsl:variable>
        <xsl:sequence select="c:closure(($entries, $loaded), ($tried, $missing), $dialect, $format)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="targets" as="element()*"
            select="($refs ! c:target(., $reg, false()))[not(map:contains($reg?info, generate-id(.)))]"/>
        <xsl:variable name="added" as="map(*)*">
          <xsl:for-each select="$targets/.">
            <xsl:variable name="owner" select="$reg?info(generate-id(ancestor::*[map:contains($reg?info, generate-id(.))][1]))"/>
            <xsl:sequence select="c:walk(., $owner?base, $owner?res, $owner?d, false(), $owner?vocab)"/>
          </xsl:for-each>
        </xsl:variable>
        <xsl:sequence select="if (exists($added)) then c:closure(($entries, $added), $tried, $dialect, $format) else $entries"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Reads a remote schema: below remotes-base from remotes-dir, any other
       http(s) URI from the network (if allowed). -->
  <xsl:function name="c:load" as="element()?">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:variable name="location" as="xs:string?" select="
        if (starts-with($uri, $remotes-base))
        then string(resolve-uri(substring-after($uri, $remotes-base), $remotes-uri))
        else if (matches($uri, '^https?://')) then $uri else ()"/>
    <xsl:if test="exists($location) and unparsed-text-available($location)">
      <xsl:sequence select="json-to-xml(unparsed-text($location), map { 'escape': true() })/*"/>
    </xsl:if>
  </xsl:function>

  <!-- The schema an absolute URI identifies. -->
  <xsl:function name="c:target" as="element()?">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:param name="reg" as="map(*)"/>
    <xsl:param name="required" as="xs:boolean"/>
    <xsl:variable name="res" select="$reg?res(c:strip-fragment($uri))"/>
    <xsl:variable name="fragment" select="substring-after($uri, '#')"/>
    <xsl:variable name="target" as="element()?" select="
        if (empty($res)) then ()
        else if ($fragment eq '') then $res
        else if (starts-with($fragment, '/')) then c:pointer($res, c:percent-decode($fragment))
        else $reg?anchors(c:strip-fragment($uri) || '#' || c:percent-decode($fragment))"/>
    <xsl:if test="$required and not(c:is-schema($target))">
      <xsl:message terminate="yes" error-code="c:UNRESOLVED"
          select="'Cannot resolve reference ' || $uri"/>
    </xsl:if>
    <xsl:sequence select="$target"/>
  </xsl:function>

  <xsl:function name="c:pointer" as="element()?">
    <xsl:param name="root" as="element()"/>
    <xsl:param name="pointer" as="xs:string"/>
    <xsl:sequence select="fold-left(tail(tokenize($pointer, '/')), $root, function($n, $t) {
        let $t := replace(replace($t, '~1', '/'), '~0', '~')
        return if ($n/self::fn:map) then $n/*[c:key(.) eq $t][1]
          else if ($n/self::fn:array and $t castable as xs:integer) then $n/*[xs:integer($t) + 1]
          else () })"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- Code generation                                                    -->
  <!-- ================================================================== -->

  <xsl:function name="c:fkey" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:sequence select="'k_' || generate-id($n) || '_k'"/>
  </xsl:function>

  <!-- Call of the function of schema $s on the instance node expression $inst. -->
  <xsl:function name="c:call" as="xs:string">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="inst" as="xs:string"/>
    <xsl:sequence select="'$S(' || c:lit(c:fkey($s)) || ')($S, ' || $inst || ', $dyn)'"/>
  </xsl:function>

  <!-- Body of the function of one schema. -->
  <xsl:function name="c:schema-body" as="xs:string">
    <xsl:param name="e" as="map(*)"/>
    <xsl:param name="reg" as="map(*)"/>
    <xsl:variable name="s" select="$e?n"/>
    <xsl:variable name="d" select="$e?d"/>
    <xsl:choose>
      <xsl:when test="$s/self::fn:boolean">
        <xsl:sequence select="'map { ''v'': ' || (if ($s = 'true') then 'true()' else 'false()') || ' }'"/>
      </xsl:when>
      <xsl:when test="$d le 7 and exists(c:kw($s, '$ref'))">
        <xsl:sequence select="'let $dyn := ($dyn, ' || c:lit($e?res) || ') return '
            || c:call(c:target(c:resolve(c:str(c:kw($s, '$ref')), $e?base), $reg, true()), '$n')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="parts" as="xs:string*" select="c:keywords($e, $reg)"/>
        <xsl:variable name="unevaluated" as="xs:string*" select="c:unevaluated($e, count($parts))"/>
        <xsl:variable name="all" select="($parts, $unevaluated)"/>
        <xsl:variable name="vars" select="(1 to count($all)) ! ('$k' || .)"/>
        <xsl:sequence select="
          if (empty($all)) then '$T'
          else 'let $dyn := if ($dyn[last()] = ' || c:lit($e?res) || ') then $dyn else ($dyn, '
            || c:lit($e?res) || '), '
            || string-join(for $i in 1 to count($all) return $vars[$i] || ' := ' || $all[$i], ', ')
            || ' return map { ''v'': ' || string-join($vars ! (. || '?v'), ' and ')
            || ', ''p'': (' || string-join($vars ! (. || '?p'), ', ')
            || '), ''i'': (' || string-join($vars ! (. || '?i'), ', ') || ') }'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Wraps a keyword result for one instance type. -->
  <xsl:function name="c:on" as="xs:string">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="expr" as="xs:string"/>
    <xsl:sequence select="'(if (' || c:kind-test($type) || ') then (' || $expr || ') else $T)'"/>
  </xsl:function>

  <!-- Test whether the instance node $n is of a kind (map, array, string,
       number, boolean, null), in the chosen instance format. -->
  <xsl:function name="c:kind-test" as="xs:string">
    <xsl:param name="kind" as="xs:string"/>
    <xsl:sequence select="if (not($elements)) then '$n/self::fn:' || $kind
        else if ($kind eq 'string') then 'not($n/@type)'
        else '$n/@type = ' || c:lit(if ($kind eq 'map') then 'object' else $kind)"/>
  </xsl:function>

  <xsl:function name="c:valid" as="xs:string">
    <xsl:param name="test" as="xs:string"/>
    <xsl:sequence select="'map { ''v'': ' || $test || ' }'"/>
  </xsl:function>

  <!-- Merges a sequence of results ($r) that must all be valid. -->
  <xsl:function name="c:all-of" as="xs:string">
    <xsl:param name="calls" as="xs:string*"/>
    <xsl:sequence select="if (empty($calls)) then '$T' else
        'let $r := (' || string-join($calls, ', ') || ') return map { ''v'': every $x in $r satisfies $x?v, ''p'': $r?p, ''i'': $r?i }'"/>
  </xsl:function>

  <xsl:function name="c:keywords" as="xs:string*">
    <xsl:param name="e" as="map(*)"/>
    <xsl:param name="reg" as="map(*)"/>
    <xsl:variable name="s" select="$e?n"/>
    <xsl:variable name="d" select="$e?d"/>
    <xsl:variable name="base" select="$e?base"/>
    <!-- the schema as seen by the validation vocabulary -->
    <xsl:variable name="v" select="if ($e?noval) then () else $s"/>

    <!-- type, disallow -->
    <xsl:for-each select="c:kw($v, 'type')">
      <xsl:sequence select="c:valid(c:type-test(., $d))"/>
    </xsl:for-each>
    <xsl:if test="$d eq 3">
      <xsl:for-each select="c:kw($v, 'disallow')">
        <xsl:sequence select="c:valid('not(' || c:type-test(., $d) || ')')"/>
      </xsl:for-each>
    </xsl:if>

    <!-- enum, const -->
    <xsl:for-each select="c:kw($v, 'enum')/self::fn:array">
      <xsl:sequence select="c:valid('(some $e in ' || c:constant(.) || '/* satisfies $eq($eq, $n, $e))')"/>
    </xsl:for-each>
    <xsl:if test="$d ge 6">
      <xsl:for-each select="c:kw($v, 'const')">
        <xsl:sequence select="c:valid('$eq($eq, $n, ' || c:constant(.) || ')')"/>
      </xsl:for-each>
    </xsl:if>

    <!-- numbers -->
    <xsl:variable name="excl-min" select="$d le 4 and c:kw($v, 'exclusiveMinimum') = 'true'"/>
    <xsl:variable name="excl-max" select="$d le 4 and c:kw($v, 'exclusiveMaximum') = 'true'"/>
    <xsl:for-each select="c:kw($v, 'minimum')/self::fn:number">
      <xsl:sequence select="c:on('number', c:valid('$num($n) ' || (if ($excl-min) then 'gt' else 'ge') || ' ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:for-each select="c:kw($v, 'maximum')/self::fn:number">
      <xsl:sequence select="c:on('number', c:valid('$num($n) ' || (if ($excl-max) then 'lt' else 'le') || ' ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:if test="$d ge 6">
      <xsl:for-each select="c:kw($v, 'exclusiveMinimum')/self::fn:number">
        <xsl:sequence select="c:on('number', c:valid('$num($n) gt ' || c:number(.)))"/>
      </xsl:for-each>
      <xsl:for-each select="c:kw($v, 'exclusiveMaximum')/self::fn:number">
        <xsl:sequence select="c:on('number', c:valid('$num($n) lt ' || c:number(.)))"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:for-each select="c:kw($v, if ($d eq 3) then 'divisibleBy' else 'multipleOf')/self::fn:number">
      <xsl:sequence select="c:on('number', c:valid('$mult($num($n), ' || c:number(.) || ')'))"/>
    </xsl:for-each>

    <!-- strings -->
    <xsl:for-each select="c:kw($v, 'minLength')/self::fn:number">
      <xsl:sequence select="c:on('string', c:valid('string-length($str($n)) ge ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:for-each select="c:kw($v, 'maxLength')/self::fn:number">
      <xsl:sequence select="c:on('string', c:valid('string-length($str($n)) le ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:for-each select="c:kw($v, 'pattern')/self::fn:string">
      <xsl:sequence select="c:on('string', c:valid('matches($str($n), ' || c:regex(c:str(.)) || ')'))"/>
    </xsl:for-each>

    <xsl:if test="$e?fmt">
      <xsl:for-each select="c:kw($s, 'format')/self::fn:string[c:str(.) = $format-names]">
        <xsl:variable name="name" select="c:str(.)"/>
        <xsl:variable name="variant" select="
            if ($d ge 2100 and $name = ('time', 'date-time')) then $name || '#v1'
            else if ($d eq 3 and $name = ('time', 'color')) then $name || '#draft3'
            else if ($d le 6 and $name = ('hostname', 'host-name')) then 'hostname#rfc1123'
            else $name"/>
        <xsl:sequence select="c:on('string', c:valid('$F(' || c:lit($variant) || ')($str($n))'))"/>
      </xsl:for-each>
    </xsl:if>

    <xsl:if test="$d eq 7 and c:kw($s, 'contentEncoding') = 'base64'">
      <xsl:sequence select="c:on('string', c:valid('(let $b := replace($str($n), ''\s'', '''') return matches($b, ''^[A-Za-z0-9+/]*={0,2}$'') and string-length($b) mod 4 eq 0)'))"/>
    </xsl:if>

    <!-- arrays -->
    <xsl:for-each select="c:kw($v, 'minItems')/self::fn:number">
      <xsl:sequence select="c:on('array', c:valid('count($n/*) ge ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:for-each select="c:kw($v, 'maxItems')/self::fn:number">
      <xsl:sequence select="c:on('array', c:valid('count($n/*) le ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:if test="c:kw($v, 'uniqueItems') = 'true'">
      <xsl:sequence select="c:on('array', c:valid('(every $i in 1 to count($n/*) - 1 satisfies every $j in $i + 1 to count($n/*) satisfies not($eq($eq, $n/*[$i], $n/*[$j])))'))"/>
    </xsl:if>
    <xsl:variable name="items" select="c:kw($s, 'items')"/>
    <xsl:variable name="prefix" as="element()*" select="
        if ($d le 2019) then $items/self::fn:array/*
        else c:kw($s, 'prefixItems')/self::fn:array/*"/>
    <xsl:if test="exists($prefix)">
      <xsl:sequence select="c:on('array', 'map { ''v'': ' || string-join(for $i in 1 to count($prefix) return
          '(let $c := $n/*[' || $i || '] return empty($c) or ' || c:call($prefix[$i], '$c') || '?v)', ' and ')
          || ', ''i'': 1 to min((count($n/*), ' || count($prefix) || ')) }')"/>
    </xsl:if>
    <xsl:variable name="rest" as="element()?" select="
        if ($d le 2019 and $items/self::fn:array) then c:kw($s, 'additionalItems')[c:is-schema(.)]
        else $items[c:is-schema(.)]"/>
    <xsl:if test="exists($rest)">
      <xsl:variable name="p" select="count($prefix)"/>
      <xsl:sequence select="c:on('array', 'let $a := $n/*[position() gt ' || $p || '] return map { ''v'': every $c in $a satisfies '
          || c:call($rest, '$c') || '?v, ''i'': ' || $p + 1 || ' to count($n/*) }')"/>
    </xsl:if>
    <xsl:if test="$d ge 6">
      <xsl:for-each select="c:kw($s, 'contains')[c:is-schema(.)]">
        <xsl:variable name="min" select="if ($d ge 2019) then (c:kw($v, 'minContains')/self::fn:number/c:number(.), '1')[1] else '1'"/>
        <xsl:variable name="max" select="if ($d ge 2019) then c:kw($v, 'maxContains')/self::fn:number/c:number(.) else ()"/>
        <xsl:sequence select="c:on('array', 'let $m := (for $i in 1 to count($n/*) return if (' || c:call(., '$n/*[$i]')
            || '?v) then $i else ()) return map { ''v'': count($m) ge ' || $min
            || (if (exists($max)) then ' and count($m) le ' || $max else '')
            || (if ($d ge 2020) then ', ''i'': $m' else '') || ' }')"/>
      </xsl:for-each>
    </xsl:if>

    <!-- objects -->
    <xsl:for-each select="c:kw($v, 'minProperties')/self::fn:number">
      <xsl:sequence select="c:on('map', c:valid('count($n/*) ge ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:for-each select="c:kw($v, 'maxProperties')/self::fn:number">
      <xsl:sequence select="c:on('map', c:valid('count($n/*) le ' || c:number(.)))"/>
    </xsl:for-each>
    <xsl:if test="$d ge 4">
      <xsl:for-each select="c:kw($v, 'required')/self::fn:array[*]">
        <xsl:sequence select="c:on('map', c:valid('(every $r in (' || c:string-list(*) || ') satisfies exists($n/*[$key(.) eq $r]))'))"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:variable name="props" as="element()*" select="c:kw($s, 'properties')/self::fn:map/*[c:is-schema(.)]"/>
    <xsl:if test="exists($props)">
      <xsl:sequence select="c:on('map', 'map { ''v'': ' || string-join($props ! ('(let $c := $n/*[$key(.) eq '
          || c:lit(c:key(.)) || '][1] return if (exists($c)) then ' || c:call(., '$c') || '?v else '
          || (if ($d eq 3 and c:kw(., 'required') = 'true') then 'false()' else 'true()') || ')'), ' and ')
          || ', ''p'': $n/*[$key(.) = (' || c:string-list-keys($props) || ')] ! $key(.) }')"/>
    </xsl:if>
    <xsl:variable name="patterns" as="element()*" select="c:kw($s, 'patternProperties')/self::fn:map/*[c:is-schema(.)]"/>
    <xsl:if test="exists($patterns)">
      <xsl:sequence select="c:on('map', 'map { ''v'': ' || string-join($patterns ! ('(every $c in $n/*[matches($key(.), '
          || c:regex(c:key(.)) || ')] satisfies ' || c:call(., '$c') || '?v)'), ' and ')
          || ', ''p'': $n/*[' || string-join($patterns ! ('matches($key(.), ' || c:regex(c:key(.)) || ')'), ' or ')
          || '] ! $key(.) }')"/>
    </xsl:if>
    <xsl:for-each select="c:kw($s, 'additionalProperties')[c:is-schema(.)]">
      <xsl:variable name="known" select="c:kw($s, 'properties')/self::fn:map/*"/>
      <xsl:variable name="filter" select="string-join((
          if (exists($known)) then 'not($key(.) = (' || c:string-list-keys($known) || '))' else (),
          c:kw($s, 'patternProperties')/self::fn:map/* ! ('not(matches($key(.), ' || c:regex(c:key(.)) || '))')), ' and ')"/>
      <xsl:sequence select="c:on('map', 'let $a := $n/*' || (if ($filter) then '[' || $filter || ']' else '')
          || ' return map { ''v'': every $c in $a satisfies ' || c:call(., '$c') || '?v, ''p'': $a ! $key(.) }')"/>
    </xsl:for-each>
    <xsl:if test="$d ge 6">
      <xsl:for-each select="c:kw($s, 'propertyNames')[c:is-schema(.)]">
        <xsl:sequence select="c:on('map', c:valid('(every $c in $n/* satisfies '
            || c:call(., if ($elements) then 'parse-xml(''&lt;json&gt;'' || $xmlesc($key($c)) || ''&lt;/json&gt;'')/*'
                         else 'json-to-xml(serialize($key($c), map { ''method'': ''json'' }))/*') || '?v)'))"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:variable name="dependencies" as="element()*" select="
        c:kw($s, 'dependencies')/self::fn:map/*,
        (if ($d ge 2019) then c:kw($v, 'dependentRequired')/self::fn:map/fn:array else ())"/>
    <xsl:variable name="required-deps" select="$dependencies[self::fn:array or self::fn:string]"/>
    <xsl:if test="exists($required-deps)">
      <xsl:sequence select="c:on('map', c:valid(string-join($required-deps ! ('(not(exists($n/*[$key(.) eq ' || c:lit(c:key(.))
          || '])) or (every $r in (' || c:string-list(self::fn:array/* | self::fn:string) || ') satisfies exists($n/*[$key(.) eq $r])))'), ' and ')))"/>
    </xsl:if>
    <xsl:variable name="schema-deps" as="element()*" select="
        $dependencies[c:is-schema(.)],
        (if ($d ge 2019) then c:kw($s, 'dependentSchemas')/self::fn:map/*[c:is-schema(.)] else ())"/>
    <xsl:if test="exists($schema-deps)">
      <xsl:sequence select="c:on('map', c:all-of($schema-deps ! ('(if (exists($n/*[$key(.) eq ' || c:lit(c:key(.))
          || '])) then ' || c:call(., '$n') || ' else ())')))"/>
    </xsl:if>

    <xsl:if test="$d ge 2100">
      <xsl:variable name="property-deps" as="element()*"
          select="c:kw($s, 'propertyDependencies')/self::fn:map/fn:map/*[c:is-schema(.)]"/>
      <xsl:if test="exists($property-deps)">
        <xsl:sequence select="c:on('map', c:all-of($property-deps ! ('(if (some $c in $n/*[$key(.) eq ' || c:lit(c:key(..))
            || '] satisfies (' || replace(c:kind-test('string'), '\$n', '\$c') || ' and $str($c) eq ' || c:lit(c:key(.)) || ')) then ' || c:call(., '$n') || ' else ())')))"/>
      </xsl:if>
    </xsl:if>

    <!-- applicators -->
    <xsl:variable name="all" as="element()*" select="
        if ($d eq 3) then c:kw($s, 'extends')/(self::fn:map | self::fn:boolean | self::fn:array/*[c:is-schema(.)])
        else c:kw($s, 'allOf')/self::fn:array/*[c:is-schema(.)]"/>
    <xsl:if test="exists($all)">
      <xsl:sequence select="c:all-of($all ! c:call(., '$n'))"/>
    </xsl:if>
    <xsl:if test="$d ge 4">
      <xsl:for-each select="c:kw($s, 'anyOf')/self::fn:array[*]">
        <xsl:sequence select="'let $r := (' || string-join(*[c:is-schema(.)] ! c:call(., '$n'), ', ')
            || '), $ok := $r[?v] return map { ''v'': exists($ok), ''p'': $ok?p, ''i'': $ok?i }'"/>
      </xsl:for-each>
      <xsl:for-each select="c:kw($s, 'oneOf')/self::fn:array[*]">
        <xsl:sequence select="'let $r := (' || string-join(*[c:is-schema(.)] ! c:call(., '$n'), ', ')
            || '), $ok := $r[?v] return map { ''v'': count($ok) eq 1, ''p'': $ok?p, ''i'': $ok?i }'"/>
      </xsl:for-each>
      <xsl:for-each select="c:kw($s, 'not')[c:is-schema(.)]">
        <xsl:sequence select="c:valid('not(' || c:call(., '$n') || '?v)')"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:if test="$d ge 7">
      <xsl:for-each select="c:kw($s, 'if')[c:is-schema(.)]">
        <xsl:variable name="then" select="c:kw($s, 'then')[c:is-schema(.)]"/>
        <xsl:variable name="else" select="c:kw($s, 'else')[c:is-schema(.)]"/>
        <xsl:sequence select="'let $f := ' || c:call(., '$n') || ' return if ($f?v) then '
            || (if (exists($then)) then '(let $t := ' || c:call($then, '$n')
                || ' return map { ''v'': $t?v, ''p'': ($f?p, $t?p), ''i'': ($f?i, $t?i) })' else '$f')
            || ' else ' || (if (exists($else)) then c:call($else, '$n') else '$T')"/>
      </xsl:for-each>
    </xsl:if>

    <!-- references (dialects from 2019-09 on; earlier ones are handled in c:schema-body) -->
    <xsl:for-each select="c:kw($s, '$ref')/self::fn:string">
      <xsl:sequence select="c:call(c:target(c:resolve(c:str(.), $base), $reg, true()), '$n')"/>
    </xsl:for-each>
    <xsl:if test="$d ge 2020">
      <xsl:for-each select="c:kw($s, '$dynamicRef')/self::fn:string">
        <xsl:variable name="uri" select="c:resolve(c:str(.), $base)"/>
        <xsl:variable name="name" select="substring-after($uri, '#')"/>
        <!-- v1: a plain-name fragment is resolved in the dynamic scope only;
             2020-12: only if the static target is a $dynamicAnchor (bookending). -->
        <xsl:variable name="v1-dynamic" select="$d ge 2100 and $name ne '' and not(starts-with($name, '/'))"/>
        <xsl:variable name="target" select="c:target($uri, $reg, not($v1-dynamic))"/>
        <xsl:sequence select="
            if ($v1-dynamic or ($name ne '' and not(starts-with($name, '/'))
                and $reg?info(generate-id($target))?danchors = $name))
            then 'let $k := (' || string-join(('(for $r in $dyn return $DA($r)?(' || c:lit($name) || '))',
                    $target[$reg?info(generate-id(.))?danchors = $name] ! c:lit(c:fkey(.))), ', ')
                || ')[1] return if (exists($k)) then $S($k)($S, $n, $dyn) else map { ''v'': false() }'
            else c:call($target, '$n')"/>
      </xsl:for-each>
    </xsl:if>
    <xsl:if test="$d eq 2019">
      <xsl:for-each select="c:kw($s, '$recursiveRef')/self::fn:string">
        <xsl:variable name="target" select="c:target(c:resolve(c:str(.), $base), $reg, true())"/>
        <xsl:sequence select="
            if ($reg?info(generate-id($target))?ranchor)
            then 'let $k := ((for $r in $dyn return $RA($r)), ' || c:lit(c:fkey($target))
                || ')[1] return $S($k)($S, $n, $dyn)'
            else c:call($target, '$n')"/>
      </xsl:for-each>
    </xsl:if>
  </xsl:function>

  <!-- unevaluatedProperties / unevaluatedItems: use the annotations of the
       $count keyword results before them ($k1 ... $kN). -->
  <xsl:function name="c:unevaluated" as="xs:string*">
    <xsl:param name="e" as="map(*)"/>
    <xsl:param name="count" as="xs:integer"/>
    <xsl:variable name="s" select="$e?n"/>
    <xsl:if test="$e?d ge 2019">
      <xsl:variable name="vars" select="(1 to $count) ! ('$k' || .)"/>
      <xsl:for-each select="c:kw($s, 'unevaluatedProperties')[c:is-schema(.)]">
        <xsl:sequence select="c:on('map', 'let $a := $n/*[not($key(.) = (' || string-join($vars ! (. || '?p'), ', ')
            || '))] return map { ''v'': every $c in $a satisfies ' || c:call(., '$c') || '?v, ''p'': $a ! $key(.) }')"/>
      </xsl:for-each>
      <xsl:for-each select="c:kw($s, 'unevaluatedItems')[c:is-schema(.)]">
        <xsl:sequence select="c:on('array', 'let $ev := (' || string-join($vars ! (. || '?i'), ', ')
            || '), $a := (1 to count($n/*))[not(. = $ev)] return map { ''v'': every $i in $a satisfies '
            || c:call(., '$n/*[$i]') || '?v, ''i'': $a }')"/>
      </xsl:for-each>
    </xsl:if>
  </xsl:function>

  <xsl:function name="c:type-test" as="xs:string">
    <xsl:param name="type" as="element()"/>
    <xsl:param name="d" as="xs:integer"/>
    <xsl:variable name="tests" as="xs:string*">
      <xsl:for-each select="$type/self::fn:string | $type/self::fn:array/* | $type/self::fn:map">
        <xsl:choose>
          <xsl:when test="self::fn:map">
            <xsl:sequence select="c:call(., '$n') || '?v'"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="map {
                'object': c:kind-test('map'), 'array': c:kind-test('array'),
                'string': c:kind-test('string'), 'number': c:kind-test('number'),
                'integer': if ($d le 4) then '(' || c:kind-test('number') || ' and not(contains($n, ''.'')) and $isint($n))'
                           else '(' || c:kind-test('number') || ' and $isint($n))',
                'boolean': c:kind-test('boolean'), 'null': c:kind-test('null'),
                'any': 'true()' }(c:str(.))"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    <xsl:sequence select="if (empty($tests)) then 'false()' else '(' || string-join($tests, ' or ') || ')'"/>
  </xsl:function>

  <!-- A JSON value of the schema as an expression that rebuilds its XML
       representation at run time. -->
  <xsl:function name="c:constant" as="xs:string">
    <xsl:param name="v" as="element()"/>
    <xsl:variable name="copy" as="element()">
      <xsl:element name="{local-name($v)}" namespace="http://www.w3.org/2005/xpath-functions">
        <xsl:copy-of select="$v/@escaped, $v/node()"/>
      </xsl:element>
    </xsl:variable>
    <xsl:sequence select="if ($elements) then 'parse-xml(' || c:lit(serialize(je:from-xpath-json($copy))) || ')/*'
        else 'json-to-xml(' || c:lit(xml-to-json($copy)) || ', map { ''escape'': true() })/*'"/>
  </xsl:function>

  <xsl:function name="c:number" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:sequence select="if (matches($n, '[eE]')) then '$num(' || c:lit(normalize-space($n)) || ')'
        else '(' || normalize-space($n) || ')'"/>
  </xsl:function>

  <xsl:function name="c:string-list" as="xs:string">
    <xsl:param name="strings" as="element()*"/>
    <xsl:sequence select="string-join($strings/self::fn:string ! c:lit(c:str(.)), ', ')"/>
  </xsl:function>

  <xsl:function name="c:string-list-keys" as="xs:string">
    <xsl:param name="members" as="element()*"/>
    <xsl:sequence select="string-join($members ! c:lit(c:key(.)), ', ')"/>
  </xsl:function>

  <!-- XPath string literal. -->
  <xsl:function name="c:lit" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="if (je:xml-safe($s)) then '''' || replace($s, '''', '''''') || ''''
        else '(' || string-join(analyze-string($s, '[&#x9;&#xA;&#xD;&#x20;-&#xD7FF;&#xE000;-&#xFFFD;&#x10000;-&#x10FFFF;]+')/* ! (
            if (self::fn:match) then '''' || replace(string(.), '''', '''''') || ''''
            else 'codepoints-to-string((' || string-join(string-to-codepoints(.) ! string(.), ', ') || '))'), ' || ') || ')'"/>
  </xsl:function>

  <!-- ECMA-262 regular expression to an XPath regular expression literal. -->
  <xsl:function name="c:regex-raw" as="xs:string">
    <xsl:param name="re" as="xs:string"/>
    <xsl:variable name="tokens" as="xs:string*">
      <xsl:iterate select="analyze-string($re, '\\[pP]\{[^}]*\}|\\u\{[0-9a-fA-F]+\}|\\u[0-9a-fA-F]{4}|\\x[0-9a-fA-F]{2}|\\c[A-Za-z]|\\.|\[\^?|\]|.', 's')/fn:match/string()">
        <xsl:param name="in-class" select="false()"/>
        <xsl:variable name="t" select="."/>
        <xsl:variable name="code" as="xs:integer?" select="
            if (matches($t, '^\\(u\{?|x)')) then c:hex(replace($t, '^\\(u\{?|x)([0-9a-fA-F]+)\}?$', '$2'))
            else if (matches($t, '^\\c')) then string-to-codepoints(upper-case(substring($t, 3))) - 64
            else ()"/>
        <xsl:sequence select="
            if (matches($t, '^\\[pP]\{')) then c:unicode-property($t)
            else if (exists($code)) then c:regex-char($code)
            else if ($t eq '\d') then (if ($in-class) then '0-9' else '[0-9]')
            else if ($t eq '\D') then (if ($in-class) then '\D' else '[^0-9]')
            else if ($t eq '\w') then (if ($in-class) then 'a-zA-Z0-9_' else '[a-zA-Z0-9_]')
            else if ($t eq '\W') then (if ($in-class) then '\W' else '[^a-zA-Z0-9_]')
            else if ($t eq '\s') then (if ($in-class) then '\s\p{Zs}&#xFEFF;&#x2028;&#x2029;&#xA0;' || $vtff
                                      else '[\s\p{Zs}&#xFEFF;&#x2028;&#x2029;&#xA0;' || $vtff || ']')
            else if ($t eq '\S') then (if ($in-class) then '\S' else '[^\s\p{Zs}&#xFEFF;&#x2028;&#x2029;&#xA0;' || $vtff || ']')
            else if ($t = ('\t', '\n', '\r', '\f', '\v', '\0'))
              then c:regex-char(map { '\t': 9, '\n': 10, '\r': 13, '\f': 12, '\v': 11, '\0': 0 }($t))
            else if (matches($t, '^\\[^nrtdDsSwWiIcCpP.\\?*+{}()|\[\]^$-]$')) then c:regex-char(string-to-codepoints(substring($t, 2)))
            else $t"/>
        <xsl:next-iteration>
          <xsl:with-param name="in-class" select="
              if (starts-with($t, '[') and not($in-class)) then true()
              else if ($t eq ']' and $in-class) then false() else $in-class"/>
        </xsl:next-iteration>
      </xsl:iterate>
    </xsl:variable>
    <xsl:sequence select="string-join($tokens)"/>
  </xsl:function>

  <xsl:function name="c:regex" as="xs:string">
    <xsl:param name="re" as="xs:string"/>
    <xsl:sequence select="c:lit(c:regex-raw($re))"/>
  </xsl:function>

  <!-- \p{Name}: Unicode property names of ECMA-262 to XSD categories. -->
  <xsl:function name="c:unicode-property" as="xs:string">
    <xsl:param name="t" as="xs:string"/>
    <xsl:variable name="name" select="replace($t, '^\\[pP]\{((General_Category|gc|Script|sc|Script_Extensions|scx)=)?(.*)\}$', '$3')"/>
    <xsl:variable name="names" select="map {
        'Letter': 'L', 'Cased_Letter': 'L', 'Uppercase_Letter': 'Lu', 'Lowercase_Letter': 'Ll',
        'Titlecase_Letter': 'Lt', 'Modifier_Letter': 'Lm', 'Other_Letter': 'Lo',
        'Mark': 'M', 'Combining_Mark': 'M', 'Nonspacing_Mark': 'Mn', 'Spacing_Mark': 'Mc', 'Enclosing_Mark': 'Me',
        'Number': 'N', 'Decimal_Number': 'Nd', 'digit': 'Nd', 'Letter_Number': 'Nl', 'Other_Number': 'No',
        'Punctuation': 'P', 'punct': 'P', 'Connector_Punctuation': 'Pc', 'Dash_Punctuation': 'Pd',
        'Open_Punctuation': 'Ps', 'Close_Punctuation': 'Pe', 'Initial_Punctuation': 'Pi',
        'Final_Punctuation': 'Pf', 'Other_Punctuation': 'Po',
        'Symbol': 'S', 'Math_Symbol': 'Sm', 'Currency_Symbol': 'Sc', 'Modifier_Symbol': 'Sk', 'Other_Symbol': 'So',
        'Separator': 'Z', 'Space_Separator': 'Zs', 'Line_Separator': 'Zl', 'Paragraph_Separator': 'Zp',
        'Other': 'C', 'Control': 'Cc', 'cntrl': 'Cc', 'Format': 'Cf', 'Private_Use': 'Co', 'Unassigned': 'Cn',
        'Greek': 'IsGreek', 'Cyrillic': 'IsCyrillic', 'Hebrew': 'IsHebrew', 'Arabic': 'IsArabic',
        'Armenian': 'IsArmenian', 'Thai': 'IsThai', 'Hiragana': 'IsHiragana', 'Katakana': 'IsKatakana' }"/>
    <xsl:sequence select="substring($t, 1, 2) || '{' || ($names($name), $name)[1] || '}'"/>
  </xsl:function>

  <!-- U+000B and U+000C, which ECMA-262 counts as white space; XML 1.0 has no
       character reference for them. -->
  <xsl:variable name="vtff" as="xs:string" select="codepoints-to-string((11, 12))"/>

  <!-- A literal character in an XPath regular expression. -->
  <xsl:function name="c:regex-char" as="xs:string">
    <xsl:param name="code" as="xs:integer"/>
    <!-- control characters stay (written with codepoints-to-string, see c:lit);
         U+0000 and surrogates become U+FFFD, as in c:unescape -->
    <xsl:variable name="ch" select="codepoints-to-string(
        if ($code eq 0 or ($code ge 55296 and $code le 57343) or $code = (65534, 65535)) then 65533 else $code)"/>
    <xsl:sequence select="if (matches($ch, '[\\.?*+{}()|\[\]^$-]')) then '\' || $ch else $ch"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- Helpers                                                            -->
  <!-- ================================================================== -->

  <xsl:function name="c:kw" as="element()*">
    <xsl:param name="s" as="element()?"/>
    <xsl:param name="names" as="xs:string*"/>
    <xsl:sequence select="for $name in $names return $s/self::fn:map/*[c:key(.) eq $name][1]"/>
  </xsl:function>

  <xsl:function name="c:unescape" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <!-- control characters stay (go-xslt holds them as in XML 1.1); U+0000,
         surrogates and U+FFFE/U+FFFF become U+FFFD -->
    <xsl:sequence select="codepoints-to-string(je:unescape-codepoints($s) ! (
        if (. eq 0 or (. ge 55296 and . le 57343) or . = (65534, 65535)) then 65533 else .))"/>
  </xsl:function>

  <xsl:function name="c:key" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:sequence select="if ($n/@escaped-key = 'true') then c:unescape($n/@key) else string($n/@key)"/>
  </xsl:function>

  <xsl:function name="c:str" as="xs:string">
    <xsl:param name="n" as="element()"/>
    <xsl:sequence select="if ($n/@escaped = 'true') then c:unescape($n) else string($n)"/>
  </xsl:function>

  <xsl:function name="c:dialect-number" as="xs:integer">
    <xsl:param name="name" as="xs:string"/>
    <xsl:sequence select="if (map:contains($dialects, $name)) then $dialects($name)
        else error(xs:QName('c:DIALECT'), 'Unknown dialect: ' || $name)"/>
  </xsl:function>

  <xsl:function name="c:dialect-name" as="xs:string">
    <xsl:param name="d" as="xs:integer"/>
    <xsl:sequence select="map:keys($dialects)[$dialects(.) eq $d]"/>
  </xsl:function>

  <xsl:function name="c:detect-dialect" as="xs:integer">
    <xsl:param name="s" as="element()"/>
    <xsl:param name="default" as="xs:integer"/>
    <xsl:variable name="uri" select="c:kw($s, '$schema')/self::fn:string/replace(c:str(.), '#$', '')"/>
    <xsl:sequence select="(if (exists($uri)) then $meta-schemas($uri) else (), $default)[1]"/>
  </xsl:function>

  <!-- The meta-schema named by $schema if it is not a standard one and can be read. -->
  <xsl:function name="c:custom-meta-schema" as="element()?">
    <xsl:param name="s" as="element()"/>
    <xsl:variable name="uri" select="c:kw($s, '$schema')/self::fn:string/c:str(.)"/>
    <xsl:if test="exists($uri) and not(map:contains($meta-schemas, replace($uri, '#$', '')))">
      <xsl:sequence select="c:load(c:strip-fragment($uri))"/>
    </xsl:if>
  </xsl:function>

  <xsl:function name="c:dir-uri" as="xs:anyURI">
    <xsl:param name="dir" as="xs:string"/>
    <xsl:sequence select="resolve-uri(replace($dir, '([^/])$', '$1/'), static-base-uri())"/>
  </xsl:function>

  <xsl:function name="c:hex" as="xs:integer">
    <xsl:param name="h" as="xs:string"/>
    <xsl:sequence select="fold-left(string-to-codepoints(upper-case($h)), 0, function($a, $c) {
        $a * 16 + (if ($c ge 65) then $c - 55 else $c - 48) })"/>
  </xsl:function>

  <!-- Percent-decoding (UTF-8). -->
  <xsl:function name="c:percent-decode" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="string-join(analyze-string($s, '(%[0-9A-Fa-f]{2})+')/* ! (
        if (self::fn:match) then c:utf8(tokenize(string(.), '%')[. ne ''] ! c:hex(.)) else string(.)))"/>
  </xsl:function>

  <xsl:function name="c:utf8" as="xs:string">
    <xsl:param name="b" as="xs:integer*"/>
    <xsl:sequence select="
        if (empty($b)) then ''
        else let $n := if ($b[1] lt 128) then 1 else if ($b[1] lt 224) then 2 else if ($b[1] lt 240) then 3 else 4,
                 $cp := if ($n eq 1) then $b[1]
                        else fold-left(subsequence($b, 2, $n - 1), $b[1] mod (128 idiv math:pow(2, $n) => xs:integer()),
                             function($a, $x) { $a * 64 + $x mod 64 })
             return codepoints-to-string($cp) || c:utf8(subsequence($b, $n + 1))"
        xmlns:math="http://www.w3.org/2005/xpath-functions/math"/>
  </xsl:function>

  <!-- URI references (RFC 3986, section 5.2). -->
  <xsl:function name="c:parse-uri" as="map(*)">
    <xsl:param name="u" as="xs:string"/>
    <xsl:variable name="g" select="analyze-string('&lt;' || $u, '^&lt;(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$')//fn:group"/>
    <xsl:sequence select="map {
        'scheme': $g[@nr = 2]/string(),
        'authority': if (string($g[@nr = 3]) ne '') then string($g[@nr = 4]) else (),
        'path': string($g[@nr = 5]),
        'query': if (string($g[@nr = 6]) ne '') then string($g[@nr = 7]) else (),
        'fragment': if (string($g[@nr = 8]) ne '') then string($g[@nr = 9]) else () }"/>
  </xsl:function>

  <xsl:function name="c:resolve" as="xs:string">
    <xsl:param name="ref" as="xs:string"/>
    <xsl:param name="base" as="xs:string"/>
    <xsl:variable name="r" select="c:parse-uri($ref)"/>
    <xsl:variable name="b" select="c:parse-uri($base)"/>
    <xsl:variable name="t" select="
        if (exists($r?scheme)) then map:put($r, 'path', c:remove-dots($r?path))
        else if (exists($r?authority)) then map:merge((map { 'scheme': $b?scheme, 'path': c:remove-dots($r?path) }, $r))
        else if ($r?path eq '') then map { 'scheme': $b?scheme, 'authority': $b?authority, 'path': $b?path,
            'query': ($r?query, $b?query)[1], 'fragment': $r?fragment }
        else map { 'scheme': $b?scheme, 'authority': $b?authority, 'query': $r?query, 'fragment': $r?fragment,
            'path': c:remove-dots(if (starts-with($r?path, '/')) then $r?path
                else if (exists($b?authority) and $b?path eq '') then '/' || $r?path
                else (if (contains($b?path, '/')) then replace($b?path, '^(.*/)[^/]*$', '$1') else '') || $r?path) }"/>
    <xsl:sequence select="string-join((
        if (exists($t?scheme)) then $t?scheme || ':' else (),
        if (exists($t?authority)) then '//' || $t?authority else (),
        $t?path,
        if (exists($t?query)) then '?' || $t?query else (),
        if (exists($t?fragment)) then '#' || $t?fragment else ()))"/>
  </xsl:function>

  <xsl:function name="c:remove-dots" as="xs:string">
    <xsl:param name="path" as="xs:string"/>
    <xsl:variable name="segments" select="tokenize($path, '/')"/>
    <xsl:variable name="out" select="fold-left($segments, (), function($acc, $seg) {
        if ($seg eq '.') then $acc
        else if ($seg eq '..') then (if (count($acc) gt 1 or ($acc[1] ne '')) then $acc[position() lt last()] else $acc)
        else ($acc, $seg) })"/>
    <xsl:sequence select="string-join($out, '/')
        || (if ($segments[last()] = ('.', '..') and count($segments) gt 1) then '/' else '')"/>
  </xsl:function>

  <xsl:function name="c:strip-fragment" as="xs:string">
    <xsl:param name="uri" as="xs:string"/>
    <xsl:sequence select="replace($uri, '#.*$', '')"/>
  </xsl:function>

</xsl:stylesheet>
