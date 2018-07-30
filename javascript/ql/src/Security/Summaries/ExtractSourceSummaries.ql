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

from TaintTracking::Configuration cfg, DataFlow::Node source, PortalEntrySink sink
where cfg.hasFlow(source, sink)
select sink.getPortal(), cfg.toString()
