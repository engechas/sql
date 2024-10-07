package org.opensearch.sql.spark.validator;

import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;

public class ValidationVisitorHelperTest {
  @Test
  void testMatchesFilePattern() {
    Assertions.assertTrue(ValidationVisitorHelper.isFileReference("text.`/my/file.txt`"));
  }

  @Test
  void testDoesNotMatchFilePattern() {
    Assertions.assertFalse(ValidationVisitorHelper.isFileReference("mytable"));
  }
}
