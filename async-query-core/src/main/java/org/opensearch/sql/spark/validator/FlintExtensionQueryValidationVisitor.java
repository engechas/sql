package org.opensearch.sql.spark.validator;

import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.misc.Interval;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.opensearch.sql.common.antlr.CaseInsensitiveCharStream;
import org.opensearch.sql.common.antlr.SyntaxAnalysisErrorListener;
import org.opensearch.sql.spark.antlr.parser.FlintSparkSqlExtensionsBaseVisitor;
import org.opensearch.sql.spark.antlr.parser.FlintSparkSqlExtensionsParser;
import org.opensearch.sql.spark.antlr.parser.SecurityLakeSqlBaseParser;
import org.opensearch.sql.spark.antlr.parser.SqlBaseLexer;

public class FlintExtensionQueryValidationVisitor extends FlintSparkSqlExtensionsBaseVisitor<Void> {
  private static final Logger log =
      LogManager.getLogger(FlintExtensionQueryValidationVisitor.class);

  @Override
  public Void visitMaterializedViewQuery(
      FlintSparkSqlExtensionsParser.MaterializedViewQueryContext ctx) {
    String innerQuery = getInnerQuery(ctx);
    SecurityLakeSQLQueryValidationVisitor visitor = new SecurityLakeSQLQueryValidationVisitor();

    SecurityLakeSqlBaseParser baseParser =
        new SecurityLakeSqlBaseParser(
            new CommonTokenStream(new SqlBaseLexer(new CaseInsensitiveCharStream(innerQuery))));
    baseParser.addErrorListener(new SyntaxAnalysisErrorListener());
    try {
      visitor.visit(baseParser.singleStatement());
    } catch (Exception e) {
      log.error("Materialized view query validation failed.", e);
      throw e;
    }

    return super.visitMaterializedViewQuery(ctx);
  }

  private String getInnerQuery(FlintSparkSqlExtensionsParser.MaterializedViewQueryContext ctx) {
    int a = ctx.start.getStartIndex();
    int b = ctx.stop.getStopIndex();
    Interval interval = new Interval(a, b);
    return ctx.start.getInputStream().getText(interval);
  }
}
