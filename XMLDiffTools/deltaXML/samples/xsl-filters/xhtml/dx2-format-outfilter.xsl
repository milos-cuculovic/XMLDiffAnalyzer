<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (c) 2010-2014 DeltaXML Ltd.  All rights reserved. -->
<!-- 
  This filter is used to reconstruct the spans that were flattened in the corresponding dx2-format-infilter.xsl

  This filter makes use of the xsl:iterate instruction which is a new feature of XSLT 3.0.  Although XSLT 3.0 is
  a W3C working draft, this instruction has been available in Saxon for many years under the guise of saxon:iterate.
  
  In order to make use of this filter in a pipeline some configuration may be necessary in user created or modified DXP
  files or when using the cores9api package.
  
  In a DXP file set a transformerAttribute at the end, for example:
  
  <comparatorPipeline>
    ...
    <transformerAttributes>
      <stringAttribute name="http://saxon.sf.net/feature/xsltVersion" literalValue="3.0"/>
    </transformerAttributes>
  </comparatorPipeline>
  
  The corresponding configuration in Java code would be:
  
  PipelinedComparatorS9 pcs9= new PipelinedComparatorS9();
  pcs9.setTransformerConfigurationOption("http://saxon.sf.net/feature/xsltVersion", "3.0");

 -->
 <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                 xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                 xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
                 xmlns:dxx="http://www.deltaxml.com/ns/xml-namespaced-attribute"
                 xmlns:test="http://www.jenitennison.com/xslt/unit-test"
                 version="3.0">

  
  <xsl:import href="../dx2-extract-version-moded.xsl"/>
  
  <xsl:include href="../functions/nearest-delta.xsl"/>
   
  <!-- 
    The regrouping algorithm was changed in a slighlty incompatible way (we properly implement 4b in the list below)
    after release 6.0.  Setting this parameter to true will preserve the previous behaviour.
    We have provided both string and boolean parameters to support older releases of DXP based pipelines with
    limited parameter typing facilities.  These parameters are equivalent.
    New user are encouraged to accept the 'false' or false() default settings.
  -->
  <xsl:param name="v60compat" as="xs:string" select="'false'"/>
  <xsl:param name="v60compatibility" as="xs:boolean" select="$v60compat ne 'false'"/>
  
   
  <xsl:output method="xml" indent="no" omit-xml-declaration="yes" />


   <!-- default identity transform -->
   <xsl:template match="node() | @*" mode="#default">
     <xsl:copy>
       <xsl:apply-templates select="@* | node()"/>
     </xsl:copy>
   </xsl:template>
   
   <!--
     1. deltaxml:format-start inside a deleted sub-tree: reconstruct all spans     (yes)
     2. deltaxml:format-start inside an added sub-tree: reconstruct all spans      (yes)
     3. deltaxml:format-start inside an unchanged sub-true: reconstruct all spans  (yes)
     4. deltaxml:format-start inside a modified sub-tree:
         a reconstruct all added spans                                             (yes)
         b reconstruct all deleted spans if they're in a group containing          (yes)
           only deleted items with equal numbers of start/end spans with the
           first span a start
   -->
   
   <!--
     This template handles cases 1 to 3 above
   -->
   <xsl:template match="*[deltaxml:format-start][deltaxml:nearest-delta-is(., ('A', 'B', 'A=B'))]">
     <xsl:copy>
       <xsl:apply-templates select="@*"/>
       <xsl:call-template name="group">
         <xsl:with-param name="sequence" select="node()[not(self::deltaxml:element)]"/>
        </xsl:call-template>
     </xsl:copy>
   </xsl:template>
   
   <!-- 
     This template handles case 4 above
   -->
   <xsl:template match="*[deltaxml:format-start][deltaxml:nearest-delta-is(., 'A!=B')]">
     <xsl:param name="v60compatibility" as="xs:boolean" select="$v60compatibility" tunnel="yes"/>   <!-- XSPEC -->
     <xsl:copy>
       <xsl:apply-templates select="@*"/>
       <xsl:call-template name="group">
         <xsl:with-param name="sequence" 
           select="if (not($v60compatibility)) then 
                     deltaxml:clean-split-a-spans(node()[not(self::deltaxml:element)])
                   else
                     node()[not(self::deltaxml:format-start[@deltaxml:deltaV2='A'] or 
                                self::deltaxml:format-end[@deltaxml:deltaV2='A'] or self::deltaxml:element)]"/>
         <xsl:with-param name="version" select="'B'"/>
       </xsl:call-template>
     </xsl:copy>
   </xsl:template>
  
   <xsl:function name="deltaxml:format-element" as="node()">
     <xsl:param name="format-start" as="element(deltaxml:format-start)"/>
     <xsl:param name="version" as="xs:string"/>
     
     <xsl:choose>
       <xsl:when test="$format-start/deltaxml:element[not(@deltaxml:deltaV2)]">
         <xsl:copy-of select="$format-start/deltaxml:element/*"/>
       </xsl:when>
       <xsl:when test="$version='A'">
         <xsl:copy-of select="$format-start/deltaxml:element/*[@deltaxml:deltaV2=('A','A!=B')]"/>
       </xsl:when>
       <xsl:otherwise>
         <xsl:copy-of select="$format-start/deltaxml:element/*[@deltaxml:deltaV2=('B','A!=B')]"/>
       </xsl:otherwise>
     </xsl:choose>
   </xsl:function>
  
   <!--
     Worked example, each line corresponds to an iteration:
     
     <p>T1 <span>T2<span>T3</span><span>T4</span></span><span>T5</span>T6</p>
     
