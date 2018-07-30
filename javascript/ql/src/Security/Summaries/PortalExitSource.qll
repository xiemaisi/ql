import javascript

class PortalExitSource extends DataFlow::AdditionalSource {
  DataFlow::Portal p;

  PortalExitSource() {
    this = p.getAnExitNode(true)
  }

  override predicate isSourceFor(DataFlow::Configuration cfg) {
    cfg instanceof TaintTracking::Configuration
  }

  DataFlow::Portal getPortal() {
    result = p
  }
}
