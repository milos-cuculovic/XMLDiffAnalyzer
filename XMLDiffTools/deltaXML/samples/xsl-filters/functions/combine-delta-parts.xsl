<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:saxon="http://saxon.sf.net/" exclude-result-prefixes="xs xd deltaxml saxon" version="2.0">
  
  <xsl:include href="merge-functions.xsl"/>
 
  <xd:doc scope="stylesheet">
    <xd:desc>
      <xd:p><xd:b>Created on:</xd:b> March 04, 2013</xd:p>
      <xd:p><xd:b>Author:</xd:b> philf</xd:p>
      <xd:p/>
    </xd:desc>
  </xd:doc>
  
    <xd:doc>
        <xd:desc>
            <xd:p>The effect of this top-level function is to produce an output deltaV2 that is a
                  corrected version of the parent-delta argument, so the '=' and '!=' separators
                  reflect the intersects of the sequences in the child-delta argument.</xd:p>
            <xd:p>This function is effectively a utility wrapper for deltaxml:combineDeltas.
                  It converts the parent and child deltaV2 input parameters to a sequence of equality-sets with
                  any child elements missing from the parent deltaV2 and any duplicate sets removed.
            </xd:p>
            <xd:p>The combineDeltas function is called with the equality-sets as the input argument.
                  The output from this is a sorted sequence of non-intersecting equality sets, these are
                  joined using the '!=' char sequence as a separator to produce a deltaV2 which is
                  the final result.</xd:p>
            <xd:p>
                example:
                (A=B=C=D=E), (A!=B=C=D, A=E, A) => (A!=B=C=D!=E)    
            </xd:p>

        </xd:desc>
        <xd:param name="parent-delta">The delta on the parent element</xd:param>
        <xd:param name="child-deltas">Zero or more child deltas</xd:param>
        <xd:return>The new recalculated parent delta</xd:return>
    </xd:doc> 
    <xsl:function name="deltaxml:combine" as="xs:string">
        <xsl:param name="parentV2Input" as="xs:string"/>
        <xsl:param name="childV2Input" as="xs:string*"/>
        <xsl:variable name="cleanParent" as="xs:string" select="replace($parentV2Input, '!=', '=')"/>
        <xsl:variable name="parentItems" as="xs:string*" select="tokenize($cleanParent, '=')"/>                
        <!-- filter out parentless children - to pass 'illegal children' xspec test -->
        <xsl:variable name="filteredChildV2Input" as="xs:string*"
                      select="distinct-values(
                              for $c in $childV2Input, $d in tokenize($c, '!=') return
                              deltaxml:filterPart($d, $parentItems)
                              )"/>
        <xsl:variable name="combinedParts" as="xs:string+"
            select="deltaxml:combineDeltas(($cleanParent, $filteredChildV2Input))"/>
        <xsl:sequence select="string-join($combinedParts, '!=')"/>
    </xsl:function>
  
    <xd:doc>
        <xd:desc>
            <xd:p>The top-level combination function. Used to break down the input sequence of 'equality-set'
                strings into a sequence of equality-sets such that there is no intersection between each set and
                there are no duplicate sets. An equality set is represented by a string with an '=' char separating
                each item in the set. So a sample input sequence and result could be: 
                ('base=anna=ben', 'anna=ben', 'charlie') => ('anna=ben', 'base', 'charlie')
            </xd:p>
            <xd:p>
                examples:
                (A=B=C) => A=B=C
                (A=B=C, A=B=C) => A=B=C
                (A=B=C=D, E, A=B=C=D=E, A, B=C=D=E) => A, B=C=D, E       
            </xd:p>
            <xd:p>call the combinePair function, on each item (eg A=B=C) against all other items - except itself,
                  for an input sequence of 5 items such as: (A=B=C=D, E, A=B=C=D=E, A, B=C=D=E)
                  this function would be called with the following input sequence positions:
                  (1,2), (1,3), (1,4), (1,5), (2,3), (2,4), (2,5), (3,4), (3,5), (4,5)</xd:p>
            <xd:p>combinePair takes 2 items and produces the non-intersecting combination as the output
                  eg. (A=B=C), (B=C) => (A), (B=C)</xd:p>
            <xd:p>if the combinePair of an item-pair produces a result different to the input,
                replace the item-pair in the input sequence with the output sequence,
                remove any duplicates, then restart the entire sequence-comparison, combineDeltas</xd:p>
            <xd:p>the comparison completes once all combinePair function calls produce the same
                  output sequence as the input, the input is output as the result and the operation
                  terminates</xd:p>
        </xd:desc>
        <xd:param name="parent-delta">The delta on the parent element</xd:param>
        <xd:param name="child-deltas">Zero or more child deltas</xd:param>
        <xd:return>The new recalculated parent delta</xd:return>
    </xd:doc> 
    <xsl:function name="deltaxml:combineDeltas" as="xs:string+">
        <xsl:param name="groupDeltas" as="xs:string+"/>
        <xsl:sequence select="deltaxml:combineDeltas(
            $groupDeltas, 1, deltaxml:combiner-indices(count($groupDeltas)))"/>
    </xsl:function>

  <xsl:function name="deltaxml:combineDeltas" as="xs:string*">
    <xsl:param name="items" as="xs:string*"/>
    <xsl:param name="index" as="xs:integer"/>
    <xsl:param name="combiner-pairs" as="xs:integer*"/>
    <xsl:variable name="combiner-index" as="xs:integer" select="($index * 2) - 1"/>
    <xsl:choose>
      <xsl:when test="count($items) eq 1">
        <xsl:sequence select="$items"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="indices" as="xs:integer*"
                      select="$combiner-pairs[$combiner-index], $combiner-pairs[$combiner-index + 1]"/>
        <xsl:variable name="item-1" select="$items[$indices[1]]"/>
        <xsl:variable name="item-2" select="$items[$indices[2]]"/>
        
        <xsl:variable name="combine-out" as="xs:string*" select="deltaxml:combinePair($item-1, $item-2)"/>
        
        <xsl:variable name="combine-is-identical" as="xs:boolean"
                      select="count($combine-out) eq 2
                              and deltaxml:compare-items(($item-1, $item-2), $combine-out) "/>
        <xsl:variable name="is-last-combination" as="xs:boolean"
                      select="$combiner-index + 1 eq count($combiner-pairs)"/>
        
        <xsl:choose>
          <xsl:when test="$is-last-combination and $combine-is-identical">
            <xsl:sequence select="deltaxml:sort-strings(distinct-values($items))"/>               
          </xsl:when>
          <xsl:when test="$combine-is-identical">
            <xsl:sequence select="deltaxml:combineDeltas($items, $index + 1, $combiner-pairs)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:variable name="filtered-items" as="xs:string*" select="deltaxml:exclude-items($items, $indices)"/>
            <xsl:variable name="new-items" as="xs:string*" select="distinct-values(($filtered-items, $combine-out))"/>
            <xsl:variable name="new-combiner-pairs" as="xs:integer*"
                          select="if (count($items) eq count($new-items)) then
                                  $combiner-pairs
                                  else deltaxml:combiner-indices(count($new-items))"/>
            <xsl:sequence select="deltaxml:combineDeltas($new-items, 1, $new-combiner-pairs)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:function>

    <!--
        examples:  A=B=C combine B=C=D => A, B=C, D
        A=B=C combine A=B=C => A=B=C
        A=B=C combine C => A=B, C
        A=B=C combine D=E => A=B=C, D=E
    -->
    <xsl:function name="deltaxml:combinePair" as="xs:string+">
        <xsl:param name="eq1" as="xs:string"/>
        <xsl:param name="eq2" as="xs:string"/>
        <xsl:variable name="eq1values" select="tokenize($eq1, '=')" as="xs:string+"/>
        <xsl:variable name="eq2values" select="tokenize($eq2, '=')" as="xs:string+"/>
        <xsl:variable name="intersection" select="deltaxml:value-intersect($eq1values, $eq2values)"
            as="xs:string*"/>
        <xsl:variable name="eq1minuscommon" select="deltaxml:value-except($eq1values, $intersection)"
            as="xs:string*"/>
        <xsl:variable name="eq2minuscommon" select="deltaxml:value-except($eq2values, $intersection)"
            as="xs:string*"/>
        <xsl:sequence
            select="distinct-values((string-join($intersection, '='), 
            string-join($eq1minuscommon, '='),
            string-join($eq2minuscommon, '='))[. ne ''])"/>
    </xsl:function>
 
  <xsl:function name="deltaxml:exclude-items" as="xs:string*">
    <xsl:param name="sequence" as="xs:string+"/>
    <xsl:param name="exclude-indices" as="xs:integer+"/>
    <xsl:sequence select="for $x in 1 to count($sequence) return
                          if ($x = $exclude-indices) then ()
                          else $sequence[$x]"/>
  </xsl:function>
  
  <!-- unordered comparison of 2 pairs of strings
  returns true if they are the same -->
  <xsl:function name="deltaxml:compare-items" as="xs:boolean">
    <xsl:param name="pair-1" as="xs:string+"/>
    <xsl:param name="pair-2" as="xs:string+"/>
    <xsl:sequence select="if (deep-equal($pair-1[1], $pair-2[1])) then
                          deep-equal($pair-1[2], $pair-2[2])
                          else if (deep-equal($pair-1[1], $pair-2[2])) then
                          deep-equal($pair-1[2], $pair-2[1])
                          else false()"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:sort-strings" as="xs:string*">
    <xsl:param name="input" as="xs:string*"/> 
    <xsl:for-each select="$input">
      <xsl:sort select="."/>
      <xsl:copy-of select="."/>
    </xsl:for-each>
  </xsl:function>
  
  <!-- 
  create sequence of indices pairs to cover all combine permutations for a given
  number of sequence items. Empty sequence returned if $max parameter less than 2
  sample output: 6 =>  1:2 1:3 1:4 1:5 1:6 2:3 2:4 2:5 2:6 3:4 3:5 3:6 4:5 4:6 5:6 
  -->
  <xsl:function name="deltaxml:combiner-indices" as="xs:integer*">
    <xsl:param name="max" as="xs:integer"/>
    <xsl:for-each select="1 to $max">
      <xsl:variable name="outer" select="." as="xs:integer"/>
      <xsl:for-each select="$outer + 1 to $max">
        <xsl:sequence select="($outer, xs:integer(.))"/>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:function>

    <xsl:function name="deltaxml:filterPart" as="xs:string*">
        <xsl:param name="part" as="xs:string"/>
        <xsl:param name="filter" as="xs:string*"/>
        <xsl:variable name="result" as="xs:string*"
                      select="for $c in tokenize($part, '=') return
                              if ($c = $filter) then $c else ()"/>  
        <xsl:sequence select="if (exists($result)) then string-join($result, '=') else ()"/>
    </xsl:function>
  
</xsl:stylesheet>

