/**
 * @name Uncontrolled data used in path expression
 * @description Accessing paths influenced by users can allow an attacker to access
 *              unexpected resources.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id js/path-injection
 * @tags security
 *       external/cwe/cwe-022
 *       external/cwe/cwe-023
 *       external/cwe/cwe-036
 *       external/cwe/cwe-073
 *       external/cwe/cwe-099
 */

import javascript
import semmle.javascript.security.dataflow.TaintedPath::TaintedPath
import DataFlow::PathGraph
import semmle.javascript.dataflow.Portals
import Security.InterestingPortals

class ConfigurationOverride extends Configuration {
  override predicate isSink(DataFlow::Node sink, DataFlow::FlowLabel label) {
    exists(Portal p | isInteresting(p.toString(), this) and
      sink = p.getAnEntryNode(_)
    ) and
    label instanceof Label::PosixPath
    or
    exists(Portal p |
      p.toString() = "(parameter 2 (member composeWith (member prototype (member Base (root https://www.npmjs.com/package/yeoman-generator)))))" and
      sink = p.getAnEntryNode(_).getALocalSource().getAPropertyWrite().getRhs()
    )
  }
}

from Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "This path depends on $@.", source.getNode(),
  "a user-provided value"
