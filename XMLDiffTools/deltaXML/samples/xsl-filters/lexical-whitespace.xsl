<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="#all"
  xmlns:preserve="http://www.deltaxml.com/ns/preserve" 
  xmlns:er="http://www.deltaxml.com/ns/entity-references"
  xmlns:fn="urn:deltaxml.com.internal.function"
  version="2.0">
  
  <xsl:output indent="no"/>
  
  <!-- 
       Purpose: XSLT filter that updates the output of the LexicalPreservation filter for cases where
       XML Schema or DTD processing has taken place. The 'grammar' attribute added by LexicalPreservation
       identifies the case. This is positioned immediately after the LexicalPreservation filter in the
       processing pipeline for DocumentComparator and PipelinedComparatorS9.
    
       Detail: 
       1. For grammar=schema case: if ignorable whitespace is set to be preserved we need to wrap such nodes in
       preserve:ignorable elements - otherwise it must be stripped from the output
       2. For grammar=dtd case: any element that contains text nodes and does not have any immediate 'preserve:ignorable' child elements
       should be marked with mixed-content=true attribute
  -->
  
  <xsl:param name="preserve-ignorable-whitespace" as="xs:boolean" select="false()"/>
  <xsl:param name="preserve-content-model" as="xs:boolean" select="false()"/>
   
  <xsl:variable name="dtd-validated" as="xs:boolean" select="exists(/*[(@deltaxml:grammar, @preserve:grammar) = 'dtd'])"/>
  <xsl:variable name="schema-validated" as="xs:boolean" select="exists(/*[(@deltaxml:grammar, @preserve:grammar) = 'schema'])"/>
  <xsl:variable name="mark-ignorable-whitespace" as="xs:boolean" select="$schema-validated and $preserve-ignorable-whitespace"/>
  <xsl:variable name="strip-ignorable-whitespace" as="xs:boolean" select="$schema-validated and not($preserve-ignorable-whitespace)"/>
  
  <!-- namespace for added mixed-content attribute is conditional on $preserve-content-model -->
  <xsl:variable name="mixed-content-attribute" as="attribute()">
    <xsl:choose>
      <xsl:when test="$preserve-content-model">
        <xsl:attribute name="preserve:mixed-content" select="'true'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="deltaxml:mixed-content" select="'true'"/>       
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  
  <xsl:template match="/" mode="#default">
    <xsl:choose>
      <xsl:when test="$dtd-validated">
        <xsl:variable name="first-pass" as="node()*">
          <xsl:apply-templates mode="#current"/>
        </xsl:variable>
        <!-- rationalise preserve:ignorable elements -->
        <xsl:apply-templates select="$first-pass[1]" mode="ws-sibling-recursion"/>        
      </xsl:when>
      <xsl:when test="$schema-validated">
        <xsl:apply-templates mode="#current"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
    
  <xsl:template match="text()" mode="#default">
    <xsl:copy/>
  </xsl:template>
     
  <xsl:template match="text()" mode="mark-ws-as-ignorable">
    <xsl:choose>
      <!-- only wrap whitespace-nodes -->
      <xsl:when test="fn:is-whitespace-only(.)">
        <preserve:ignorable xml:space="preserve"><xsl:value-of select="."/></preserve:ignorable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="text()" mode="strip-ignorable">
    <!-- only copy non-whitespace nodes -->
    <xsl:if test="not(fn:is-whitespace-only(.))">
      <xsl:value-of select="."/>
    </xsl:if>
  </xsl:template>
        
  <!-- test un-matched elements -->
  <xsl:template match="*" mode="#default mark-ws-as-ignorable strip-ignorable">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      
      <!-- for dtd grammar, add mixed-content attribute to elements with text and no ignorable whitespace -->
      <xsl:if test="$dtd-validated and exists(text()) and empty(preserve:ignorable)">
        <xsl:sequence select="$mixed-content-attribute"/>
      </xsl:if>
      
      <xsl:variable name="mixed-content-marked" as="xs:boolean" select="exists((@preserve:mixed-content, @deltaxml:mixed-content))"/>

      <xsl:choose>
        <!-- for schema grammar, if preserved, mark ignorable whitespace (i.e. outside mixed-content) -->
        <xsl:when test="$mark-ignorable-whitespace and not($mixed-content-marked)">
          <xsl:apply-templates mode="mark-ws-as-ignorable"/>
        </xsl:when>
        <!-- for schema grammar, if not preserved, strip ignorable whitespace (i.e. outside mixed-content) -->
        <xsl:when test="$strip-ignorable-whitespace and not($mixed-content-marked)">
          <xsl:apply-templates mode="strip-ignorable"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="#default"/>         
        </xsl:otherwise>
      </xsl:choose>
      
    </xsl:copy>
  </xsl:template>
  
  <!-- sax parser can generate 2 consecutive ignorable whitespace events, rationalise these into 1 -->
  <xsl:template match="node()" mode="ws-sibling-recursion">
    <xsl:param name="preceding-was-ignorable" as="xs:boolean" select="false()"/>
    <xsl:variable name="is-ignorable" as="xs:boolean" select="(exists(self::preserve:ignorable), false())[1]"/>
    <xsl:variable name="following-ignorable" as="element()?" select="following-sibling::node()[1][self::preserve:ignorable]"/>
    <xsl:choose>
      <xsl:when test="$preceding-was-ignorable and $is-ignorable"/>
      <xsl:when test="$is-ignorable and exists($following-ignorable)">
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:value-of select="string-join((string(text()), string($following-ignorable/text())), '')"/>
        </xsl:copy>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:copy-of select="@*"/>
          <xsl:apply-templates select="node()[1]" mode="ws-sibling-recursion"/> 
        </xsl:copy>         
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="following-sibling::node()[1]" mode="ws-sibling-recursion">
      <xsl:with-param name="preceding-was-ignorable" select="$is-ignorable"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:function name="fn:is-whitespace-only" as="xs:boolean">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="matches($text, '^\s+$')"/>
  </xsl:function>
  
</xsl:stylesheet>