<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0">
  
  <xsl:param name="punctuation" select="'. , ; : ! ? ( ) &apos;&apos; &quot; [ ]'"/>
  <xsl:param name="ignoreFormat" as="xs:string"/>
  
  <!-- Enable or disable extra whitespace on output -->
  <xsl:output method="xml" indent="no" />

  <!-- strip-space can be omitted if a single space in place of whitespace nodes is needed -->
  <xsl:strip-space elements="*"/>
  
  <xsl:template match="node() | @*">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Add deltaxml:ordered="false" to unordered elements -->
  <xsl:template match="xhtml:head">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ordered">false</xsl:attribute> 
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xhtml:style|xhtml:pre">
    <xsl:copy>
      <xsl:attribute name="deltaxml:word-by-word">false</xsl:attribute>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xhtml:style/comment()">
    <xsl:element name="deltaxml:comment">
      <xsl:value-of select="."/>
    </xsl:element>
  </xsl:template>
  
  <!--
    We have to delete the col and colgroup info because otherwise we could get
    incorrect XHTML out. This may lose some formatting info. Could do something more complex
    later, i.e. split into canonical form as <col> elements 
  -->
  <xsl:template match="xhtml:col | xhtml:colgroup"/>
  
  <!-- add a deltaxml:format attribute to all formatting elements -->
  <xsl:template match="xhtml:em | 
                       xhtml:strong | 
                       xhtml:dfn |
                       xhtml:code |
                       xhtml:samp |
                       xhtml:kbd |
                       xhtml:var |
                       xhtml:cite |
                       xhtml:abbr |
                       xhtml:acronym |
                       xhtml:q |
                       xhtml:sub |
                       xhtml:sup |
                       xhtml:tt |
                       xhtml:i |
                       xhtml:b |
                       xhtml:big |
                       xhtml:small |
                       xhtml:u |
                       xhtml:s |
                       xhtml:strike|
                       xhtml:span |
                       xhtml:basefont | 
                       xhtml:font">
    <xsl:copy>
      <xsl:if test="xs:boolean($ignoreFormat)">
        <xsl:attribute name="deltaxml:format">true</xsl:attribute>
      </xsl:if>
      <xsl:attribute name="deltaxml:punctuation" select="$punctuation"/>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  
  <!-- other elements to put punctuation on -->
  <xsl:template match="xhtml:h1 |
                       xhtml:h2 |
                       xhtml:h3 |
                       xhtml:h4 |
                       xhtml:h5 |
                       xhtml:h6 |
                       xhtml:p |
                       xhtml:div |
                       xhtml:blockquote">
    <xsl:copy>
      <xsl:attribute name="deltaxml:punctuation" select="$punctuation"/>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Do not apply threshold filter to TD/TR/title elements -->
  <xsl:template match="xhtml:td | xhtml:tr | xhtml:title">
    <xsl:copy>
      <xsl:attribute name="deltaxml:threshold" select="'false'"/>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- For every id attribute, use the value as a key. Also applies to @name in meta tag -->
  <xsl:template match="@id | xhtml:meta/@name">
    <!-- add a deltaxml:key="XX" attribute, with the same value as the id attribute,
         then copy the original attribute -->
    <xsl:attribute name="deltaxml:key">
      <xsl:value-of select="normalize-space(.)"/>
    </xsl:attribute>
    <xsl:attribute name="{name()}">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
</xsl:stylesheet>
