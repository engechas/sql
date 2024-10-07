package org.opensearch.sql.spark.validator;

import org.antlr.v4.runtime.CommonTokenStream;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.opensearch.sql.common.antlr.CaseInsensitiveCharStream;
import org.opensearch.sql.common.antlr.SyntaxAnalysisErrorListener;
import org.opensearch.sql.datasource.model.DataSourceType;
import org.opensearch.sql.spark.antlr.parser.FlintSparkSqlExtensionsLexer;
import org.opensearch.sql.spark.antlr.parser.FlintSparkSqlExtensionsParser;

public class FlintExtensionQueryValidator {
  private static final Logger log = LogManager.getLogger(FlintExtensionQueryValidator.class);

  public void validate(String sqlQuery, DataSourceType datasourceType) {
    if (datasourceType != DataSourceType.SECURITY_LAKE) {
      return;
    }

    FlintExtensionQueryValidationVisitor visitor = new FlintExtensionQueryValidationVisitor();
    FlintSparkSqlExtensionsParser parser =
        new FlintSparkSqlExtensionsParser(
            new CommonTokenStream(
                new FlintSparkSqlExtensionsLexer(new CaseInsensitiveCharStream(sqlQuery))));
    parser.addErrorListener(new SyntaxAnalysisErrorListener());

    try {
      visitor.visit(parser.singleStatement());
    } catch (Exception e) {
      log.error("Query validation failed. DataSourceType=" + datasourceType, e);
      throw e;
    }
  }
}
