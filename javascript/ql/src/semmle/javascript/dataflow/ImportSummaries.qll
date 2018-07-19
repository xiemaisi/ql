import javascript
import external.ExternalArtifact

/**
 * An additional data flow source specified in an `additional-sources.csv` file.
 */
class AdditionalSourceSpec extends ExternalData {
  AdditionalSourceSpec() {
    this.getDataPath() = "additional-sources.csv"
  }

  /**
   * Gets the portal specification of this additional source.
   */
  string getPortalSpec() {
    result = getField(0)
  }

  /**
   * Gets the portal of this additional source.
   */
  DataFlow::Portal getPortal() {
    result.toString() = getPortalSpec()
  }

  /**
   * Gets the type of this source.
   */
  string getSourceType() {
    result = getField(1)
  }

  override string toString() {
    result = getPortalSpec() + " as source for " + getSourceType()
  }
}

private class AdditionalSourceFromSpec extends DataFlow::AdditionalSource {
  AdditionalSourceSpec spec;

  AdditionalSourceFromSpec() {
    this = spec.getPortal().getAnExitNode(_)
  }

  override predicate isSourceFor(DataFlow::Configuration cfg) {
    cfg.toString() = spec.getSourceType()
  }
}

/**
 * An additional data flow sink specified in an `additional-sinks.csv` file.
 */
class AdditionalSinkSpec extends ExternalData {
  AdditionalSinkSpec() {
    this.getDataPath() = "additional-sinks.csv"
  }

  /**
   * Gets the portal specification of this additional sink.
   */
  string getPortalSpec() {
    result = getField(0)
  }

  /**
   * Gets the portal of this additional sink.
   */
  DataFlow::Portal getPortal() {
    result.toString() = getPortalSpec()
  }

  /**
   * Gets the type of this sink.
   */
  string getSinkType() {
    result = getField(1)
  }

  override string toString() {
    result = getPortalSpec() + " as sink for " + getSinkType()
  }
}

private class AdditionalSinkFromSpec extends DataFlow::AdditionalSink {
  AdditionalSinkSpec spec;

  AdditionalSinkFromSpec() {
    this = spec.getPortal().getAnEntryNode(_)
  }

  override predicate isSinkFor(DataFlow::Configuration cfg) {
    cfg.toString() = spec.getSinkType()
  }
}
