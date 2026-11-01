<?xml version="1.0" encoding="UTF-8"?>
<!--
  json-elements.xslt

  Functions that convert JSON to and from the "JSON elements" XML format, in
  which object members are elements named after their keys. Unlike the W3C
  representation of fn:json-to-xml(), where every member is a map, string,
  number, ... element with the key in an attribute, this format lets an XSD
  describe objects with ordinary element declarations.

  The format
  ==========
    {"name": "Erika", "age": 42, "tags": ["a", 1], "address": {"city": "Köln"},
     "ok": true, "none": null}

  is

    <json type="object">
      <name>Erika</name>
      <age type="number">42</age>
      <tags type="array">
        <item>a</item>
        <item type="number">1</item>
      </tags>
      <address type="object">
        <city>Köln</city>
      </address>
      <ok type="boolean">true</ok>
      <none type="null"/>
    </json>

  - The document element is json, array members are item elements, and object
    members are elements named after their keys. Members keep their order.
  - type is object, array, number, boolean or null; without it the value is
    a string.
  - Numbers keep their lexical form (1.0 stays 1.0), booleans are true or
    false, null is empty.
  - Keys that are not XML names are encoded as in SQL/XML (ISO/IEC 9075-14),
    where names follow the conservative rules of XML 1.0 4th edition (letters
    and _ first, then also digits, marks, ., - and middle dot):
    a character that may not appear at its position becomes _xHHHH_, every
    character above U+FFFF becomes _xHHHHHHHH_ (older XML 1.0 parsers do not
    accept them in names), an underscore followed by x becomes _x005F_,
    and the empty key is _x_. "first name" is first_x0020_name, "1st" is
    _x0031_st, "a:b" is a_x003A_b. Element names have no namespace.
  - A string with characters XML cannot hold (such as U+0000) keeps its JSON
    escape sequences and gets escaped="true", as in fn:json-to-xml().

  Functions (namespace urn:json-xml-utilities:json-elements)
  =========
    je:parse($json as xs:string?) as document-node()?
    je:parse($json as xs:string?, $options as map(*)) as document-node()?
        JSON text to the format. $options are those of fn:json-to-xml
        (liberal, duplicates); escape is always used.
    je:serialize($doc as node()) as xs:string
        The format (a document or its json element) to JSON text.
    je:from-xpath-json($node as node()) as document-node()
    je:to-xpath-json($node as node()) as document-node()
        Conversion from and to the W3C representation of fn:json-to-xml().
    je:name($key as xs:string) as xs:string
    je:key($name as xs:string) as xs:string
        Key to element name and back.

  Use as a library with xsl:import or xsl:include, or run it directly with
  go-xslt (https://github.com/tim-riep/go-xslt):

    JSON to XML (parameter json-file or json, no source document):
      go-xslt transform -s xslt/json-elements.xslt -it xsl:initial-template \
        -allow-dir examples -p json-file=../examples/json-elements/sample.json

    XML to JSON, or W3C representation to this format (source document):
      go-xslt transform -s xslt/json-elements.xslt examples/json-elements/sample.xml
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:je="urn:json-xml-utilities:json-elements"
    exclude-result-prefixes="xs fn je">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:param name="json-file" as="xs:string?" select="()"/>
  <xsl:param name="json" as="xs:string?" select="()"/>

  <!-- ================================================================== -->
  <!-- Entry points                                                       -->
  <!-- ================================================================== -->

  <!-- JSON text (parameter json or json-file) to the format. -->
  <xsl:template name="xsl:initial-template">
    <xsl:choose>
      <xsl:when test="exists($json)">
        <xsl:sequence select="je:parse($json)"/>
      </xsl:when>
      <xsl:when test="exists($json-file)">
        <xsl:sequence select="je:parse(unparsed-text($json-file, 'UTF-8'))"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes" error-code="je:NOINPUT"
          >No input: set the parameter json-file or json.</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A source document in this format becomes JSON text; one in the W3C
       representation becomes this format. -->
  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="json">
        <xsl:result-document method="text">
          <xsl:value-of select="je:serialize(.)"/>
        </xsl:result-document>
      </xsl:when>
      <xsl:when test="fn:*">
        <xsl:sequence select="je:from-xpath-json(.)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes" error-code="je:INPUT"
          >The source is neither a json element nor the XML representation of fn:json-to-xml().</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- Public functions                                                   -->
  <!-- ================================================================== -->

  <xsl:function name="je:parse" as="document-node()?">
    <xsl:param name="json" as="xs:string?"/>
    <xsl:sequence select="je:parse($json, map {})"/>
  </xsl:function>

  <xsl:function name="je:parse" as="document-node()?">
    <xsl:param name="json" as="xs:string?"/>
    <xsl:param name="options" as="map(*)"/>
    <xsl:if test="exists($json)">
      <xsl:sequence select="je:from-xpath-json(json-to-xml($json, map:merge(($options, map { 'escape': true() }),
          map { 'duplicates': 'use-last' })))" xmlns:map="http://www.w3.org/2005/xpath-functions/map"/>
    </xsl:if>
  </xsl:function>

  <!-- Unlike fn:xml-to-json, numbers keep their lexical form. -->
  <xsl:function name="je:serialize" as="xs:string">
    <xsl:param name="doc" as="node()"/>
    <xsl:variable name="parts" as="xs:string*">
      <xsl:apply-templates select="$doc/descendant-or-self::json[1]" mode="je:serialize"/>
    </xsl:variable>
    <xsl:sequence select="string-join($parts)"/>
  </xsl:function>

  <xsl:function name="je:from-xpath-json" as="document-node()">
    <xsl:param name="node" as="node()"/>
    <xsl:document>
      <xsl:apply-templates select="$node/descendant-or-self::fn:*[1]" mode="je:from-xpath-json">
        <xsl:with-param name="name" select="'json'"/>
      </xsl:apply-templates>
    </xsl:document>
  </xsl:function>

  <xsl:function name="je:to-xpath-json" as="document-node()">
    <xsl:param name="node" as="node()"/>
    <xsl:document>
      <xsl:apply-templates select="$node/descendant-or-self::json[1]" mode="je:to-xpath-json"/>
    </xsl:document>
  </xsl:function>

  <!-- Key to element name (SQL/XML escaping). -->
  <xsl:function name="je:name" as="xs:string">
    <xsl:param name="key" as="xs:string"/>
    <xsl:variable name="cps" select="string-to-codepoints($key)"/>
    <xsl:sequence select="if ($key eq '') then '_x_' else string-join(
        for $i in 1 to count($cps) return
        let $c := codepoints-to-string($cps[$i])
        return
          if ($c eq '_' and $cps[$i + 1] eq 120) then '_x005F_'
          else if ($cps[$i] le 65535
                   and matches($c, if ($i eq 1) then '^[\p{Ll}\p{Lu}\p{Lo}\p{Lt}\p{Nl}_]$'
                                   else '^[\p{Ll}\p{Lu}\p{Lo}\p{Lt}\p{Nl}\p{Lm}\p{Mn}\p{Mc}\p{Me}\p{Nd}_.\-&#xB7;]$')
                   and (if ($i eq 1) then $c else 'a' || $c) castable as xs:NCName) then $c
          else '_x' || je:hex($cps[$i], if ($cps[$i] gt 65535) then 8 else 4) || '_')"/>
  </xsl:function>

  <!-- Element name to key. -->
  <xsl:function name="je:key" as="xs:string">
    <xsl:param name="name" as="xs:string"/>
    <xsl:sequence select="if ($name eq '_x_') then '' else string-join(
        analyze-string($name, '_x([0-9A-Fa-f]{8}|[0-9A-Fa-f]{4})_')/* !
          (if (self::fn:match) then codepoints-to-string(je:from-hex(string(fn:group))) else string(.)))"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- W3C representation to this format                                  -->
  <!-- ================================================================== -->

  <xsl:template match="fn:*" mode="je:from-xpath-json">
    <xsl:param name="name" as="xs:string"/>
    <xsl:element name="{$name}">
      <xsl:if test="not(self::fn:string)">
        <xsl:attribute name="type" select="if (self::fn:map) then 'object' else local-name()"/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="self::fn:map">
          <xsl:for-each select="*">
            <xsl:apply-templates select="." mode="je:from-xpath-json">
              <xsl:with-param name="name" select="je:name(je:w3c-key(.))"/>
            </xsl:apply-templates>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="self::fn:array">
          <xsl:apply-templates select="*" mode="je:from-xpath-json">
            <xsl:with-param name="name" select="'item'"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="self::fn:string and @escaped = 'true'">
          <xsl:variable name="text" select="je:unescape(string(.))"/>
          <xsl:choose>
            <xsl:when test="exists($text)">
              <xsl:value-of select="$text"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:attribute name="escaped" select="'true'"/>
              <xsl:value-of select="."/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="self::fn:string">
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:when test="self::fn:null"/>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- The key of a member of the W3C representation, unescaped. Keys with
       characters XML cannot hold cannot occur unescaped; je:name encodes them. -->
  <xsl:function name="je:w3c-key" as="xs:string">
    <xsl:param name="member" as="element()"/>
    <xsl:sequence select="if ($member/@escaped-key = 'true')
        then codepoints-to-string(je:unescape-codepoints(string($member/@key)))
        else string($member/@key)"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- This format to the W3C representation                              -->
  <!-- ================================================================== -->

  <xsl:template match="*" mode="je:to-xpath-json">
    <xsl:param name="key" as="xs:string?" select="()"/>
    <xsl:variable name="type" select="(@type, 'string')[1]"/>
    <xsl:if test="not($type = ('object', 'array', 'string', 'number', 'boolean', 'null'))">
      <xsl:message terminate="yes" error-code="je:TYPE"
          select="'Unknown type ' || $type || ' on ' || path(.)"/>
    </xsl:if>
    <xsl:element name="{if ($type eq 'object') then 'map' else $type}"
        namespace="http://www.w3.org/2005/xpath-functions">
      <xsl:if test="exists($key)">
        <xsl:choose>
          <xsl:when test="je:xml-safe($key)">
            <xsl:attribute name="key" select="$key"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="escaped-key" select="'true'"/>
            <xsl:attribute name="key" select="je:escape($key)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$type eq 'object'">
          <xsl:for-each select="*">
            <xsl:apply-templates select="." mode="je:to-xpath-json">
              <xsl:with-param name="key" select="je:key(local-name())"/>
            </xsl:apply-templates>
          </xsl:for-each>
        </xsl:when>
        <xsl:when test="$type eq 'array'">
          <xsl:apply-templates select="*" mode="je:to-xpath-json"/>
        </xsl:when>
        <xsl:when test="$type eq 'string'">
          <xsl:if test="@escaped = 'true'">
            <xsl:attribute name="escaped" select="'true'"/>
          </xsl:if>
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:when test="$type eq 'null'"/>
        <xsl:otherwise>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>

  <!-- ================================================================== -->
  <!-- This format to JSON text                                           -->
  <!-- ================================================================== -->

  <xsl:template match="*" mode="je:serialize" as="xs:string*">
    <xsl:variable name="type" select="(@type, 'string')[1]"/>
    <xsl:choose>
      <xsl:when test="$type eq 'object'">
        <xsl:sequence select="'{'"/>
        <xsl:for-each select="*">
          <xsl:sequence select="(if (position() gt 1) then ',' else ()), je:json-string(je:key(local-name())), ':'"/>
          <xsl:apply-templates select="." mode="je:serialize"/>
        </xsl:for-each>
        <xsl:sequence select="'}'"/>
      </xsl:when>
      <xsl:when test="$type eq 'array'">
        <xsl:sequence select="'['"/>
        <xsl:for-each select="*">
          <xsl:sequence select="if (position() gt 1) then ',' else ()"/>
          <xsl:apply-templates select="." mode="je:serialize"/>
        </xsl:for-each>
        <xsl:sequence select="']'"/>
      </xsl:when>
      <xsl:when test="$type eq 'string' and @escaped = 'true'">
        <xsl:sequence select="'&quot;' || replace(string(.), '&quot;', '\\&quot;') || '&quot;'"/>
      </xsl:when>
      <xsl:when test="$type eq 'string'">
        <xsl:sequence select="je:json-string(string(.))"/>
      </xsl:when>
      <xsl:when test="$type eq 'null'">
        <xsl:sequence select="'null'"/>
      </xsl:when>
      <xsl:when test="$type eq 'boolean' and normalize-space(.) = ('true', 'false')">
        <xsl:sequence select="normalize-space(.)"/>
      </xsl:when>
      <xsl:when test="$type eq 'number' and matches(normalize-space(.), '^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+\-]?[0-9]+)?$')">
        <xsl:sequence select="normalize-space(.)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes" error-code="je:VALUE"
            select="'Invalid ' || $type || ' value ''' || string(.) || ''' at ' || path(.)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- A JSON string literal. -->
  <xsl:function name="je:json-string" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="'&quot;' || string-join(string-to-codepoints($s) ! (
        if (. eq 34) then '\&quot;' else if (. eq 92) then '\\'
        else if (. eq 10) then '\n' else if (. eq 13) then '\r' else if (. eq 9) then '\t'
        else if (. lt 32 or not(je:xml-char(.))) then '\u' || je:hex(., 4)
        else codepoints-to-string(.))) || '&quot;'"/>
  </xsl:function>

  <!-- ================================================================== -->
  <!-- Helpers                                                            -->
  <!-- ================================================================== -->

  <!-- Code points of a string with JSON escape sequences. -->
  <xsl:function name="je:unescape-codepoints" as="xs:integer*">
    <xsl:param name="s" as="xs:string"/>
    <xsl:for-each select="analyze-string($s, '\\u[dD][89abAB][0-9a-fA-F]{2}\\u[dD][c-fC-F][0-9a-fA-F]{2}|\\u[0-9a-fA-F]{4}|\\.')/*">
      <xsl:variable name="t" select="string(.)"/>
      <xsl:choose>
        <xsl:when test="self::fn:non-match">
          <xsl:sequence select="string-to-codepoints($t)"/>
        </xsl:when>
        <xsl:when test="string-length($t) eq 12">
          <xsl:sequence select="65536 + (je:from-hex(substring($t, 3, 4)) - 55296) * 1024
              + je:from-hex(substring($t, 9, 4)) - 56320"/>
        </xsl:when>
        <xsl:when test="string-length($t) eq 6">
          <xsl:sequence select="je:from-hex(substring($t, 3))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:sequence select="map { 'b': 8, 'f': 12, 'n': 10, 'r': 13, 't': 9 }(substring($t, 2)),
              string-to-codepoints(substring($t, 2))[not(substring($t, 2) = ('b', 'f', 'n', 'r', 't'))]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>

  <!-- The unescaped string, or () if it has characters XML cannot hold. -->
  <xsl:function name="je:unescape" as="xs:string?">
    <xsl:param name="s" as="xs:string"/>
    <xsl:variable name="cps" select="je:unescape-codepoints($s)"/>
    <xsl:if test="every $c in $cps satisfies je:xml-char($c)">
      <xsl:sequence select="codepoints-to-string($cps)"/>
    </xsl:if>
  </xsl:function>

  <!-- JSON escapes for a key that has characters XML cannot hold. -->
  <xsl:function name="je:escape" as="xs:string">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="string-join(string-to-codepoints($s) ! (
        if (. eq 92) then '\\'
        else if (je:xml-char(.)) then codepoints-to-string(.)
        else '\u' || je:hex(., 4)))"/>
  </xsl:function>

  <xsl:function name="je:xml-safe" as="xs:boolean">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="every $c in string-to-codepoints($s) satisfies je:xml-char($c)"/>
  </xsl:function>

  <!-- A character XML 1.0 can hold. -->
  <xsl:function name="je:xml-char" as="xs:boolean">
    <xsl:param name="c" as="xs:integer"/>
    <xsl:sequence select="$c = (9, 10, 13) or ($c ge 32 and $c le 55295)
        or ($c ge 57344 and $c le 65533) or ($c ge 65536 and $c le 1114111)"/>
  </xsl:function>

  <xsl:function name="je:hex" as="xs:string">
    <xsl:param name="n" as="xs:integer"/>
    <xsl:param name="digits" as="xs:integer"/>
    <xsl:sequence select="string-join(reverse(for $i in 0 to $digits - 1
        return substring('0123456789ABCDEF', ($n idiv xs:integer(math:pow(16, $i))) mod 16 + 1, 1)))"
        xmlns:math="http://www.w3.org/2005/xpath-functions/math"/>
  </xsl:function>

  <xsl:function name="je:from-hex" as="xs:integer">
    <xsl:param name="h" as="xs:string"/>
    <xsl:sequence select="fold-left(string-to-codepoints(upper-case($h)), 0, function($a, $c) {
        $a * 16 + (if ($c ge 65) then $c - 55 else $c - 48) })"/>
  </xsl:function>

</xsl:stylesheet>
