/*
 * Copyright OpenSearch Contributors
 * SPDX-License-Identifier: Apache-2.0
 */

parser grammar SecurityLakeSqlBaseParser;

options { tokenVocab = SqlBaseLexer; }

@members {
  /**
   * When false, INTERSECT is given the greater precedence over the other set
   * operations (UNION, EXCEPT and MINUS) as per the SQL standard.
   */
  public boolean legacy_setops_precedence_enabled = false;

  /**
   * When false, a literal with an exponent would be converted into
   * double type rather than decimal type.
   */
  public boolean legacy_exponent_literal_as_decimal_enabled = false;

  /**
   * When true, the behavior of keywords follows ANSI SQL standard.
   */
  public boolean SQL_standard_keyword_behavior = false;

  /**
   * When true, double quoted literals are identifiers rather than STRINGs.
   */
  public boolean double_quoted_identifiers = false;
}

singleStatement
    : (statement) SEMICOLON* EOF
    ;

statement
    : query                                                            #statementDefault
    | EXPLAIN (LOGICAL | FORMATTED | EXTENDED | CODEGEN | COST)?
        statement                                                      #explain
    | SHOW DATABASES ((FROM | IN) multipartIdentifier)?
            (LIKE? pattern=stringLit)?                                 #showDatabases
    | SHOW TABLES ((FROM | IN) identifierReference)?
        (LIKE? pattern=stringLit)?                                     #showTables
    | SHOW TABLE EXTENDED ((FROM | IN) ns=identifierReference)?
        LIKE pattern=stringLit                                         #showTableExtended
    | SHOW TBLPROPERTIES table=identifierReference
        (LEFT_PAREN key=propertyKey RIGHT_PAREN)?                      #showTblProperties
    | SHOW COLUMNS (FROM | IN) table=identifierReference
        ((FROM | IN) ns=multipartIdentifier)?                          #showColumns
    | SHOW PARTITIONS identifierReference                              #showPartitions
    | (DESC | DESCRIBE) TABLE option=(EXTENDED | FORMATTED)?
        identifierReference                                            #describeTable
    ;

query
    : ctes? queryTerm queryOrganization
    ;

ctes
    : WITH namedQuery (COMMA namedQuery)*
    ;

namedQuery
    : name=errorCapturingIdentifier (columnAliases=identifierList)? AS? LEFT_PAREN query RIGHT_PAREN
    ;

propertyList
    : LEFT_PAREN property (COMMA property)* RIGHT_PAREN
    ;

property
    : key=propertyKey (EQ? value=propertyValue)?
    ;

propertyKey
    : errorCapturingIdentifier (DOT errorCapturingIdentifier)*
    | stringLit
    ;

propertyValue
    : INTEGER_VALUE
    | DECIMAL_VALUE
    | booleanValue
    | stringLit
    ;

identifierReference
    : IDENTIFIER_KW LEFT_PAREN expression RIGHT_PAREN
    | multipartIdentifier
    ;

queryOrganization
    : (ORDER BY order+=sortItem (COMMA order+=sortItem)*)?
      (CLUSTER BY clusterBy+=expression (COMMA clusterBy+=expression)*)?
      (SORT BY sort+=sortItem (COMMA sort+=sortItem)*)?
      windowClause?
      (LIMIT (ALL | limit=expression))?
      (OFFSET offset=expression)?
    ;

queryTerm
    : queryPrimary                                                                       #queryTermDefault
    | left=queryTerm {legacy_setops_precedence_enabled}?
        operator=(INTERSECT | UNION | EXCEPT | SETMINUS) setQuantifier? right=queryTerm  #setOperation
    | left=queryTerm {!legacy_setops_precedence_enabled}?
        operator=INTERSECT setQuantifier? right=queryTerm                                #setOperation
    | left=queryTerm {!legacy_setops_precedence_enabled}?
        operator=(UNION | EXCEPT | SETMINUS) setQuantifier? right=queryTerm              #setOperation
    | left=queryTerm OPERATOR_PIPE operatorPipeRightSide                                 #operatorPipeStatement
    ;

queryPrimary
    : querySpecification                                                    #queryPrimaryDefault
    | fromStatement                                                         #fromStmt
    | TABLE identifierReference                                             #table
    | LEFT_PAREN query RIGHT_PAREN                                          #subquery
    ;

sortItem
    : expression ordering=(ASC | DESC)? (NULLS nullOrder=(LAST | FIRST))?
    ;

fromStatement
    : fromClause fromStatementBody+
    ;

fromStatementBody
    : selectClause
      lateralView*
      whereClause?
      aggregationClause?
      havingClause?
      windowClause?
      queryOrganization
    ;

querySpecification
    : selectClause
      fromClause?
      lateralView*
      whereClause?
      aggregationClause?
      havingClause?
      windowClause?                                                         #regularQuerySpecification
    ;

selectClause
    : SELECT setQuantifier? namedExpressionSeq
    ;

exceptClause
    : EXCEPT LEFT_PAREN exceptCols=multipartIdentifierList RIGHT_PAREN
    ;

whereClause
    : WHERE booleanExpression
    ;

havingClause
    : HAVING booleanExpression
    ;

fromClause
    : FROM relation (COMMA relation)* lateralView* pivotClause? unpivotClause?
    ;

