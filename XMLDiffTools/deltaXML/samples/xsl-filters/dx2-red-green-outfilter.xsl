<?xml version="1.0" encoding="UTF-8"?>
<!--
  This filter sorts mixed up consecutive added or deleted elements (at the same level) and outputs 
  all items of the same version (i.e. 'A' or 'B') together. Whether the 'A'or 'B' version is output 
  first is dependent on the 'ordering-mode' parameter as follows:
  
  'A-first' - the items with a delta of 'A' are ordered before those with a delta of 'B' 
              (default behaviour)
  'B-first' - the items with a delta of 'B' are ordered before those with a delta of 'A'
  
  'dynamic' - the items with the same delta as the first item, followed by those with the
              opposite delta (original behaivour)
  
  e.g.
  
  <root>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="delete"/>
  </root>
  
  has a default 'A-first' output of: 

  <root>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="delete"/>
  </root>
  
  has a 'B-first' (and legacy 'as-delta-occur') output of:
  
  <root>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="add"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="delete"/>
    <word deltaxml:delta="unchanged"/>
    <word deltaxml:delta="delete"/>
  </root>
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:ignore="http://www.deltaxml.com/ns/ignoreForAlignment"
                version="3.0">

  <xsl:param name="ordering-mode" as="xs:string" select="'A-first'" />
 
  <xsl:variable name="B-first" as="xs:boolean" select="$ordering-mode = 'B-first'" />
  <xsl:variable name="dynamic" as="xs:boolean" select="$ordering-mode = 'dynamic'" />

  <xsl:mode on-no-match="shallow-copy"/>

  <xsl:template match="*[@deltaxml:deltaV2='A!=B'][not(@deltaxml:red-green='false')]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:copy-of select="deltaxml:attributes"/>
      <!-- THIS GROUPING ONLY WORKS IF THE INPUT IS NOT INDENTED -->
      <xsl:for-each-group select="node()[not(self::deltaxml:attributes)]" group-adjacent="if(@deltaxml:deltaV2 and (@deltaxml:deltaV2='B' or @deltaxml:deltaV2='A')) then 1 else 0">
        <xsl:choose>
          <xsl:when test="current-grouping-key()=1">
            <xsl:variable name="first-item" as="node()" select="current-group()[1]"/>
            <xsl:choose>
              <xsl:when test="exists($first-item/@ignore:format) and matches($first-item/@ignore:format, '[^s]e')">
                <!-- 
                  Regex matches ignore:format="1e" but does NOT match ignore:format="1se"
                  Where there is a match, do NOT perform red/green processing. 
                  This prevents text changes following an element close tag from being regrouped so
                  they appear before it.
                -->
                <xsl:for-each select="current-group()">
                  <xsl:choose>
                    <xsl:when test="self::element()">
                      <xsl:apply-templates select="."/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:copy-of select="."/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:for-each>                
              </xsl:when>
              <xsl:when test="$B-first or ($dynamic and $first-item/@deltaxml:deltaV2='B')">
                <xsl:for-each select="current-group()[@deltaxml:deltaV2='B']">
                  <xsl:apply-templates select="."/>
                </xsl:for-each>
                <xsl:for-each select="current-group()[@deltaxml:deltaV2='A']">
                  <xsl:apply-templates select="."/>
                </xsl:for-each>
              </xsl:when>
              <xsl:otherwise>
                <xsl:for-each select="current-group()[@deltaxml:deltaV2='A']">
                  <xsl:apply-templates select="."/>
                </xsl:for-each>
                <xsl:for-each select="current-group()[@deltaxml:deltaV2='B']">
                  <xsl:apply-templates select="."/>
                </xsl:for-each>
              </xsl:otherwise>
            </xsl:choose>           
          </xsl:when>
          <xsl:otherwise>
            <xsl:for-each select="current-group()">
              <xsl:choose>
                <xsl:when test="self::element()">
                  <xsl:apply-templates select="."/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:copy-of select="."/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:for-each>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>