<?xml version="1.0" encoding="UTF-8"?>
<!--
  json-schema-test-suite-to-xml.xslt

  Splits the files of the JSON Schema Test Suite into single XML files, using
  the standard XPath 3.1 function fn:json-to-xml() (W3C XML representation of
  JSON, namespace http://www.w3.org/2005/xpath-functions).

  A test file is an array of test groups, each with a schema and several tests:

    [ { "description": "...", "schema": {...},
        "tests": [ { "description": "...", "data": ..., "valid": true }, ... ] },
      ... ]

  For every input file <path>/<name>.json and every group (numbered from 01)
  and test (numbered from 01) this writes

    <path>/<name>/<group>/schema.xml        the group's schema
    <path>/<name>/<group>/test-<test>.xml   the whole test object
                                            (description, data, valid, ...)

  The root element of schema.xml is the schema itself (map, or boolean for a
  boolean schema). A comment in front of it names the source file, the group
  and the group description.

  Conversion is lossless: numbers keep their lexical form, and strings that
  contain characters XML cannot represent are kept with JSON escapes and
  marked escaped="true" / escaped-key="true" (option escape = true()).

  Parameters:
    suite-dir   directory of the test suite, relative to this stylesheet or
                absolute (default: ../test-suites/json-schema/)
    files       whitespace-separated paths of the test files, relative to
                suite-dir

  Run with go-xslt (https://github.com/tim-riep/go-xslt) from the repository
  root; find does not follow the tests/latest symlink, so it is skipped:

    go-xslt transform -s xslt/json-schema-test-suite-to-xml.xslt \
      -it xsl:initial-template -allow-dir test-suites/json-schema \
      -d test-suites/json-schema-xml \
      -p "files=$(cd test-suites/json-schema && find tests -name '*.json' | sort)"
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:local="urn:json-xml-utilities:local"
    exclude-result-prefixes="xs fn local">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:param name="suite-dir" as="xs:string" select="'../test-suites/json-schema/'"/>
  <xsl:param name="files" as="xs:string" select="''"/>

  <xsl:variable name="options" as="map(*)"
      select="map { 'escape': true(), 'duplicates': 'reject' }"/>

  <xsl:variable name="suite-base" as="xs:anyURI"
      select="resolve-uri(replace($suite-dir, '([^/])$', '$1/'), static-base-uri())"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="paths" as="xs:string*" select="tokenize(normalize-space($files), ' ')"/>
    <xsl:if test="empty($paths)">
      <xsl:message terminate="yes" error-code="local:NOINPUT"
        >No input: set the parameter files.</xsl:message>
    </xsl:if>
    <xsl:for-each select="$paths">
      <xsl:call-template name="local:split-file">
        <xsl:with-param name="path" select="."/>
      </xsl:call-template>
    </xsl:for-each>
    <xsl:message select="'Converted ' || count($paths) || ' test files.'"/>
  </xsl:template>

  <xsl:template name="local:split-file">
    <xsl:param name="path" as="xs:string"/>
    <xsl:variable name="doc" as="document-node()"
        select="json-to-xml(unparsed-text(resolve-uri($path, $suite-base), 'UTF-8'), $options)"/>
    <xsl:variable name="dir" as="xs:string" select="replace($path, '\.json$', '')"/>

    <xsl:for-each select="$doc/fn:array/fn:map">
      <xsl:variable name="group" as="element(fn:map)" select="."/>
      <xsl:variable name="group-no" as="xs:string" select="format-integer(position(), '01')"/>
      <xsl:variable name="group-dir" as="xs:string" select="$dir || '/' || $group-no"/>

      <xsl:result-document href="{$group-dir}/schema.xml">
        <xsl:comment select="local:comment((
            'Source: ' || $path || ', test group ' || $group-no,
            'Description: ' || $group/fn:string[@key = 'description'],
            'JSON Schema Test Suite, MIT License, Copyright (c) 2012 Julian Berman'))"/>
        <xsl:apply-templates select="$group/*[@key = 'schema']" mode="local:root"/>
      </xsl:result-document>

      <xsl:for-each select="$group/fn:array[@key = 'tests']/fn:map">
        <xsl:variable name="test-no" as="xs:string" select="format-integer(position(), '01')"/>
        <xsl:result-document href="{$group-dir}/test-{$test-no}.xml">
          <xsl:comment select="local:comment((
              'Source: ' || $path || ', test group ' || $group-no || ', test ' || $test-no,
              'Schema: schema.xml',
              'JSON Schema Test Suite, MIT License, Copyright (c) 2012 Julian Berman'))"/>
          <xsl:apply-templates select="." mode="local:root"/>
        </xsl:result-document>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>

  <!-- Copy a value as a standalone document: drop the key that belonged to
       its parent map. -->
  <xsl:template match="*" mode="local:root">
    <xsl:copy>
      <xsl:copy-of select="@* except (@key, @escaped-key)"/>
      <xsl:copy-of select="node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Comment text: one line per item, made safe for an XML comment. -->
  <xsl:function name="local:comment" as="xs:string">
    <xsl:param name="lines" as="xs:string*"/>
    <xsl:sequence select="' ' || string-join(
        for $l in $lines return replace(replace(replace($l, '--', '- -'), '--', '- -'), '-$', '- '),
        '&#10;     ') || ' '"/>
  </xsl:function>

</xsl:stylesheet>