temporalClause
    : FOR? (SYSTEM_VERSION | VERSION) AS OF version
    | FOR? (SYSTEM_TIME | TIMESTAMP) AS OF timestamp=valueExpression
    ;

aggregationClause
    : GROUP BY groupingExpressionsWithGroupingAnalytics+=groupByClause
        (COMMA groupingExpressionsWithGroupingAnalytics+=groupByClause)*
    | GROUP BY groupingExpressions+=expression (COMMA groupingExpressions+=expression)* (
      WITH kind=ROLLUP
    | WITH kind=CUBE
    | kind=GROUPING SETS LEFT_PAREN groupingSet (COMMA groupingSet)* RIGHT_PAREN)?
    ;

groupByClause
    : groupingAnalytics
    | expression
    ;

groupingAnalytics
    : (ROLLUP | CUBE) LEFT_PAREN groupingSet (COMMA groupingSet)* RIGHT_PAREN
    | GROUPING SETS LEFT_PAREN groupingElement (COMMA groupingElement)* RIGHT_PAREN
    ;

groupingElement
    : groupingAnalytics
    | groupingSet
    ;

groupingSet
    : LEFT_PAREN (expression (COMMA expression)*)? RIGHT_PAREN
    | expression
    ;

pivotClause
    : PIVOT LEFT_PAREN aggregates=namedExpressionSeq FOR pivotColumn IN LEFT_PAREN pivotValues+=pivotValue (COMMA pivotValues+=pivotValue)* RIGHT_PAREN RIGHT_PAREN
    ;

pivotColumn
    : identifiers+=errorCapturingIdentifier
    | LEFT_PAREN identifiers+=errorCapturingIdentifier (COMMA identifiers+=errorCapturingIdentifier)* RIGHT_PAREN
    ;

pivotValue
    : expression (AS? errorCapturingIdentifier)?
    ;

unpivotClause
    : UNPIVOT nullOperator=unpivotNullClause? LEFT_PAREN
        operator=unpivotOperator
      RIGHT_PAREN (AS? errorCapturingIdentifier)?
    ;

unpivotNullClause
    : (INCLUDE | EXCLUDE) NULLS
    ;

unpivotOperator
    : (unpivotSingleValueColumnClause | unpivotMultiValueColumnClause)
    ;

unpivotSingleValueColumnClause
    : unpivotValueColumn FOR unpivotNameColumn IN LEFT_PAREN unpivotColumns+=unpivotColumnAndAlias (COMMA unpivotColumns+=unpivotColumnAndAlias)* RIGHT_PAREN
    ;

unpivotMultiValueColumnClause
    : LEFT_PAREN unpivotValueColumns+=unpivotValueColumn (COMMA unpivotValueColumns+=unpivotValueColumn)* RIGHT_PAREN
      FOR unpivotNameColumn
      IN LEFT_PAREN unpivotColumnSets+=unpivotColumnSet (COMMA unpivotColumnSets+=unpivotColumnSet)* RIGHT_PAREN
    ;

unpivotColumnSet
    : LEFT_PAREN unpivotColumns+=unpivotColumn (COMMA unpivotColumns+=unpivotColumn)* RIGHT_PAREN unpivotAlias?
    ;

unpivotValueColumn
    : identifier
    ;

unpivotNameColumn
    : identifier
    ;

unpivotColumnAndAlias
    : unpivotColumn unpivotAlias?
    ;

unpivotColumn
    : multipartIdentifier
    ;

unpivotAlias
    : AS? errorCapturingIdentifier
    ;

lateralView
    : LATERAL VIEW (OUTER)? qualifiedName LEFT_PAREN (expression (COMMA expression)*)? RIGHT_PAREN tblName=identifier (AS? colName+=identifier (COMMA colName+=identifier)*)?
    ;

setQuantifier
    : DISTINCT
    | ALL
    ;

relation
    : LATERAL? relationPrimary relationExtension*
    ;

relationExtension
    : joinRelation
    | pivotClause
    | unpivotClause
    ;

joinRelation
    : (joinType) JOIN LATERAL? right=relationPrimary joinCriteria?
    | NATURAL joinType JOIN LATERAL? right=relationPrimary
    ;

joinType
    : INNER?
    | CROSS
    | LEFT OUTER?
    | LEFT? SEMI
    | RIGHT OUTER?
    | FULL OUTER?
    | LEFT? ANTI
    ;

joinCriteria
    : ON booleanExpression
    | USING identifierList
    ;

identifierList
    : LEFT_PAREN identifierSeq RIGHT_PAREN
    ;

identifierSeq
    : ident+=errorCapturingIdentifier (COMMA ident+=errorCapturingIdentifier)*
    ;

relationPrimary
    : identifierReference temporalClause?
      optionsClause? tableAlias                             #tableName
    | LEFT_PAREN query RIGHT_PAREN tableAlias               #aliasedQuery
    | LEFT_PAREN relation RIGHT_PAREN tableAlias            #aliasedRelation
    | functionTable                                         #tableValuedFunction
    ;

optionsClause
    : WITH options=propertyList
    ;

