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
  
  <!-- Purpose: For cases where schema/dtd information is not available,
       i.e. there is no 'grammar' attribute on the root element.
       If indentation found, analyse whitespace within each element to determine
       whether it should be annotated with 'deltaxml:mixed-content' or
       'deltaxml:space=preserve' attributes prior to normalisation.
       This is an '80%' solution - some problem areas:
       1. If indentation does not start at the first-element child
       2. When mixed content only has whitespace-only text nodes
         e.g. <p><b>bold</b> <a href="test.html">test</a></p>
       3. Lexical preservation elements for representing entity references (er:*)
          can cause issues when analysing whitespace because they break up text nodes     
  -->
  
  <!-- if the document element is immediately followed by a text node this is assumed
       to be for formatting/indenting the xml - extra complexity is required to 
       handle lexical preservation elements that might occur first
  -->
  
  <xsl:param name="preserve-ignorable-whitespace" as="xs:boolean" select="false()"/>
  <xsl:param name="preserve-content-model" as="xs:boolean" select="false()"/>
  <xsl:param name="collate-element-type-info" as="xs:boolean" select="true()"/>
  
  <xsl:variable name="preserve-xmlns" select="'http://www.deltaxml.com/ns/preserve'"/>
  
  <xsl:variable name="all-element-names" as="xs:QName*" 
    select="distinct-values(for $x in //*[not(self::deltaxml:* or self::er:* or self::preserve:*)] return node-name($x))"/>
  
  <xsl:variable name="mixed-element-names" as="xs:QName*"
    select="for $x in $all-element-names,
            $y in //*[node-name(.) eq $x][fn:check-if-mixed(.)][1] return node-name($y)"/>
  

  <xsl:variable name="any-validated" as="xs:boolean" select="exists(/*[@deltaxml:grammar, @preserve:grammar])"/>
  
  <!-- 
    if xml has already been validated - there's no need to test indentation - assume true.
    Also, don't check for text-nodes following preserve:* elements (e.g. DTD declaration)
    added by core
  -->
  <xsl:variable name="is-indented" as="xs:boolean" 
    select="$any-validated
    or
    exists(/*[child::text()]) 
    or 
    exists(
    /*/*
    [namespace-uri(.) ne $preserve-xmlns][1]/following-sibling::text()
    )"/>
    
  <xsl:template match="@*|processing-instruction()|comment()">
    <xsl:copy-of select="."/>
  </xsl:template>
  
  <xsl:template match="text()">
    <xsl:param name="is-mixed" select="true()"/>
    <xsl:choose>
      <xsl:when test="$any-validated or $is-mixed">
        <xsl:copy/>
      </xsl:when>
      <!-- ignorable whitespace is only wrapped when preserve-ignorable-whitespace is
           set 'true' - this benefits performance considerably    
      -->
      <xsl:when test="$preserve-ignorable-whitespace and string-length(normalize-space(.)) eq 0">
        <preserve:ignorable xml:space="preserve"><xsl:copy/></preserve:ignorable>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
      
  <!-- no need for special whitespace treatment of the contents of these elements -->
  <xsl:template match="*[self::preserve:cdata]">
    <xsl:copy>
      <xsl:attribute name="xml:space" select="'preserve'"/>
      <xsl:copy-of select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
    
  <!-- test un-matched elements for mixed-content or xml:space=preserve characteristics -->
  <xsl:template match="*">
    <xsl:choose>
      <xsl:when test="$is-indented">
        <xsl:copy>
          
          <xsl:variable name="is-mixed" as="xs:boolean"
            select="
            if ($collate-element-type-info) then
            not($any-validated) and (node-name(.) = $mixed-element-names and exists(text()))
            else fn:check-if-mixed(.)"/>
          
          <!--xsl:message select="'name', name(.), 'collate-element-type-info', $collate-element-type-info, 'is-mixed', $is-mixed"/>-->
          
          <xsl:if test="empty(parent::*) and not($any-validated)">
            <xsl:sequence select="fn:grammarAttribute('grammar', 'inferred:whitespace-detection.xsl')"/>                        
          </xsl:if>
          
          <xsl:if test="$is-mixed">
            <xsl:sequence select="fn:grammarAttribute('mixed-content', 'true')"/>
          </xsl:if>
          
          <xsl:if test="not($any-validated) and empty(@xml:space) and ((empty(*) and matches(., '^\s+$')) or fn:preserve-space-in-element(.))">
              <xsl:sequence select="fn:grammarAttribute('space', 'preserve')"/>
          </xsl:if>
          
          <xsl:apply-templates select="@*, node()">
            <xsl:with-param name="is-mixed" select="$is-mixed"/>
          </xsl:apply-templates>         
        </xsl:copy>
      </xsl:when>
      <!-- if not indented and is the document element add xml:space=preserve attribute -->
      <xsl:when test="empty(parent::*)">
        <xsl:copy>
          
          <xsl:if test="not($any-validated)">
            <xsl:sequence select="fn:grammarAttribute('grammar', 'inferred:whitespace-detection.xsl')"/>                                    
          </xsl:if>
          
          <xsl:if test="not($any-validated) and empty(@xml:space)">
            <xsl:sequence select="fn:grammarAttribute('space', 'preserve')"/>            
          </xsl:if>
          
          <xsl:apply-templates select="@*, node()"/>
          
        </xsl:copy>
      </xsl:when>
      <!-- if not indented and not the document element, copy normally -->
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="fn:grammarAttribute" as="attribute()">
    <xsl:param name="attribute-name" as="xs:string"/>
    <xsl:param name="attribute-value" as="xs:string"/>
       
    <xsl:choose>
      <xsl:when test="$preserve-content-model">
        <xsl:attribute name="preserve:{$attribute-name}" select="$attribute-value"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="deltaxml:{$attribute-name}" select="$attribute-value"/>       
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="fn:check-if-mixed" as="xs:boolean">
    <xsl:param name="context" as="element()"/>
    <!-- whitespace-only = there are no child er: elements AND no child text nodes that have text -->
    <xsl:variable name="whitespace-only" as="xs:boolean" 
      select="empty($context/er:*)
      and empty($context/text()[normalize-space()])"/>
    <!-- assume single space char is a separator and not used for formatting -->
    <!-- separators-only = all the child text nodes in the context are just a single space -->
    <xsl:variable name="separators-only" as="xs:boolean" select="every $ws-node in $context/text() satisfies $ws-node eq ' '"/>
