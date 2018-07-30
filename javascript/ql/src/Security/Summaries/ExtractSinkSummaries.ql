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

from TaintTracking::Configuration cfg, PortalExitSource source, DataFlow::Node sink
where cfg.hasFlow(source, sink)
select source.getPortal(), cfg.toString()