functionTableSubqueryArgument
    : TABLE identifierReference tableArgumentPartitioning?
    | TABLE LEFT_PAREN identifierReference RIGHT_PAREN tableArgumentPartitioning?
    | TABLE LEFT_PAREN query RIGHT_PAREN tableArgumentPartitioning?
    ;

tableArgumentPartitioning
    : ((WITH SINGLE PARTITION)
        | (PARTITION BY
            (((LEFT_PAREN partition+=expression (COMMA partition+=expression)* RIGHT_PAREN))
            | (expression (COMMA invalidMultiPartitionExpression=expression)+)
            | partition+=expression)))
      ((ORDER | SORT) BY
        (((LEFT_PAREN sortItem (COMMA sortItem)* RIGHT_PAREN)
        | (sortItem (COMMA invalidMultiSortItem=sortItem)+)
        | sortItem)))?
    ;

functionTableNamedArgumentExpression
    : key=identifier FAT_ARROW table=functionTableSubqueryArgument
    ;

functionTableReferenceArgument
    : functionTableSubqueryArgument
    | functionTableNamedArgumentExpression
    ;

functionTableArgument
    : functionTableReferenceArgument
    | functionArgument
    ;

functionTable
    : funcName=functionName LEFT_PAREN
      (functionTableArgument (COMMA functionTableArgument)*)?
      RIGHT_PAREN tableAlias
    ;

tableAlias
    : (AS? strictIdentifier identifierList?)?
    ;

multipartIdentifierList
    : multipartIdentifier (COMMA multipartIdentifier)*
    ;

multipartIdentifier
    : parts+=errorCapturingIdentifier (DOT parts+=errorCapturingIdentifier)*
    ;

namedExpression
    : expression (AS? (name=errorCapturingIdentifier | identifierList))?
    ;

namedExpressionSeq
    : namedExpression (COMMA namedExpression)*
    ;

expression
    : booleanExpression
    ;

namedArgumentExpression
    : key=identifier FAT_ARROW value=expression
    ;

functionArgument
    : expression
    | namedArgumentExpression
    ;

booleanExpression
    : (NOT | BANG) booleanExpression                               #logicalNot
    | EXISTS LEFT_PAREN query RIGHT_PAREN                          #exists
    | valueExpression predicate?                                   #predicated
    | left=booleanExpression operator=AND right=booleanExpression  #logicalBinary
    | left=booleanExpression operator=OR right=booleanExpression   #logicalBinary
    ;

predicate
    : errorCapturingNot? kind=BETWEEN lower=valueExpression AND upper=valueExpression
    | errorCapturingNot? kind=IN LEFT_PAREN expression (COMMA expression)* RIGHT_PAREN
    | errorCapturingNot? kind=IN LEFT_PAREN query RIGHT_PAREN
    | errorCapturingNot? kind=RLIKE pattern=valueExpression
    | errorCapturingNot? kind=(LIKE | ILIKE) quantifier=(ANY | SOME | ALL) (LEFT_PAREN RIGHT_PAREN | LEFT_PAREN expression (COMMA expression)* RIGHT_PAREN)
    | errorCapturingNot? kind=(LIKE | ILIKE) pattern=valueExpression (ESCAPE escapeChar=stringLit)?
    | IS errorCapturingNot? kind=NULL
    | IS errorCapturingNot? kind=(TRUE | FALSE | UNKNOWN)
    | IS errorCapturingNot? kind=DISTINCT FROM right=valueExpression
    ;

errorCapturingNot
    : NOT
    | BANG
    ;

valueExpression
    : primaryExpression                                                                      #valueExpressionDefault
    | operator=(MINUS | PLUS | TILDE) valueExpression                                        #arithmeticUnary
    | left=valueExpression operator=(ASTERISK | SLASH | PERCENT | DIV) right=valueExpression #arithmeticBinary
    | left=valueExpression operator=(PLUS | MINUS | CONCAT_PIPE) right=valueExpression       #arithmeticBinary
    | left=valueExpression shiftOperator right=valueExpression                               #shiftExpression
    | left=valueExpression operator=AMPERSAND right=valueExpression                          #arithmeticBinary
    | left=valueExpression operator=HAT right=valueExpression                                #arithmeticBinary
    | left=valueExpression operator=PIPE right=valueExpression                               #arithmeticBinary
    | left=valueExpression comparisonOperator right=valueExpression                          #comparison
    ;

shiftOperator
    : SHIFT_LEFT
    | SHIFT_RIGHT
    | SHIFT_RIGHT_UNSIGNED
    ;

datetimeUnit
    : YEAR | QUARTER | MONTH
    | WEEK | DAY | DAYOFYEAR
    | HOUR | MINUTE | SECOND | MILLISECOND | MICROSECOND
    ;

