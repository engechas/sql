/*
 * Copyright OpenSearch Contributors
 * SPDX-License-Identifier: Apache-2.0
 */

package org.opensearch.sql.spark.validator;

import static org.opensearch.sql.spark.validator.GrammarElement.CROSS_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.DESCRIBE_TABLE;
import static org.opensearch.sql.spark.validator.GrammarElement.EXPLAIN;
import static org.opensearch.sql.spark.validator.GrammarElement.FULL_OUTER_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.INNER_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.LATERAL_SUBQUERY;
import static org.opensearch.sql.spark.validator.GrammarElement.LEFT_ANTI_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.LEFT_OUTER_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.LEFT_SEMI_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.MAP_FUNCTIONS;
import static org.opensearch.sql.spark.validator.GrammarElement.RIGHT_OUTER_JOIN;
import static org.opensearch.sql.spark.validator.GrammarElement.SHOW_NAMESPACES;
import static org.opensearch.sql.spark.validator.GrammarElement.SHOW_TABLES;
import static org.opensearch.sql.spark.validator.GrammarElement.WITH;

import com.google.common.collect.ImmutableSet;
import java.util.Set;

public class SecurityLakeGrammarElementValidator extends AllowListGrammarElementValidator {
  public static final Set<GrammarElement> SECURITY_LAKE_ALLOW_LIST =
      ImmutableSet.<GrammarElement>builder()
          .add(
              CROSS_JOIN,
              DESCRIBE_TABLE,
              EXPLAIN,
              FULL_OUTER_JOIN,
              INNER_JOIN,
              LATERAL_SUBQUERY,
              LEFT_ANTI_JOIN,
              LEFT_OUTER_JOIN,
              LEFT_SEMI_JOIN,
              MAP_FUNCTIONS,
              RIGHT_OUTER_JOIN,
              SHOW_NAMESPACES,
              SHOW_TABLES,
              WITH)
          .build();

  public SecurityLakeGrammarElementValidator() {
    super(SECURITY_LAKE_ALLOW_LIST);
  }
}
