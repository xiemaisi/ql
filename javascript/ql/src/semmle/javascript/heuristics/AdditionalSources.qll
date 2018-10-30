/**
 * Provides classes that heuristically increase the extent of the sources in security queries.
 *
 * Note: This module should not be a permanent part of the standard library imports.
 */

import javascript
import SyntacticHeuristics

/**
 * A heuristic source of data flow in a security query.
 */
abstract class HeuristicSource extends DataFlow::Node { }

/**
 * An access to a password, viewed a source of remote flow.
 */
private class RemoteFlowPassword extends HeuristicSource, RemoteFlowSource {

  RemoteFlowPassword() {
    isReadFrom(this, "(?is).*(password|passwd).*")
  }

  override string getSourceType() {
    result = "a user provided password"
  }
}

/**
 * A call to a JSON parser, viewed as a likely source of remote flow.
 */
private class JsonParseSource extends HeuristicSource, RemoteFlowSource {
  JsonParseSource() {
    this = any(JsonParserCall jpc).getOutput()
  }

  override string getSourceType() {
    result = "JSON data"
  }
}

/**
 * A parameter called `req` or `request`, viewed as a likely source of remote flow.
 */
private class HeuristicRequestObject extends HeuristicSource, RemoteFlowSource {
  HeuristicRequestObject() {
    exists (string req, Parameter p | req = "req" or req = "request" |
      this = DataFlow::parameterNode(p) and
      p.getName().toLowerCase() = req
    )
  }

  override string getSourceType() {
    result = "request data"
  }
}
