/*
 * Copyright OpenSearch Contributors
 * SPDX-License-Identifier: Apache-2.0
 */

package org.opensearch.sql.spark.validator;

import java.util.Map;
import java.util.function.BiConsumer;
import lombok.AllArgsConstructor;
import org.antlr.v4.runtime.CommonTokenStream;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.opensearch.sql.common.antlr.CaseInsensitiveCharStream;
import org.opensearch.sql.common.antlr.SyntaxAnalysisErrorListener;
import org.opensearch.sql.datasource.model.DataSourceType;
import org.opensearch.sql.spark.antlr.parser.SecurityLakeSqlBaseParser;
import org.opensearch.sql.spark.antlr.parser.SqlBaseLexer;
import org.opensearch.sql.spark.utils.SQLQueryUtils;

/** Validate input SQL query based on the DataSourceType. */
@AllArgsConstructor
public class SQLQueryValidator {
  private static final Logger log = LogManager.getLogger(SQLQueryValidator.class);
  private final Map<DataSourceType, BiConsumer<String, DataSourceType>> VALIDATOR_MAPPING =
      Map.of(DataSourceType.SECURITY_LAKE, this::validateSecurityLake);

  private final GrammarElementValidatorProvider grammarElementValidatorProvider;

  /**
   * It will look up validator associated with the DataSourceType, and throw
   * IllegalArgumentException if invalid grammar element is found.
   *
   * @param sqlQuery The query to be validated
   * @param datasourceType
   */
  public void validate(String sqlQuery, DataSourceType datasourceType) {
    final BiConsumer<String, DataSourceType> validatorFunction =
        VALIDATOR_MAPPING.getOrDefault(datasourceType, this::validateDefault);
    validatorFunction.accept(sqlQuery, datasourceType);
  }

  private void validateSecurityLake(String sqlQuery, DataSourceType datasourceType) {
    SecurityLakeSQLQueryValidationVisitor visitor = new SecurityLakeSQLQueryValidationVisitor();
    SecurityLakeSqlBaseParser baseParser =
        new SecurityLakeSqlBaseParser(
            new CommonTokenStream(new SqlBaseLexer(new CaseInsensitiveCharStream(sqlQuery))));
    baseParser.addErrorListener(new SyntaxAnalysisErrorListener());
    try {
      visitor.visit(baseParser.singleStatement());
    } catch (Exception e) {
      log.error("Query validation failed. DataSourceType=" + datasourceType, e);
      throw e;
    }
  }

  private void validateDefault(String sqlQuery, DataSourceType datasourceType) {
    GrammarElementValidator grammarElementValidator =
        grammarElementValidatorProvider.getValidatorForDatasource(datasourceType);
    SQLQueryValidationVisitor visitor = new SQLQueryValidationVisitor(grammarElementValidator);
    try {
      visitor.visit(SQLQueryUtils.getBaseParser(sqlQuery).singleStatement());
    } catch (IllegalArgumentException e) {
      log.error("Query validation failed. DataSourceType=" + datasourceType, e);
      throw e;
    }
  }
}
