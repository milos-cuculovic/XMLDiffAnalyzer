<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                exclude-result-prefixes="#all"
                version="2.0">
  
  <xsl:param name="important-attribute-names" as="xs:string" select="''"/>
  <xsl:variable name="attribute-names-sequence" as="xs:string*" select="tokenize($important-attribute-names,',')"/>
  
  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="#all">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:apply-templates select="@*" mode="mark"/>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- insert elements for important attributes -->
  <xsl:template match="@*" mode="mark">
    <xsl:if test="name(.) ne 'deltaxml:key' and local-name(.) = $attribute-names-sequence">
      <deltaxml:important name="{local-name(.)}">
        <deltaxml:content><xsl:value-of select="string-join((for $a in 1 to 10 return .),'+')"/></deltaxml:content>      
      </deltaxml:important>
      </xsl:if>    
  </xsl:template>
  
</xsl:stylesheet>
