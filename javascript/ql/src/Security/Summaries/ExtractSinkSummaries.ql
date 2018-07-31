/**
 * @name Extract sink summaries
 * @description Extracts sink summaries, that is, pairs `(p, cfg)` such that taint may flow
 *              from a user-controlled exit node of portal `p` to a known sink for
 *              configuration `cfg`.
 * @kind table
 * @id js/sink-summary-extraction
 */

import AllConfigurations
import PortalExitSource

from TaintTracking::Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink,
     DataFlow::Portal p
where cfg.hasPathFlow(source, sink) and
      p = source.getNode().(PortalExitSource).getPortal() and
      // avoid constructing infeasible paths
      sink.getPathSummary().hasReturn() = false and
      // exclude uninteresting and noisy configurations
      cfg != "LocationHrefDataFlowConfiguration"
select p, cfg.toString()