primaryExpression
    : name=(CURRENT_DATE | CURRENT_TIMESTAMP | CURRENT_USER | USER | SESSION_USER)             #currentLike
    | name=(TIMESTAMPADD | DATEADD | DATE_ADD) LEFT_PAREN (unit=datetimeUnit | invalidUnit=stringLit) COMMA unitsAmount=valueExpression COMMA timestamp=valueExpression RIGHT_PAREN             #timestampadd
    | name=(TIMESTAMPDIFF | DATEDIFF | DATE_DIFF | TIMEDIFF) LEFT_PAREN (unit=datetimeUnit | invalidUnit=stringLit) COMMA startTimestamp=valueExpression COMMA endTimestamp=valueExpression RIGHT_PAREN    #timestampdiff
    | CASE whenClause+ (ELSE elseExpression=expression)? END                                   #searchedCase
    | CASE value=expression whenClause+ (ELSE elseExpression=expression)? END                  #simpleCase
    | name=(CAST | TRY_CAST) LEFT_PAREN expression AS dataType RIGHT_PAREN                     #cast
    | primaryExpression collateClause                                                      #collate
    | primaryExpression DOUBLE_COLON dataType                                                  #castByColon
    | STRUCT LEFT_PAREN (argument+=namedExpression (COMMA argument+=namedExpression)*)? RIGHT_PAREN #struct
    | FIRST LEFT_PAREN expression (IGNORE NULLS)? RIGHT_PAREN                                  #first
    | ANY_VALUE LEFT_PAREN expression (IGNORE NULLS)? RIGHT_PAREN                              #any_value
    | LAST LEFT_PAREN expression (IGNORE NULLS)? RIGHT_PAREN                                   #last
    | POSITION LEFT_PAREN substr=valueExpression IN str=valueExpression RIGHT_PAREN            #position
    | constant                                                                                 #constantDefault
    | ASTERISK exceptClause?                                                                   #star
    | qualifiedName DOT ASTERISK exceptClause?                                                 #star
    | LEFT_PAREN namedExpression (COMMA namedExpression)+ RIGHT_PAREN                          #rowConstructor
    | LEFT_PAREN query RIGHT_PAREN                                                             #subqueryExpression
    | functionName LEFT_PAREN (setQuantifier? argument+=functionArgument
       (COMMA argument+=functionArgument)*)? RIGHT_PAREN
       (WITHIN GROUP LEFT_PAREN ORDER BY sortItem (COMMA sortItem)* RIGHT_PAREN)?
       (FILTER LEFT_PAREN WHERE where=booleanExpression RIGHT_PAREN)?
       (nullsOption=(IGNORE | RESPECT) NULLS)? ( OVER windowSpec)?                             #functionCall
    | identifier ARROW expression                                                              #lambda
    | LEFT_PAREN identifier (COMMA identifier)+ RIGHT_PAREN ARROW expression                   #lambda
    | value=primaryExpression LEFT_BRACKET index=valueExpression RIGHT_BRACKET                 #subscript
    | identifier                                                                               #columnReference
    | base=primaryExpression DOT fieldName=identifier                                          #dereference
    | LEFT_PAREN expression RIGHT_PAREN                                                        #parenthesizedExpression
    | EXTRACT LEFT_PAREN field=identifier FROM source=valueExpression RIGHT_PAREN              #extract
    | (SUBSTR | SUBSTRING) LEFT_PAREN str=valueExpression (FROM | COMMA) pos=valueExpression
      ((FOR | COMMA) len=valueExpression)? RIGHT_PAREN                                         #substring
    | TRIM LEFT_PAREN trimOption=(BOTH | LEADING | TRAILING)? (trimStr=valueExpression)?
       FROM srcStr=valueExpression RIGHT_PAREN                                                 #trim
    | OVERLAY LEFT_PAREN input=valueExpression PLACING replace=valueExpression
      FROM position=valueExpression (FOR length=valueExpression)? RIGHT_PAREN                  #overlay
    ;

literalType
    : DATE
    | TIMESTAMP | TIMESTAMP_LTZ | TIMESTAMP_NTZ
    | INTERVAL
    | BINARY_HEX
    | unsupportedType=identifier
    ;

constant
    : NULL                                                                                     #nullLiteral
    | QUESTION                                                                                 #posParameterLiteral
    | COLON identifier                                                                         #namedParameterLiteral
    | interval                                                                                 #intervalLiteral
    | literalType stringLit                                                                    #typeConstructor
    | number                                                                                   #numericLiteral
    | booleanValue                                                                             #booleanLiteral
    | stringLit+                                                                               #stringLiteral
    ;

comparisonOperator
    : EQ | NEQ | NEQJ | LT | LTE | GT | GTE | NSEQ
    ;

booleanValue
    : TRUE | FALSE
    ;

interval
    : INTERVAL (errorCapturingMultiUnitsInterval | errorCapturingUnitToUnitInterval)
    ;

errorCapturingMultiUnitsInterval
    : body=multiUnitsInterval unitToUnitInterval?
    ;

multiUnitsInterval
    : (intervalValue unit+=unitInMultiUnits)+
    ;

errorCapturingUnitToUnitInterval
    : body=unitToUnitInterval (error1=multiUnitsInterval | error2=unitToUnitInterval)?
    ;

unitToUnitInterval
    : value=intervalValue from=unitInUnitToUnit TO to=unitInUnitToUnit
    ;

intervalValue
    : (PLUS | MINUS)?
      (INTEGER_VALUE | DECIMAL_VALUE | stringLit)
    ;

unitInMultiUnits
    : NANOSECOND | NANOSECONDS | MICROSECOND | MICROSECONDS | MILLISECOND | MILLISECONDS
    | SECOND | SECONDS | MINUTE | MINUTES | HOUR | HOURS | DAY | DAYS | WEEK | WEEKS
    | MONTH | MONTHS | YEAR | YEARS
    ;