pos                  level    level1StartPos   atLevel1End  
1     T1             0             0           F            copy node to result
2     start(span)    1             2           F            
3     T2             1             2           F            
4     start(span)    2             2           F            
5     T3             2             2           F            
6     end            1             2           F            
7     start(span)    2             2           F            
8     T4             2             2           F            
9     end            1             2           F            
10    end            0             2           T            recurse with subsequence from 2 to 10 (size: 10-2+1)
11    start(span)    1            11           F            
12    T5             1            11           F        
13    end            0            11           T            recurse with subsequence from 11 to 13 (size: 13-11+1)
14    T6             0            11           F            copy node to result
   -->
   <xsl:template name="group">
     <xsl:param name="sequence" as="node()*"/>
     <xsl:param name="version" as="xs:string" select="'B'"/>
     <xsl:iterate select="$sequence">
       <xsl:param name="level" as="xs:integer" select="0"/>
       <xsl:param name="level1StartPos" as="xs:integer"  select="0"/>
       <xsl:variable name="newLevel" as="xs:integer" 
         select="if (self::deltaxml:format-start) then
                    $level + 1 
                 else if (self::deltaxml:format-end) then 
                    $level - 1
                 else
                    $level"/>
       <xsl:variable name="newLevel1StartPos" as="xs:integer" 
         select="if (($newLevel eq 1) and (self::deltaxml:format-start)) then
                    position()
                 else 
                    $level1StartPos"/>
       <xsl:variable name="atLevel1End" as="xs:boolean"
         select="($newLevel eq 0) and (self::deltaxml:format-end)"/>
       <xsl:choose>
         <xsl:when test="$newLevel le 0 and not($atLevel1End)">
           <xsl:apply-templates select="."/> 
           <!-- using apply rather than copy here so that deltaxml:spacers/deltaxml:empty
             can be removed by last template in this file-->
         </xsl:when>
         <xsl:when test="$atLevel1End or ((position() eq last()) and $newLevel gt 0)">
           <xsl:call-template name="create-format-level">
             <xsl:with-param name="sequence" 
               select="subsequence($sequence, $newLevel1StartPos, ((position() - $newLevel1StartPos) + 1))"/>
             <xsl:with-param name="version" select="$version"/>
           </xsl:call-template>
         </xsl:when>
       </xsl:choose>
       <xsl:next-iteration>
         <xsl:with-param name="level" select="$newLevel"/>
         <xsl:with-param name="level1StartPos" select="$newLevel1StartPos"/>
       </xsl:next-iteration>
     </xsl:iterate>
   </xsl:template>
       
   <!-- determines the delta to be used on a formatting element when reconstructing the element
        from its flattened contents.  We know we will be specifying the deltas on child/descendent
         formatting elements based on their contents, so we can ignore the deltas on any
         formatting elements in the sequence. -->
   <xsl:function name="deltaxml:generate-delta" as="xs:string">
     <xsl:param name="sequence" as="node()+"/>
     <xsl:variable name="child-sequence" select="$sequence[not(self::deltaxml:format-start or self::deltaxml:format-end)]" as="node()*"/>
     <xsl:choose>
       <xsl:when test="empty($child-sequence)">
         <!-- nothing contained inside the formatting empty, so use same delta as parent -->
         <xsl:text/>
       </xsl:when>
       <xsl:when test="empty($child-sequence/@deltaxml:deltaV2)">
         <!-- no delta attribute, same as parent -->
         <xsl:text/>
       </xsl:when>
       <xsl:when test="empty($child-sequence[not(self::deltaxml:empty)])">
         <!-- if empty in both inputs, then same as parent -->
         <xsl:text/>
       </xsl:when>
       <xsl:when test="(every $i in $child-sequence/@deltaxml:deltaV2 satisfies $i = 'A') and empty($child-sequence[self::text()])">
         <xsl:text>A</xsl:text>
       </xsl:when>
       <xsl:when test="(every $i in $child-sequence/@deltaxml:deltaV2 satisfies $i = 'B') and empty($child-sequence[self::text()])">
         <xsl:text>B</xsl:text>
       </xsl:when>
       <xsl:when test="every $i in $child-sequence/@deltaxml:deltaV2 satisfies $i = 'A=B'">
         <xsl:text>A=B</xsl:text>
       </xsl:when>
       <xsl:otherwise>
         <xsl:text>A!=B</xsl:text>
       </xsl:otherwise>
     </xsl:choose>
   </xsl:function>
   
   <xsl:function name="deltaxml:clean-split-a-spans">
     <xsl:param name="in" as="node()*"/>
     <xsl:variable name="result" as="node()*">
       <xsl:iterate select="$in">
         <xsl:param name="ALevel" as="xs:integer" select="0"/>
         <xsl:param name="level1AStartPos" as="xs:integer" select="0"/>
         <xsl:variable name="newALevel" as="xs:integer" 
           select="if (self::deltaxml:format-start[contains(@deltaxml:deltaV2, 'A')]) then
                     $ALevel + 1 
                   else if (self::deltaxml:format-end[contains(@deltaxml:deltaV2, 'A')]) then 
                     $ALevel - 1
                   else
                     $ALevel"/>
         <xsl:variable name="newLevel1AStartPos" as="xs:integer" 
           select="if (($newALevel eq 1) and (self::deltaxml:format-start[contains(@deltaxml:deltaV2, 'A')])) then
                     position()
                   else 
                     $level1AStartPos"/>
         <xsl:variable name="atLevel1AEnd" as="xs:boolean"
           select="($newALevel eq 0) and (self::deltaxml:format-end[contains(@deltaxml:deltaV2, 'A')])"/>
         <xsl:choose>
           <xsl:when test="$newALevel eq 0 and (not($atLevel1AEnd))">
             <xsl:sequence select="."/>
           </xsl:when>
           <xsl:when test="$atLevel1AEnd">
           <xsl:variable name="nestedASequence" as="node()*" 
             select="subsequence($in, $newLevel1AStartPos, ((position() - $newLevel1AStartPos) + 1))"/>
           <xsl:choose>
             <xsl:when test="deltaxml:generate-delta($nestedASequence) eq 'A'">
               <xsl:sequence select="$nestedASequence"/>
             </xsl:when>
             <xsl:when test="($nestedASequence[1][@deltaxml:deltaV2='A']) and ($nestedASequence[last()][@deltaxml:deltaV2='A'])">
               <xsl:sequence select="deltaxml:clean-split-a-spans(subsequence($nestedASequence, 2, count($nestedASequence)-2))"/>
             </xsl:when>
             <xsl:when test="$nestedASequence[1][@deltaxml:deltaV2='A']">
               <xsl:sequence select="deltaxml:clean-split-a-spans(subsequence($nestedASequence, 2, count($nestedASequence)-2)), $nestedASequence[last()]"/>
             </xsl:when>
             <xsl:when test="$nestedASequence[last()][@deltaxml:deltaV2='A']">
               <xsl:sequence select="$nestedASequence[1], deltaxml:clean-split-a-spans(subsequence($nestedASequence, 2, count($nestedASequence)-2))"/>
             </xsl:when>
             <xsl:otherwise>
               <!-- Keep both markers and recurse into rest -->
               <xsl:sequence select="$nestedASequence[1], deltaxml:clean-split-a-spans(subsequence($nestedASequence, 2, count($nestedASequence)-2)), $nestedASequence[last()]"/>
             </xsl:otherwise>
           </xsl:choose>
           </xsl:when>
         </xsl:choose>
         <xsl:next-iteration>
           <xsl:with-param name="ALevel" select="$newALevel"/>
           <xsl:with-param name="level1AStartPos" select="$newLevel1AStartPos"></xsl:with-param>
         </xsl:next-iteration>
       </xsl:iterate>
     </xsl:variable>
     <xsl:sequence select="$result"/>
   </xsl:function>
   
     <xsl:template name="create-format-level">
       <xsl:param name="sequence" as="node()*"/>
       <xsl:param name="version" as="xs:string" />
       <xsl:variable name="format-element" select="deltaxml:format-element($sequence[1], $version)" as="element()"/>
       <xsl:element name="{name($format-element)}" namespace="{namespace-uri($format-element)}">
         <xsl:variable name="generated-delta" select="deltaxml:generate-delta($sequence)"/>
         <xsl:choose>
           <xsl:when test="$generated-delta eq '' and $sequence[1]/ancestor::*[1]/@deltaxml:deltaV2='A!=B'">
             <xsl:attribute name="deltaxml:deltaV2" select="'A=B'"/>
           </xsl:when>
           <xsl:when test="$generated-delta ne ''">
             <xsl:attribute name="deltaxml:deltaV2" select="$generated-delta"/>
           </xsl:when>
         </xsl:choose>
         <xsl:copy-of select="$format-element/(@* except @deltaxml:deltaV2)"/>
         <xsl:choose>
           <xsl:when test="$version='A'">
             <xsl:apply-templates select="$format-element/deltaxml:attributes/*" mode="A"/>
           </xsl:when>
           <xsl:when test="$version='B'">
             <xsl:apply-templates select="$format-element/deltaxml:attributes/*" mode="B"/>
           </xsl:when>
           <xsl:otherwise>
             <xsl:apply-templates select="$format-element/deltaxml:attributes"/>
           </xsl:otherwise>
         </xsl:choose>
         <xsl:call-template name="group">
           <xsl:with-param name="sequence" 
             select="if ($sequence[last()][self::deltaxml:format-end])
             then subsequence($sequence, 2, count($sequence)-2)
             else subsequence($sequence, 2)"/>
           <xsl:with-param name="version" select="$version"/>
         </xsl:call-template>
       </xsl:element>
     </xsl:template>

       
   <!-- we don't need to process these -->
   <xsl:template match="deltaxml:format-start | deltaxml:format-end | deltaxml:spacer | deltaxml:empty"/>
   
</xsl:stylesheet>