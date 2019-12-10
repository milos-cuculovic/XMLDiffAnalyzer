<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0">
  <!-- Handle dxx/dxa namespaces -->
  
  <xsl:variable name="xml-namespace" as="xs:string" select="'http://www.w3.org/XML/1998/namespace'"/>
  <xsl:variable name="dxx-namespace" as="xs:string" select="'http://www.deltaxml.com/ns/xml-namespaced-attribute'"/>
  <xsl:variable name="dxa-namespace" as="xs:string" select="'http://www.deltaxml.com/ns/non-namespaced-attribute'"/>
  
  
  <xsl:function name="deltaxml:get-attribute-ns" as="xs:string">
    <xsl:param name="element" as="node()"></xsl:param>
    <xsl:choose>
      <xsl:when test="namespace-uri($element)=$dxa-namespace">
        <xsl:text></xsl:text>
      </xsl:when>
      <xsl:when test="namespace-uri($element)=$dxx-namespace">
        <xsl:value-of select="$xml-namespace"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="namespace-uri($element)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="deltaxml:get-attribute-ns-reverse" as="xs:string">
    <xsl:param name="attr" as="attribute()"/>
    <xsl:choose>
      <xsl:when test="namespace-uri($attr)=''">
        <xsl:text>http://www.deltaxml.com/ns/non-namespaced-attribute</xsl:text>
      </xsl:when>
      <xsl:when test="namespace-uri($attr)='http://www.w3.org/XML/1998/namespace'">
        <xsl:text>http://www.deltaxml.com/ns/xml-namespaced-attribute</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="namespace-uri($attr)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="deltaxml:get-attribute-prefix" as="xs:string">
    <xsl:param name="attr" as="attribute()"/>
    <xsl:choose>
      <xsl:when test="namespace-uri($attr)=''">
        <xsl:text>dxa:</xsl:text>
      </xsl:when>
      <xsl:when test="namespace-uri($attr)='http://www.w3.org/XML/1998/namespace'">
        <xsl:text>dxx:</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="attrName" select="name($attr)" as="xs:string"/>
        <xsl:value-of select="if (contains($attrName,':')) then concat(substring-before($attrName, ':'), ':') else ''"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
</xsl:stylesheet>
