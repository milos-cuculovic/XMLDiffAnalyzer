<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="2.0">
    
    <xsl:import href="dx2-extract-version-moded-parameterized.xsl"/>
    
    <!--
    This is new dx2-extract-version-moded.xsl. Old one was renamed to dx2-extract-version-moded-parameterized.xsl which
    now works for any number of versions. It extracts subtree based on the 'version-name' parameter.
    This xslt is used as bridge between dx2-extract-version-moded-parameterized.xsl and current extract version template 
    calls with mode A or B to extract subtree with version A or B.
    -->
    
    <xsl:template match="*" mode="A">
       <xsl:apply-templates select="." mode="extractVersion">
           <xsl:with-param name="version-name" select="'A'" tunnel="yes"/>
       </xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="*" mode="B">
        <xsl:apply-templates select="." mode="extractVersion">
            <xsl:with-param name="version-name" select="'B'" tunnel="yes"/>
        </xsl:apply-templates>
    </xsl:template>
    
    
    <xsl:template name="extract-A-with-delta">
        <xsl:call-template name="extracts-subtree-with-delta">
            <xsl:with-param name="version-name" select="'A'" tunnel="yes"/>
            <xsl:with-param name="node" select="."/>
        </xsl:call-template>
    </xsl:template>
    
    <xsl:template name="extract-B-with-delta">
        <xsl:call-template name="extracts-subtree-with-delta">
            <xsl:with-param name="version-name" select="'B'" tunnel="yes"/>
            <xsl:with-param name="node" select="."/>
        </xsl:call-template>
    </xsl:template>
    
</xsl:stylesheet>