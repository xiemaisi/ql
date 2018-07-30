import javascript

class PortalEntrySink extends DataFlow::AdditionalSink {
  DataFlow::Portal p;

  PortalEntrySink() {
    this = p.getAnEntryNode(true)
  }

  override predicate isSinkFor(DataFlow::Configuration cfg) {
    cfg instanceof TaintTracking::Configuration
  }

  DataFlow::Portal getPortal() {
    result = p
  }
}
