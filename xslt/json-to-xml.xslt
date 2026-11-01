<?xml version="1.0" encoding="UTF-8"?>
<!--
  json-to-xml.xslt

  Converts any JSON document into XML using the standard XPath 3.1 function
  fn:json-to-xml(). The result uses the W3C XML representation of JSON
  (namespace http://www.w3.org/2005/xpath-functions), e.g.

    {"a": [1, true, null]}

  becomes

    <map xmlns="http://www.w3.org/2005/xpath-functions">
      <array key="a">
        <number>1</number>
        <boolean>true</boolean>
        <null/>
      </array>
    </map>

  Input (one of the two is required):
    json-file   path or URI of the JSON file. A relative path is resolved
                against the directory of this stylesheet; pass an absolute
                path (or file: URI) to read from elsewhere.
    json        the JSON text itself (takes precedence over json-file)

  Options (passed to fn:json-to-xml, see XPath F&O 3.1, section 17.5.3):
    liberal     'yes' accepts JSON extensions such as comments (default: no)
    duplicates  'reject' | 'use-first' | 'retain' (default: use-first)
    escape      'yes' keeps JSON escape sequences in strings and keys and
                marks them with escaped="true" (default: no)

  Run with go-xslt (https://github.com/tim-riep/go-xslt), no source document
  needed. go-xslt only reads files next to the stylesheet unless more
  directories are allowed with -allow-dir:

    go-xslt transform -s xslt/json-to-xml.xslt -it xsl:initial-template \
      -allow-dir examples \
      -p json-file=../examples/json-to-xml/sample.json \
      -o examples/json-to-xml/sample.xml

    go-xslt transform -s xslt/json-to-xml.xslt -it xsl:initial-template \
      -p 'json={"a": [1, true, null]}'

  Alternatively pass an XML document whose text content is the JSON:

    go-xslt transform -s xslt/json-to-xml.xslt input.xml
-->
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    exclude-result-prefixes="xs fn">

  <xsl:output method="xml" encoding="UTF-8" indent="yes"/>

  <xsl:param name="json-file" as="xs:string?" select="()"/>
  <xsl:param name="json" as="xs:string?" select="()"/>
  <xsl:param name="liberal" as="xs:string" select="'no'"/>
  <xsl:param name="duplicates" as="xs:string" select="'use-first'"/>
  <xsl:param name="escape" as="xs:string" select="'no'"/>

  <xsl:variable name="options" as="map(*)" select="map {
      'liberal'    : $liberal = ('yes', 'true', '1'),
      'duplicates' : $duplicates,
      'escape'     : $escape = ('yes', 'true', '1')
    }"/>

  <!-- Entry point when started with -it (no source document). -->
  <xsl:template name="xsl:initial-template">
    <xsl:variable name="text" as="xs:string">
      <xsl:choose>
        <xsl:when test="exists($json)">
          <xsl:sequence select="$json"/>
        </xsl:when>
        <xsl:when test="exists($json-file)">
          <xsl:sequence select="unparsed-text($json-file, 'UTF-8')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message terminate="yes" error-code="Q{{urn:json-xml-utilities}}NOINPUT"
            >No input: set the parameter json-file or json.</xsl:message>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="json-to-xml($text, $options)"/>
  </xsl:template>

  <!-- Entry point when an XML source document is given: the JSON text is
       taken from the document's string value, e.g. <json>{"a":1}</json>. -->
  <xsl:template match="/">
    <xsl:sequence select="json-to-xml(string(.), $options)"/>
  </xsl:template>

</xsl:stylesheet>
