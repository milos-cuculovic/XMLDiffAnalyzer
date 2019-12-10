<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1" 
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0">

  <xsl:function name="deltaxml:nearest-delta-is" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="deltas" as="xs:string+"/>
    
    <xsl:variable name="nearest-delta" select="$node/ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2" as="xs:string?"/>
    
    <xsl:sequence select="$nearest-delta = $deltas"/>    
  </xsl:function>
  
  <xsl:function name="deltaxml:nearest-delta-contains" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="version" as="xs:string"/>
    
    <xsl:variable name="nearest-delta" select="$node/ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2" as="xs:string?"/>
    
    <xsl:sequence select="contains($nearest-delta, $version)"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:nearest-delta" as="xs:string">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="($node/ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2, '')[1]"/>
  </xsl:function> 
</xsl:stylesheet>