unitInUnitToUnit
    : SECOND | MINUTE | HOUR | DAY | MONTH | YEAR
    ;

collateClause
    : COLLATE collationName=identifier
    ;

type
    : BOOLEAN
    | TINYINT | BYTE
    | SMALLINT | SHORT
    | INT | INTEGER
    | BIGINT | LONG
    | FLOAT | REAL
    | DOUBLE
    | DATE
    | TIMESTAMP | TIMESTAMP_NTZ | TIMESTAMP_LTZ
    | STRING collateClause?
    | CHARACTER | CHAR
    | VARCHAR
    | BINARY
    | DECIMAL | DEC | NUMERIC
    | VOID
    | INTERVAL
    | VARIANT
    | ARRAY | STRUCT | MAP
    | unsupportedType=identifier
    ;

dataType
    : complex=ARRAY LT dataType GT                              #complexDataType
    | complex=MAP LT dataType COMMA dataType GT                 #complexDataType
    | complex=STRUCT (LT complexColTypeList? GT | NEQ)          #complexDataType
    | INTERVAL from=(YEAR | MONTH) (TO to=MONTH)?               #yearMonthIntervalDataType
    | INTERVAL from=(DAY | HOUR | MINUTE | SECOND)
      (TO to=(HOUR | MINUTE | SECOND))?                         #dayTimeIntervalDataType
    | type (LEFT_PAREN INTEGER_VALUE
      (COMMA INTEGER_VALUE)* RIGHT_PAREN)?                      #primitiveDataType
    ;

complexColTypeList
    : complexColType (COMMA complexColType)*
    ;

complexColType
    : errorCapturingIdentifier COLON? dataType (errorCapturingNot NULL)?
    ;

whenClause
    : WHEN condition=expression THEN result=expression
    ;

windowClause
    : WINDOW namedWindow (COMMA namedWindow)*
    ;

namedWindow
    : name=errorCapturingIdentifier AS windowSpec
    ;

windowSpec
    : name=errorCapturingIdentifier                         #windowRef
    | LEFT_PAREN name=errorCapturingIdentifier RIGHT_PAREN  #windowRef
    | LEFT_PAREN
      ( CLUSTER BY partition+=expression (COMMA partition+=expression)*
      | (PARTITION BY partition+=expression (COMMA partition+=expression)*)?
        ((ORDER | SORT) BY sortItem (COMMA sortItem)*)?)
      windowFrame?
      RIGHT_PAREN                                           #windowDef
    ;

windowFrame
    : frameType=RANGE start=frameBound
    | frameType=ROWS start=frameBound
    | frameType=RANGE BETWEEN start=frameBound AND end=frameBound
    | frameType=ROWS BETWEEN start=frameBound AND end=frameBound
    ;

frameBound
    : UNBOUNDED boundType=(PRECEDING | FOLLOWING)
    | boundType=CURRENT ROW
    | expression boundType=(PRECEDING | FOLLOWING)
    ;

functionName
    : IDENTIFIER_KW LEFT_PAREN expression RIGHT_PAREN
    | identFunc=IDENTIFIER_KW   // IDENTIFIER itself is also a valid function name.
    | qualifiedName
    | FILTER
    | LEFT
    | RIGHT
    ;

qualifiedName
    : identifier (DOT identifier)*
    ;

// this rule is used for explicitly capturing wrong identifiers such as test-table, which should actually be `test-table`
// replace identifier with errorCapturingIdentifier where the immediate follow symbol is not an expression, otherwise
// valid expressions such as "a-b" can be recognized as an identifier
errorCapturingIdentifier
    : identifier errorCapturingIdentifierExtra
    ;

// extra left-factoring grammar
errorCapturingIdentifierExtra
    : (MINUS identifier)+    #errorIdent
    |                        #realIdent
    ;

identifier
    : strictIdentifier
    | {!SQL_standard_keyword_behavior}? strictNonReserved
    ;

strictIdentifier
    : IDENTIFIER              #unquotedIdentifier
    | quotedIdentifier        #quotedIdentifierAlternative
    | {SQL_standard_keyword_behavior}? ansiNonReserved #unquotedIdentifier
    | {!SQL_standard_keyword_behavior}? nonReserved    #unquotedIdentifier
    ;

quotedIdentifier
    : BACKQUOTED_IDENTIFIER
    | {double_quoted_identifiers}? DOUBLEQUOTED_STRING
    ;

number
    : {!legacy_exponent_literal_as_decimal_enabled}? MINUS? EXPONENT_VALUE #exponentLiteral
    | {!legacy_exponent_literal_as_decimal_enabled}? MINUS? DECIMAL_VALUE  #decimalLiteral
    | {legacy_exponent_literal_as_decimal_enabled}? MINUS? (EXPONENT_VALUE | DECIMAL_VALUE) #legacyDecimalLiteral
    | MINUS? INTEGER_VALUE            #integerLiteral
    | MINUS? BIGINT_LITERAL           #bigIntLiteral
    | MINUS? SMALLINT_LITERAL         #smallIntLiteral
    | MINUS? TINYINT_LITERAL          #tinyIntLiteral
    | MINUS? DOUBLE_LITERAL           #doubleLiteral
    | MINUS? FLOAT_LITERAL            #floatLiteral
    | MINUS? BIGDECIMAL_LITERAL       #bigDecimalLiteral
    ;

