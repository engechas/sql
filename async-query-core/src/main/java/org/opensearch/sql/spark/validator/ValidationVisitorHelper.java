package org.opensearch.sql.spark.validator;

public class ValidationVisitorHelper {
  private static final String FILE_REFERENCE_PATTERN = "^[a-zA-Z]+\\.`[^`]+`$";

  public static boolean isFileReference(String reference) {
    return reference.matches(FILE_REFERENCE_PATTERN);
  }
}
