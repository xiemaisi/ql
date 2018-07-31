/**
 * @name Extract source summaries
 * @description Extracts source summaries, that is, pairs `(p, cfg)` such that taint may flow
 *              from a known source for configuration `cfg` to an escaping entry node of
 *              portal `p`.
 * @kind table
 * @id js/source-summary-extraction
 */

import AllConfigurations
import PortalEntrySink

from TaintTracking::Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink,
     DataFlow::Portal p
where cfg.hasPathFlow(source, sink) and
      p = sink.getNode().(PortalEntrySink).getPortal() and
      // avoid constructing infeasible paths
      sink.getPathSummary().hasCall() = false and
      // exclude uninteresting and noisy configurations
      cfg != "LocationHrefDataFlowConfiguration"
select p, cfg.toString()