stringLit
    : STRING_LITERAL
    | {!double_quoted_identifiers}? DOUBLEQUOTED_STRING
    ;

version
    : INTEGER_VALUE
    | stringLit
    ;

operatorPipeRightSide
    : selectClause
    | whereClause
    // The following two cases match the PIVOT or UNPIVOT clause, respectively.
    // For each one, we add the other clause as an option in order to return high-quality error
    // messages in the event that both are present (this is not allowed).
    | pivotClause unpivotClause?
    | unpivotClause pivotClause?
    ;

// When `SQL_standard_keyword_behavior=true`, there are 2 kinds of keywords in Spark SQL.
// - Reserved keywords:
//     Keywords that are reserved and can't be used as identifiers for table, view, column,
//     function, alias, etc.
// - Non-reserved keywords:
//     Keywords that have a special meaning only in particular contexts and can be used as
//     identifiers in other contexts. For example, `EXPLAIN SELECT ...` is a command, but EXPLAIN
//     can be used as identifiers in other places.
// You can find the full keywords list by searching "Start of the keywords list" in this file.
// The non-reserved keywords are listed below. Keywords not in this list are reserved keywords.
ansiNonReserved
//--ANSI-NON-RESERVED-START
    : ADD
    | AFTER
    | ALTER
    | ALWAYS
    | ANALYZE
    | ANTI
    | ANY_VALUE
    | ARCHIVE
    | ARRAY
    | ASC
    | AT
    | BEGIN
    | BETWEEN
    | BIGINT
    | BINARY
    | BINARY_HEX
    | BINDING
    | BOOLEAN
    | BUCKET
    | BUCKETS
    | BY
    | BYTE
    | CACHE
    | CALLED
    | CASCADE
    | CATALOG
    | CATALOGS
    | CHANGE
    | CHAR
    | CHARACTER
    | CLEAR
    | CLUSTER
    | CLUSTERED
    | CODEGEN
    | COLLECTION
    | COLUMNS
    | COMMENT
    | COMMIT
    | COMPACT
    | COMPACTIONS
    | COMPENSATION
    | COMPUTE
    | CONCATENATE
    | CONTAINS
    | COST
    | CUBE
    | CURRENT
    | DATA
    | DATABASE
    | DATABASES
    | DATE
    | DATEADD
    | DATE_ADD
    | DATEDIFF
    | DATE_DIFF
    | DAY
    | DAYS
    | DAYOFYEAR
    | DBPROPERTIES
    | DEC
    | DECIMAL
    | DECLARE
    | DEFAULT
    | DEFINED
    | DEFINER
    | DELETE
    | DELIMITED
    | DESC
    | DESCRIBE
    | DETERMINISTIC
    | DFS
    | DIRECTORIES
    | DIRECTORY
    | DISTRIBUTE
    | DIV
    | DO
    | DOUBLE
    | DROP
    | ESCAPED
    | EVOLUTION
    | EXCHANGE
    | EXCLUDE
    | EXISTS
    | EXPLAIN
    | EXPORT
    | EXTENDED
    | EXTERNAL
    | EXTRACT
    | FIELDS
    | FILEFORMAT
    | FIRST
    | FLOAT
    | FOLLOWING
    | FORMAT
    | FORMATTED
    | FUNCTION
    | FUNCTIONS
    | GENERATED
    | GLOBAL
    | GROUPING
    | HOUR
    | HOURS
    | IDENTIFIER_KW
    | IDENTITY
    | IF
    | IGNORE
    | IMMEDIATE
    | IMPORT
    | INCLUDE
    | INCREMENT
    | INDEX
    | INDEXES
    | INPATH
    | INPUT
    | INPUTFORMAT
    | INSERT
    | INT
    | INTEGER
    | INTERVAL
    | INVOKER
    | ITEMS
    | ITERATE
    | KEYS
    | LANGUAGE
    | LAST
    | LAZY
    | LEAVE
    | LIKE
    | ILIKE
    | LIMIT
    | LINES
    | LIST
    | LOAD
    | LOCAL
    | LOCATION
    | LOCK
    | LOCKS
    | LOGICAL
    | LONG
    | LOOP
    | MACRO
    | MAP
    | MATCHED
    | MERGE
    | MICROSECOND
    | MICROSECONDS
    | MILLISECOND
    | MILLISECONDS
    | MINUTE
    | MINUTES
    | MODIFIES
    | MONTH
    | MONTHS
    | MSCK
    | NAME
    | NAMESPACE
    | NAMESPACES
    | NANOSECOND
    | NANOSECONDS
    | NO
    | NONE
    | NULLS
    | NUMERIC
    | OF
    | OPTION
    | OPTIONS
    | OUT
    | OUTPUTFORMAT
    | OVER
    | OVERLAY
    | OVERWRITE
    | PARTITION
    | PARTITIONED
    | PARTITIONS
    | PERCENTLIT
    | PIVOT
    | PLACING
    | POSITION
    | PRECEDING
    | PRINCIPALS
    | PROPERTIES
    | PURGE
    | QUARTER
    | QUERY
    | RANGE
    | READS
    | REAL
    | RECORDREADER
    | RECORDWRITER
    | RECOVER
    | REDUCE
    | REFRESH
    | RENAME
    | REPAIR
    | REPEAT
    | REPEATABLE
    | REPLACE
    | RESET
    | RESPECT
    | RESTRICT
    | RETURN
    | RETURNS
    | REVOKE
    | RLIKE
    | ROLE
    | ROLES
    | ROLLBACK
    | ROLLUP
    | ROW
    | ROWS
    | SCHEMA
    | SCHEMAS
    | SECOND
    | SECONDS
    | SECURITY
    | SEMI
    | SEPARATED
    | SERDE
    | SERDEPROPERTIES
    | SET
    | SETMINUS
    | SETS
    | SHORT
    | SHOW
    | SINGLE
    | SKEWED
    | SMALLINT
    | SORT
    | SORTED
    | SOURCE
    | SPECIFIC
    | START
    | STATISTICS
    | STORED
    | STRATIFY
    | STRING
    | STRUCT
    | SUBSTR
    | SUBSTRING
    | SYNC
    | SYSTEM_TIME
    | SYSTEM_VERSION
    | TABLES
    | TABLESAMPLE
    | TARGET
    | TBLPROPERTIES
    | TEMPORARY
    | TERMINATED
    | TIMEDIFF
    | TIMESTAMP
    | TIMESTAMP_LTZ
    | TIMESTAMP_NTZ
    | TIMESTAMPADD
    | TIMESTAMPDIFF
    | TINYINT
    | TOUCH
    | TRANSACTION
    | TRANSACTIONS
    | TRANSFORM
    | TRIM
    | TRUE
    | TRUNCATE
    | TRY_CAST
    | TYPE
    | UNARCHIVE
    | UNBOUNDED
    | UNCACHE
    | UNLOCK
    | UNPIVOT
    | UNSET
    | UNTIL
    | UPDATE
    | USE
    | VALUES
    | VARCHAR
    | VAR
    | VARIABLE
    | VARIANT
    | VERSION
    | VIEW
    | VIEWS
    | VOID
    | WEEK
    | WEEKS
    | WHILE
    | WINDOW
    | YEAR
    | YEARS
    | ZONE