<!--    <xsl:message select="'name=', name($context), 'ws-only=', $whitespace-only, 'separators-only=',$separators-only,'exists=',exists($context/text()), 'is-mixed=', exists($context/text()) 
      and (not($whitespace-only) or $separators-only)"/>-->
    <!-- child text nodes exist and EITHER they are not whitespace only OR they are separators only -->
    <xsl:sequence select="exists($context/text()) 
                          and (not($whitespace-only) or $separators-only)"/>
  </xsl:function>
  
  <!-- assumption is that element is indented and not within mixed content -->
  <!-- If the child xml is less indented than the parent, the function detects that the xml has been unusually formatted and this should be preserved -->
  <xsl:function name="fn:preserve-space-in-element" as="xs:boolean">
    <xsl:param name="element" as="element()"/>
    <xsl:for-each select="$element">
      <xsl:variable name="preceding-text" 
        select="(preceding-sibling::text()|preceding-sibling::deltaxml:textGroup/deltaxml:text[1]/text())[1]" as="node()?"/>
      <xsl:choose>
        <xsl:when test="exists($preceding-text)">
          <xsl:variable name="preceding-lines" as="xs:string*" select="tokenize($preceding-text, '\n')"/>
          <xsl:variable name="parent-indent-size" as="xs:integer" select="string-length($preceding-lines[last()])" />
          <xsl:variable name="lines" as="xs:string*" select="tokenize(text()[1], '\n')"/>
          <!-- ignore first line as it has no indentation -->
          <xsl:variable name="line" as="xs:string?" select="$lines[2]"/>
          <xsl:choose>
            <!-- check for case where '&lt' is represented as <er:lt/> in code snippets -->
            <xsl:when test="exists($line) and not(matches($line, '^\s*$') and not(node()[2][self::er:lt]))">
              <xsl:variable name="trimmed-line" as="xs:string" select="replace($line, '^\s+','')"/>
              <xsl:variable name="child-indent-size" select="string-length($line) - string-length($trimmed-line)"/>
              <xsl:sequence select="$child-indent-size lt $parent-indent-size"/>
            </xsl:when>
            <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="false()"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:function>
  
</xsl:stylesheet>