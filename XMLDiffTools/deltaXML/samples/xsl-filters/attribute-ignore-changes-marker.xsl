<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:local="http://www.deltaxml.com/ns/local-function"
                exclude-result-prefixes="xs"
                version="2.0">
  
  <xsl:param as="xs:string" name="default-mode" select="'BdA'" />
  <xsl:param as="xs:string" name="attribute-mode" select="'skip'"/>
  
  <xsl:variable as="xs:string" name="defaultMode" select="if ($default-mode='auto') then 'BdA' else $default-mode" />
  <xsl:variable as="xs:string" name="attributeOutputMode" select="local:mode($attribute-mode)"/>
  
  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
    
  <!-- Ensure deltaxml:attributes are not marked up - as these are not handled by the apply-ignore-changes.xsl filter -->
  <xsl:template match="deltaxml:attributes" priority="2" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@*, node()" mode="#current"/>          
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="deltaxml:attributes[not($attributeOutputMode = 'skip')]/*" mode="#all">
    <xsl:copy>
      <xsl:attribute name="deltaxml:ignore-changes" select="$attributeOutputMode"/>
      <xsl:apply-templates select="@*, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
    
  <xsl:function name="local:mode" as="xs:string">
    <xsl:param name="inMode" as="xs:string" />
    <xsl:choose>
      <xsl:when test="$inMode='auto'">
        <xsl:value-of select="$default-mode" />
      </xsl:when>
      <xsl:when test="$inMode='skip'">
        <xsl:value-of select="'skip'" />
      </xsl:when>
      <xsl:when test="$inMode= ('A', 'AdB')">
        <xsl:value-of select="'A'" />
      </xsl:when>
      <xsl:when test="$inMode=('B', 'BdA')">
        <xsl:value-of select="'B'" />
      </xsl:when>
      <xsl:when test="$inMode=('A,B', 'AB')">
        <xsl:value-of select="'A,B'" />
      </xsl:when>
      <xsl:when test="$inMode=('B,A', 'BA')">
        <xsl:value-of select="'B,A'" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="concat('Invalid mode ', $inMode,
          ' was expecting one of ''A'', ''B'', ''A,B'', ''B,A'', ''AB'', ''BA'', ''AdB'', ''BdA'', ''skip'', or ''auto''.')"
          terminate="yes" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
</xsl:stylesheet>