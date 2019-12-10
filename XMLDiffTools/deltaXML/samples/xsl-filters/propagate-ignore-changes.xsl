<?xml version="1.0" encoding="UTF-8"?>
<!-- $Id$ -->
<!-- Copyright (c) 2008 DeltaXML Ltd. All rights reserved -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="3.0">
  
  <!-- Rationalizes delta attributes which may have been modified
    by previous filters such as any filters to 'ignore attribute changes'.
    It looks at the the delta attribute of element and if set to modify
    checks to see that at least one child element/text-node/attribute
    is modified; if not the parent elements delta is changed to 'unchanged'.-->
  
  <xsl:include href="formatting/combine-format-fragments-iterate.xsl"/>
  
  <xsl:variable name="IsFCD" select="exists(/*[@deltaxml:content-type='full-context'])" as="xs:boolean"/>
  
  <xsl:template match="/">
    <xsl:variable name="stage1">
      <xsl:choose>
        <xsl:when test="/*/@deltaxml:version eq '2.1' and /*/@deltaxml:meta-formatting-elements eq 'true'">
          <xsl:variable name="hasTextOverlaps" select="descendant-or-self::*[
            not(exists(@deltaxml:deltaTag)) and
            (@deltaxml:*[starts-with(local-name(.), 'deltaTag')]) and 
            exists(@deltaxml:ignored)]"/>
          <xsl:choose>
            <xsl:when test="$hasTextOverlaps">
              <xsl:variable name="combined">
                <xsl:apply-templates mode="combine"/> 
              </xsl:variable>
              <xsl:apply-templates select="$combined" mode="strip-tags"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="." mode="strip-tags"/>
            <!-- YES we must strip tags we can still get here when we have  only @deltaxml:deltaTag, i.e. still have formatting but not split up. test will fail unless you do this -->
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:copy-of select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="/*/@deltaxml:version eq '2.1' and /*/@deltaxml:meta-formatting-elements eq 'true'">
        <xsl:apply-templates select="$stage1" mode="propagate"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="$stage1" mode="propagateNoDeltaTag"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:mode name="strip-tags" on-no-match="shallow-copy"/>
  
  <xsl:template match="*[@deltaxml:deltaV2='A=B']
                        [@deltaxml:deltaTag]
                        [not(@deltaxml:deltaTagStart | @deltaxml:deltaTagMiddle | @deltaxml:deltaTagEnd)]" mode="strip-tags">
    <xsl:copy>
      <xsl:apply-templates select="@* except (@deltaxml:deltaTag, @deltaxml:deltaTagStart, @deltaxml:deltaTagMiddle, @deltaxml:deltaTagEnd),
        node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="@deltaxml:ignored" mode="#all"/>
  
  <xsl:mode name="propagate" on-no-match="shallow-copy"/>
  <xsl:mode name="propagateNoDeltaTag" on-no-match="shallow-copy"/>
   
  <xsl:template match="*[@deltaxml:deltaV2=('A!=B', 'A=B')][not(self::deltaxml:attributes)][not(self::deltaxml:textGroup)]
    [not(descendant::*[@deltaxml:deltaV2=('A','B')][not(self::deltaxml:attributes)][not(self::deltaxml:textGroup)])]
    [not(descendant::deltaxml:text[@deltaxml:deltaV2=('A','B')])]
    [not(descendant::deltaxml:attributeValue[@deltaxml:deltaV2=('A','B')])]
    [not(descendant-or-self::*/@deltaxml:*[starts-with(local-name(.), 'deltaTag')])]"
    mode="propagate">
    <!-- copy subtree using mode unchanged because sub-tree of an unchanged element should not contain a delta attribute -->
    <xsl:copy>
      <xsl:attribute name="deltaxml:deltaV2">A=B</xsl:attribute>
      <xsl:if test="$IsFCD">
        <xsl:apply-templates select="@* except @deltaxml:deltaV2" mode="#current"/>
        <xsl:apply-templates select="node() " mode="unchanged"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@deltaxml:deltaV2=('A!=B', 'A=B')][not(self::deltaxml:attributes)][not(self::deltaxml:textGroup)]
    [not(descendant::*[@deltaxml:deltaV2=('A','B')][not(self::deltaxml:attributes)][not(self::deltaxml:textGroup)])]
    [not(descendant::deltaxml:text[@deltaxml:deltaV2=('A','B')])]
    [not(descendant::deltaxml:attributeValue[@deltaxml:deltaV2=('A','B')])]"
    mode="propagateNoDeltaTag">
    <!-- copy subtree using mode unchanged because sub-tree of an unchanged element should not contain a delta attribute -->
    <xsl:copy>
      <xsl:attribute name="deltaxml:deltaV2">A=B</xsl:attribute>
      <xsl:if test="$IsFCD">
        <xsl:apply-templates select="@* except @deltaxml:deltaV2" mode="#current"/>
        <xsl:apply-templates select="node() " mode="unchanged"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  
  <!-- This removes the instances where apply-ignore-changes has added a delta of A=B underneath an A or B subtree.
       This occurs for example when an ignore-changes='A' is specified on a descendant in an 'A' subtree.
       The priority for this template is higher as it should not be handled by the template above -->
  <xsl:template match="*[@deltaxml:deltaV2='A=B'][ancestor::*[@deltaxml:deltaV2=('A', 'B')]]" mode="propagate propagateNoDeltaTag" priority="2.0">
    <xsl:copy>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2, node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="deltaxml:attributes[count(*) eq 0]" mode="propagate propagateNoDeltaTag"/>
  
  <xsl:template match="deltaxml:textGroup[@deltaxml:deltaV2='A'][ancestor::*[@deltaxml:deltaV2='A']]" mode="propagate propagateNoDeltaTag">
    <xsl:copy-of select="deltaxml:text/text()"/>
  </xsl:template>
  
  <xsl:template match="deltaxml:textGroup[@deltaxml:deltaV2='B'][ancestor::*[@deltaxml:deltaV2='B']]" mode="propagate propagateNoDeltaTag">
    <xsl:copy-of select="deltaxml:text/text()"/>
  </xsl:template>
  
  <!-- unchanged mode uses an identity transform to copy a subtree, but removing delta attributes-->
  <xsl:mode name="unchanged" on-no-match="shallow-copy"/>
  
  <xsl:template match="@deltaxml:deltaV2" mode="unchanged"/>
  
  <xsl:template match="deltaxml:attributes" mode="unchanged"/>
  

</xsl:stylesheet>