//--ANSI-NON-RESERVED-END
    ;

// When `SQL_standard_keyword_behavior=false`, there are 2 kinds of keywords in Spark SQL.
// - Non-reserved keywords:
//     Same definition as the one when `SQL_standard_keyword_behavior=true`.
// - Strict-non-reserved keywords:
//     A strict version of non-reserved keywords, which can not be used as table alias.
// You can find the full keywords list by searching "Start of the keywords list" in this file.
// The strict-non-reserved keywords are listed in `strictNonReserved`.
// The non-reserved keywords are listed in `nonReserved`.
// These 2 together contain all the keywords.
strictNonReserved
    : ANTI
    | CROSS
    | EXCEPT
    | FULL
    | INNER
    | INTERSECT
    | JOIN
    | LATERAL
    | LEFT
    | NATURAL
    | ON
    | RIGHT
    | SEMI
    | SETMINUS
    | UNION
    | USING
    ;

nonReserved
//--DEFAULT-NON-RESERVED-START
    : ADD
    | AFTER
    | ALL
    | ALTER
    | ALWAYS
    | ANALYZE
    | AND
    | ANY
    | ANY_VALUE
    | ARCHIVE
    | ARRAY
    | AS
    | ASC
    | AT
    | AUTHORIZATION
    | BEGIN
    | BETWEEN
    | BIGINT
    | BINARY
    | BINARY_HEX
    | BINDING
    | BOOLEAN
    | BOTH
    | BUCKET
    | BUCKETS
    | BY
    | BYTE
    | CACHE
    | CALL
    | CALLED
    | CASCADE
    | CASE
    | CAST
    | CATALOG
    | CATALOGS
    | CHANGE
    | CHAR
    | CHARACTER
    | CHECK
    | CLEAR
    | CLUSTER
    | CLUSTERED
    | CODEGEN
    | COLLATE
    | COLLATION
    | COLLECTION
    | COLUMN
    | COLUMNS
    | COMMENT
    | COMMIT
    | COMPACT
    | COMPACTIONS
    | COMPENSATION
    | COMPUTE
    | CONCATENATE
    | CONSTRAINT
    | CONTAINS
    | COST
    | CREATE
    | CUBE
    | CURRENT
    | CURRENT_DATE
    | CURRENT_TIME
    | CURRENT_TIMESTAMP
    | CURRENT_USER
    | DATA
    | DATABASE
    | DATABASES
    | DATE
    | DATEADD
    | DATE_ADD
    | DATEDIFF
    | DATE_DIFF
    | DAY
    | DAYS
    | DAYOFYEAR
    | DBPROPERTIES
    | DEC
    | DECIMAL
    | DECLARE
    | DEFAULT
    | DEFINED
    | DEFINER
    | DELETE
    | DELIMITED
    | DESC
    | DESCRIBE
    | DETERMINISTIC
    | DFS
    | DIRECTORIES
    | DIRECTORY
    | DISTINCT
    | DISTRIBUTE
    | DIV
    | DO
    | DOUBLE
    | DROP
    | ELSE
    | END
    | ESCAPE
    | ESCAPED
    | EVOLUTION
    | EXCHANGE
    | EXCLUDE
    | EXECUTE
    | EXISTS
    | EXPLAIN
    | EXPORT
    | EXTENDED
    | EXTERNAL
    | EXTRACT
    | FALSE
    | FETCH
    | FILTER
    | FIELDS
    | FILEFORMAT
    | FIRST
    | FLOAT
    | FOLLOWING
    | FOR
    | FOREIGN
    | FORMAT
    | FORMATTED
    | FROM
    | FUNCTION
    | FUNCTIONS
    | GENERATED
    | GLOBAL
    | GRANT
    | GROUP
    | GROUPING
    | HAVING
    | HOUR
    | HOURS
    | IDENTIFIER_KW
    | IDENTITY
    | IF
    | IGNORE
    | IMMEDIATE
    | IMPORT
    | IN
    | INCLUDE
    | INCREMENT
    | INDEX
    | INDEXES
    | INPATH
    | INPUT
    | INPUTFORMAT
    | INSERT
    | INT
    | INTEGER
    | INTERVAL
    | INTO
    | INVOKER
    | IS
    | ITEMS
    | ITERATE
    | KEYS
    | LANGUAGE
    | LAST
    | LAZY
    | LEADING
    | LEAVE
    | LIKE
    | LONG
    | ILIKE
    | LIMIT
    | LINES
    | LIST
    | LOAD
    | LOCAL
    | LOCATION
    | LOCK
    | LOCKS
    | LOGICAL
    | LONG
    | LOOP
    | MACRO
    | MAP
    | MATCHED
    | MERGE
    | MICROSECOND
    | MICROSECONDS
    | MILLISECOND
    | MILLISECONDS
    | MINUTE
    | MINUTES
    | MODIFIES
    | MONTH
    | MONTHS
    | MSCK
    | NAME
    | NAMESPACE
    | NAMESPACES
    | NANOSECOND
    | NANOSECONDS
    | NO
    | NONE
    | NOT
    | NULL
    | NULLS
    | NUMERIC
    | OF
    | OFFSET
    | ONLY
    | OPTION
    | OPTIONS
    | OR
    | ORDER
    | OUT
    | OUTER
    | OUTPUTFORMAT
    | OVER
    | OVERLAPS
    | OVERLAY
    | OVERWRITE
    | PARTITION
    | PARTITIONED
    | PARTITIONS
    | PERCENTLIT
    | PIVOT
    | PLACING
    | POSITION
    | PRECEDING
    | PRIMARY
    | PRINCIPALS
    | PROPERTIES
    | PURGE
    | QUARTER
    | QUERY
    | RANGE
    | READS
    | REAL
    | RECORDREADER
    | RECORDWRITER
    | RECOVER
    | REDUCE
    | REFERENCES
    | REFRESH
    | RENAME
    | REPAIR
    | REPEAT
    | REPEATABLE
    | REPLACE
    | RESET
    | RESPECT
    | RESTRICT
    | RETURN
    | RETURNS
    | REVOKE
    | RLIKE
    | ROLE
    | ROLES
    | ROLLBACK
    | ROLLUP
    | ROW
    | ROWS
    | SCHEMA
    | SCHEMAS
    | SECOND
    | SECONDS
    | SECURITY
    | SELECT
    | SEPARATED
    | SERDE
    | SERDEPROPERTIES
    | SESSION_USER
    | SET
    | SETS
    | SHORT
    | SHOW
    | SINGLE
    | SKEWED
    | SMALLINT
    | SOME
    | SORT
    | SORTED
    | SOURCE
    | SPECIFIC
    | SQL
    | START
    | STATISTICS
    | STORED
    | STRATIFY
    | STRING
    | STRUCT
    | SUBSTR
    | SUBSTRING
    | SYNC
    | SYSTEM_TIME
    | SYSTEM_VERSION
    | TABLE
    | TABLES
    | TABLESAMPLE
    | TARGET
    | TBLPROPERTIES
    | TEMPORARY
    | TERMINATED
    | THEN
    | TIME
    | TIMEDIFF
    | TIMESTAMP
    | TIMESTAMP_LTZ
    | TIMESTAMP_NTZ
    | TIMESTAMPADD
    | TIMESTAMPDIFF
    | TINYINT
    | TO
    | TOUCH
    | TRAILING
    | TRANSACTION
    | TRANSACTIONS
    | TRANSFORM
    | TRIM
    | TRUE
    | TRUNCATE
    | TRY_CAST
    | TYPE
    | UNARCHIVE
    | UNBOUNDED
    | UNCACHE
    | UNIQUE
    | UNKNOWN
    | UNLOCK
    | UNPIVOT
    | UNSET
    | UNTIL
    | UPDATE
    | USE
    | USER
    | VALUES
    | VARCHAR
    | VAR
    | VARIABLE
    | VARIANT
    | VERSION
    | VIEW
    | VIEWS
    | VOID
    | WEEK
    | WEEKS
    | WHILE
    | WHEN
    | WHERE
    | WINDOW
    | WITH
    | WITHIN
    | YEAR
    | YEARS
    | ZONE
//--DEFAULT-NON-RESERVED-END
    ;
