/**
 * Provides machinery for performing backward data-flow exploration.
 *
 * Importing this module effectively makes all data-flow and taint-tracking configurations
 * ignore their `isSource` predicate. Instead, flow is tracked from any _initial node_ without
 * incoming flow to a sink node. All initial nodes are then treated as source nodes.
 *
 * NOTE: This does not scale on non-trivial code bases, so this module is of limited usefulness
 * as it stands.
 */

import javascript

private class BackwardExploringConfiguration extends DataFlow::Configuration {
  DataFlow::Configuration cfg;

  BackwardExploringConfiguration() {
    this = cfg
  }

  override predicate isSource(DataFlow::Node node) { any() }

  override predicate isSource(DataFlow::Node node, DataFlow::FlowLabel lbl) { any() }

  override predicate hasFlow(DataFlow::Node source, DataFlow::Node sink) {
    exists(DataFlow::PathNode src, DataFlow::PathNode snk | hasFlowPath(src, snk) |
      source = src.getNode() and
      sink = snk.getNode()
    )
  }

  override predicate hasFlowPath(DataFlow::SourcePathNode source, DataFlow::SinkPathNode sink) {
    exists(DataFlow::MidPathNode first |
      source.getConfiguration() = this and
      source.getASuccessor() = first and
      not exists(DataFlow::MidPathNode mid | mid.getASuccessor() = first) and
      first.getASuccessor*() = sink
    )
  }
}
