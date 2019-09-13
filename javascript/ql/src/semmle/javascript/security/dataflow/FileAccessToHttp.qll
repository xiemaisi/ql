/**
 * Provides a taint tracking configuration for reasoning about file
 * data in outbound network requests.
 *
 * Note, for performance reasons: only import this file if
 * `FileAccessToHttp::Configuration` is needed, otherwise
 * `FileAccessToHttpCustomizations` should be imported instead.
 */

import javascript

module FileAccessToHttp {
  import FileAccessToHttpCustomizations::FileAccessToHttp

  /**
   * A taint tracking configuration for file data in outbound network requests.
   */
  class Configuration extends DataFlow::Configuration {
    Configuration() { this = "FileAccessToHttp" }

    override predicate isSource(DataFlow::Node source, DataFlow::FlowLabel label) {
      source instanceof Source and label = DataFlow::FlowLabel::data()
    }

    override predicate isSink(DataFlow::Node sink, DataFlow::FlowLabel label) {
      sink instanceof Sink and label = any(DataFlow::FlowLabel lbl)
    }

    override predicate isBarrier(DataFlow::Node node) {
      super.isBarrier(node) or
      node instanceof Sanitizer
    }
  }
}
