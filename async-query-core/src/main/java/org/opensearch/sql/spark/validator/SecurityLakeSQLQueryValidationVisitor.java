package org.opensearch.sql.spark.validator;

import static org.opensearch.sql.spark.validator.ValidationVisitorHelper.isFileReference;

import org.opensearch.sql.spark.antlr.parser.SecurityLakeSqlBaseParser;
import org.opensearch.sql.spark.antlr.parser.SecurityLakeSqlBaseParserBaseVisitor;

public class SecurityLakeSQLQueryValidationVisitor
    extends SecurityLakeSqlBaseParserBaseVisitor<Void> {
  @Override
  public Void visitTableName(SecurityLakeSqlBaseParser.TableNameContext ctx) {
    String reference = ctx.identifierReference().getText();
    if (isFileReference(reference)) {
      throw new IllegalArgumentException(GrammarElement.FILE + " is not allowed.");
    }
    return super.visitTableName(ctx);
  }

  @Override
  public Void visitFunctionName(SecurityLakeSqlBaseParser.FunctionNameContext ctx) {
    validateFunctionAllowed(ctx.qualifiedName().getText());
    return super.visitFunctionName(ctx);
  }

  private void validateFunctionAllowed(String function) {
    FunctionType type = FunctionType.fromFunctionName(function.toLowerCase());
    switch (type) {
      case AGGREGATE:
      case WINDOW:
      case ARRAY:
      case MAP:
      case DATE_TIMESTAMP:
      case JSON:
      case MATH:
      case STRING:
      case CONDITIONAL:
      case BITWISE:
      case CONVERSION:
      case PREDICATE:
      case GENERATOR:
        break;
      default:
        throw new IllegalArgumentException(function + " is not allowed.");
    }
  }
}
