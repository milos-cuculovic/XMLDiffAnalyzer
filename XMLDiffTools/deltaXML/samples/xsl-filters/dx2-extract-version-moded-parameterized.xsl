<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id$ -->
<!-- Copyright (c) 2008 DeltaXML Ltd. All rights reserved -->
<!--
    This stylesheet extracts a specified single document from a deltaV2 full-context delta file.
    The styesheet will process a changes-only delta but the result may not be useful.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
  xmlns:dxx="http://www.deltaxml.com/ns/xml-namespaced-attribute"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" 
  xmlns:saxon="http://saxon.sf.net/" version="3.1"
  exclude-result-prefixes="dxa dxx deltaxml xs">
  
  <xsl:import href="extract-format-version.xsl"/>
  
  <!-- In the dx2 format attributes are stored as elements and these
  elements have the same namespace as the corresponding attribute,
  with 2 exceptions, when the attribute wasn't in a namespace or
  was in the xml: namespace for example xml:space or xml:id.
  This function maps the dx2 format namespace into the original
  namespaces. -->
  <xsl:function name="deltaxml:convert-attribute-namespace" as="xs:string">
    <xsl:param name="namespace-uri" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$namespace-uri eq 'http://www.deltaxml.com/ns/non-namespaced-attribute'"><xsl:text/></xsl:when>
      <xsl:when test="$namespace-uri eq 'http://www.deltaxml.com/ns/xml-namespaced-attribute'">http://www.w3.org/XML/1998/namespace</xsl:when>
      <xsl:otherwise><xsl:sequence select="$namespace-uri"/></xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!-- Generalized for any version -->
  <xsl:template match="@* | node()" mode="extractVersion">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Generalized for any version -->
  <xsl:template match="*[*[@deltaxml:deltaTag | @deltaxml:deltaTagStart]]" mode="extractVersion" priority="10">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:variable name="result" as="element()">
      <xsl:apply-templates select="." mode="split-element-v21">
        <xsl:with-param name="version" select="$version-name"/>
      </xsl:apply-templates>
    </xsl:variable>
    <xsl:apply-templates select="$result" mode="#current"/>         
  </xsl:template>
  
  <!-- handle elements that are be part of an included element but do not themselves have a deltaxml:deltaV2 attribute, e.g. under an element with deltaxml:delta='A=B' -->
  <xsl:template match="*[not(@deltaxml:deltaV2)] [not(deltaxml:atts-or-text-group(.))]" mode="extractVersion">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:apply-templates select="* | text() | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@deltaxml:deltaV2 | @deltaxml:version | @deltaxml:content-type | @deltaxml:original-position" mode="extractVersion"/>
  
  <!-- Generalized for any version -->
  <!-- do nothing with this because child elements processed separately -->
  <xsl:template match="deltaxml:attributes" mode="extractVersion"></xsl:template>
  
  <xsl:template match="*[@deltaxml:deltaV2] [not(deltaxml:atts-or-text-group(.))]" mode="extractVersion">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:if test="deltaxml:extractable(@deltaxml:deltaV2, $version-name)">
      <xsl:copy copy-namespaces="no">
        <xsl:apply-templates select="@*" mode="#current"></xsl:apply-templates>
        <!-- write out any attributes that apply to this version only -->
        <xsl:apply-templates select="deltaxml:attributes/*" mode="#current"></xsl:apply-templates>
        <xsl:choose>
          <xsl:when test=".[@deltaxml:ordered='false'][*[@deltaxml:original-position]]">
            <xsl:call-template name="extract-orderless-items-in-order">
              <xsl:with-param name="container" select="."/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="* | text() | node()" mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  
  <!-- write out attributes that apply to this version -->
  <xsl:template match="deltaxml:attributes/*" mode="extractVersion">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:if test="not(empty(@deltaxml:deltaV2))">
      <xsl:if test="deltaxml:extractable(@deltaxml:deltaV2, $version-name)">
        <xsl:attribute name="{local-name(.)}" namespace="{deltaxml:convert-attribute-namespace(namespace-uri(.))}">
          <xsl:value-of select="deltaxml:attributeValue[deltaxml:extractable(@deltaxml:deltaV2, $version-name)]/text()"/>
        </xsl:attribute>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <!-- for a deltaxml:textGroup, we write out the appropriate text, if any -->
  <xsl:template match="deltaxml:textGroup" mode="extractVersion">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:if test="not(empty(@deltaxml:deltaV2))">
      <xsl:if test="deltaxml:extractable(@deltaxml:deltaV2, $version-name)">
        <xsl:value-of select="deltaxml:text[deltaxml:extractable(@deltaxml:deltaV2, $version-name)]/text()"/>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <!-- for a deltaxml:contentGroup, we output the appropriate content, if any -->
  <xsl:template match="deltaxml:contentGroup" mode="extractVersion">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:if test="not(empty(@deltaxml:deltaV2))">
      <xsl:if test="deltaxml:extractable(@deltaxml:deltaV2, $version-name)">
        <xsl:apply-templates select="deltaxml:content[deltaxml:extractable(@deltaxml:deltaV2, $version-name)]/node()" mode="#current"/>
      </xsl:if>
    </xsl:if>
  </xsl:template>
  
  <!-- For elements within an orderless container we use original-position to extract them in order -->
  <xsl:template name="extract-orderless-items-in-order">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:param name="container" as="element()" required="yes"/>
    <xsl:for-each select="$container/*[deltaxml:extractable(@deltaxml:deltaV2, $version-name)]">
      <xsl:sort select="deltaxml:extract-original-position-for-version($version-name, .)" data-type="number" order="ascending"/>
      <xsl:variable name="currentElement" select="." as="element()"/>
      <xsl:variable name="precedingNonElementNodes" select="
        if (exists($currentElement/preceding-sibling::*[deltaxml:extractable(@deltaxml:deltaV2, $version-name)])) 
          then $currentElement/preceding-sibling::node()[not(self::*)][. >> $currentElement/preceding-sibling::*[deltaxml:extractable(@deltaxml:deltaV2, $version-name)][1]]
          else $currentElement/preceding-sibling::node()[not(self::*)]" as="node()*"/>
      <xsl:apply-templates select="$precedingNonElementNodes" mode="extractVersion"/>
      <xsl:apply-templates select="." mode="extractVersion"/>
    </xsl:for-each>
    <xsl:variable name="trailingNonElements" select="if (exists($container/*[deltaxml:extractable(@deltaxml:deltaV2, $version-name)])) 
      then $container/*[deltaxml:extractable(@deltaxml:deltaV2, $version-name)][last()]/following-sibling::node()[not(self::*)]
      else $container/node()[not(self::*)]" as="node()*"/>
    <xsl:apply-templates select="$trailingNonElements" mode="extractVersion"/>
  </xsl:template>
  
  <!-- Generalized for any version -->
  <xsl:template name="extracts-subtree-with-delta">
    <xsl:param name="version-name" as="xs:string" required="yes" tunnel="yes"/>
    <xsl:param name="node" as="node()" required="yes"/>
    <xsl:choose>
      <xsl:when test="$node/self::deltaxml:attributes">
        <xsl:apply-templates mode="extractVersion">
          <xsl:with-param name="version" select="$version-name" tunnel="yes"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="$node/self::deltaxml:textGroup and deltaxml:extractable($node/@deltaxml:deltaV2, $version-name)">
        <deltaxml:textGroup deltaxml:deltaV2="{$version-name}">
          <deltaxml:text deltaxml:deltaV2="{$version-name}">
            <xsl:apply-templates mode="extractVersion">
              <xsl:with-param name="version" select="$version-name" tunnel="yes"/>
            </xsl:apply-templates>
          </deltaxml:text>
        </deltaxml:textGroup>
      </xsl:when>
      <xsl:when test="$node/self::deltaxml:contentGroup and deltaxml:extractable($node/@deltaxml:deltaV2, $version-name)">
        <deltaxml:contentGroup deltaxml:deltaV2="{$version-name}">
          <deltaxml:content deltaxml:deltaV2="{$version-name}">
            <xsl:apply-templates mode="extractVersion">
              <xsl:with-param name="version" select="$version-name" tunnel="yes"/>
            </xsl:apply-templates>
          </deltaxml:content>
        </deltaxml:contentGroup>
      </xsl:when>
      <xsl:when test=". instance of element()">
        <xsl:copy copy-namespaces="no">
          <xsl:attribute name="deltaxml:deltaV2" select="$version-name"/>
          <xsl:apply-templates select="$node/@* except $node/@deltaxml:deltaV2, $node/deltaxml:attributes/*, $node/node() except $node/deltaxml:attributes" mode="extractVersion">
            <xsl:with-param name="version" select="$version-name" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{name($node)}" namespace="{namespace-uri($node)}">
          <xsl:attribute name="deltaxml:deltaV2" select="$version-name"/>
          <xsl:apply-templates select="$node/@* except $node/@deltaxml:deltaV2, $node/deltaxml:attributes/*, $node/node() except $node/deltaxml:attributes" mode="extractVersion">
            <xsl:with-param name="version" select="$version-name" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="deltaxml:atts-or-text-group" as="xs:boolean">
    <xsl:param name="node" as="node()" />
    <xsl:sequence select="$node/ancestor-or-self::deltaxml:attributes or $node/ancestor-or-self::deltaxml:textGroup or $node/ancestor-or-self::deltaxml:contentGroup" />
  </xsl:function>
  
  <xsl:function name="deltaxml:extractable" as="xs:boolean">
    <xsl:param name="delta" as="xs:string"/>
    <xsl:param name="equal-group" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="empty($delta)">
        <xsl:sequence select="false()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="delta-equal-groups" select="tokenize($delta, '!=')" as="xs:string+"/>
        <!-- The equal group must either be a subset or equal to one of the delta components,
            for example delta         equal-group           result
                       A=B=C!=D=E       A=B=C                true
                       A=B=C!=D=E       A=B                  true
                       A=B=C!=D=E       D=E                  true
                       A=B=C!=D=E       A                    true
                       A=B=C!=D=E       C=D                  false -->
        <xsl:variable name="equal-group-members" as="xs:string+" select="tokenize($equal-group, '=')"/>
        <xsl:sequence select="some $group in $delta-equal-groups satisfies deltaxml:subset(tokenize($group, '='), $equal-group-members)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="deltaxml:value-except" as="xs:anyAtomicType*">
    <xsl:param name="arg1" as="xs:anyAtomicType*"/>
    <xsl:param name="arg2" as="xs:anyAtomicType*"/>
    <xsl:sequence select="distinct-values($arg1[not(.=$arg2)])"/>
  </xsl:function>
  
  <!-- true when all members of arg2 are in arg1 -->
  <xsl:function name="deltaxml:subset" as="xs:boolean">
    <xsl:param name="arg1" as="xs:anyAtomicType*"/>
    <xsl:param name="arg2" as="xs:anyAtomicType*"/>
    <xsl:sequence select="empty(deltaxml:value-except($arg2, $arg1))"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:warn" as="xs:boolean">
    <xsl:param name="arg1" as="xs:string"/>
    <xsl:message terminate="no" select="$arg1"/>
    <xsl:sequence select="true()"/>
  </xsl:function>
  
  
  <xsl:function name="deltaxml:extract-original-position-for-version" as="xs:numeric">
    <xsl:param name="version-name" as="xs:string" required="yes" />
    <xsl:param name="item" as="element()" required="yes" />
    <xsl:variable name="position-label" as="xs:string" select="tokenize($version-name, '=')[last()]"/>
    <xsl:choose>
      <xsl:when test="not($item/@deltaxml:original-position)">
        <xsl:message terminate="no" select="concat('No @deltaxml:original-position found for ', $version-name, ' at input document node ', path($item))"/>
        <xsl:value-of select="xs:double('INF')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="original-positions-string" as="xs:string" select="$item/@deltaxml:original-position"/>
        <xsl:sequence select="
          let $tuples := tokenize($original-positions-string, ','), (: Replace this by use of analyze-string :)
              $posInSequenceOfEmptyString := 
                  for $tuple in $tuples 
                          return 
                          if(normalize-space(tokenize($tuple, '=')[1]) = $position-label) then 
                              tokenize($tuple, '=')[2] 
                            else '' ,
               $pos := string-join($posInSequenceOfEmptyString)
          return 
              if(not(number($pos))) then (: XPath has no way of outputing a warning message so we have to call an xslt function which does. That functiuon won't be called unless it does something that needs to be evaluated. So Create an ignored vairable which we test and then alwasy return the same result:)
              let $kludge := deltaxml:warn(concat('No label in @deltaxml:original-position for ', $position-label, ' at input document node ', path($item))) return if($kludge) then xs:double('INF') else xs:double('INF')
              else
                xs:integer(number($pos))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
</xsl:stylesheet>
