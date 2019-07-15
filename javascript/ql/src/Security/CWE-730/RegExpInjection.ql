/**
 * @name Regular expression injection
 * @description User input should not be used in regular expressions without first being escaped,
 *              otherwise a malicious user may be able to inject an expression that could require
 *              exponential time on certain inputs.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id js/regex-injection
 * @tags security
 *       external/cwe/cwe-730
 *       external/cwe/cwe-400
 */

import javascript
import semmle.javascript.security.dataflow.RegExpInjection::RegExpInjection
import DataFlow::PathGraph
import semmle.javascript.dataflow.Portals
import Security.InterestingPortals

class ConfigurationOverride extends Configuration {
  override predicate isSink(DataFlow::Node sink) {
    exists(Portal p | isInteresting(p.toString(), this) and
      sink = p.getAnEntryNode(_)
    )
  }
}

from Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "This regular expression is constructed from a $@.",
  source.getNode(), "user-provided value"
