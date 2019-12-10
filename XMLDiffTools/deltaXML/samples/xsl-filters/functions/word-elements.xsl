<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                exclude-result-prefixes="#all"
                version="2.0">
  
  <xsl:function name="deltaxml:isWord" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:value-of select="exists($node[self::deltaxml:word or self::deltaxml:space or self::deltaxml:punctuation])"/>
  </xsl:function>
  
</xsl:stylesheet>