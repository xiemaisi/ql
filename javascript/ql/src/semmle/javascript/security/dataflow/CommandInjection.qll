/**
 * Provides a taint tracking configuration for reasoning about command-injection
 * vulnerabilities (CWE-078).
 */

import javascript
import semmle.javascript.security.dataflow.RemoteFlowSources

module CommandInjection {
  /**
   * A data flow source for command-injection vulnerabilities.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for command-injection vulnerabilities.
   */
  abstract class Sink extends DataFlow::Node {
  }

  /**
   * A sanitizer for command-injection vulnerabilities.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * A taint-tracking configuration for reasoning about command-injection vulnerabilities.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "CommandInjection" }

    override predicate isSource(DataFlow::Node source) {
      source instanceof Source
    }

    /**
     * Holds if `sink` is a data flow sink for command-injection vulnerabilities, and
     * the alert should be placed at the node `highlight`.
     */
    predicate isSink(DataFlow::Node sink, DataFlow::Node highlight) {
      sink instanceof Sink and highlight = sink
      or
      indirectCommandInjection(sink, highlight)
    }

    override predicate isSink(DataFlow::Node sink) {
      isSink(sink, _)
    }

    override predicate isSanitizer(DataFlow::Node node) {
      node instanceof Sanitizer
    }
  }

  /** A source of remote user input, considered as a flow source for command injection. */
  class RemoteFlowSourceAsSource extends Source {
    RemoteFlowSourceAsSource() { this instanceof RemoteFlowSource }
  }

  /**
   * A command argument to a function that initiates an operating system command.
  */
  class SystemCommandExecutionSink extends Sink, DataFlow::ValueNode {
    SystemCommandExecutionSink() {
      this = any(SystemCommandExecution sys).getACommandArgument()
    }
  }

  /**
   * Auxiliary data flow configuration for tracking string literals that look like they
   * may refer to an operating system shell, and array literals that may end up being
   * interpreted as argument lists for system commands.
   */
  class ArgumentListTracking extends DataFlow::Configuration {
    ArgumentListTracking() { this = "ArgumentListTracking" }

    override predicate isSource(DataFlow::Node nd) {
      nd instanceof DataFlow::ArrayLiteralNode
      or
      exists (StringLiteral shell | shellCmd(shell, _) |
        nd = DataFlow::valueNode(shell)
      )
    }

    override predicate isSink(DataFlow::Node nd) {
      exists (SystemCommandExecution sys |
        nd = sys.getACommandArgument() or
        nd = sys.getArgumentList()
      )
    }
  }

  /**
   * Holds if `shell arg <cmd>` runs `<cmd>` as a shell command.
   *
   * That is, either `shell` is a Unix shell (`sh` or similar) and
   * `arg` is `"-c"`, or `shell` is `cmd.exe` and `arg` is `"/c"`.
   */
  private predicate shellCmd(StringLiteral shell, string arg) {
    exists (string s | s = shell.getValue() |
      (s = "sh" or s = "bash" or s = "/bin/sh" or s = "/bin/bash")
      and
      arg = "-c"
    )
    or
    exists (string s | s = shell.getValue().toLowerCase() |
      (s = "cmd" or s = "cmd.exe")
      and
      (arg = "/c" or arg = "/C")
    )
  }

  /**
   * An indirect command execution through `sh -c` or `cmd.exe /c`.
   *
   * For example, we may have a call to `childProcess.spawn` like this:
   *
   * ```
   * let sh = "sh";
   * let args = ["-c", cmd];
   * childProcess.spawn(sh, args, cb);
   * ```
   *
   * Here, the indirect sink is `cmd`. For reporting purposes, however,
   * we want to report the `spawn` call as the sink, so we bind it to `sys`.
   */
  private predicate indirectCommandInjection(DataFlow::Node sink, SystemCommandExecution sys) {
    exists (ArgumentListTracking cfg, DataFlow::ArrayLiteralNode args,
            StringLiteral shell, string dashC |
      indirectCommandInjectionCandidate(args, shell, dashC) and
      cfg.hasFlow(DataFlow::valueNode(shell), sys.getACommandArgument()) and
      cfg.hasFlow(args, sys.getArgumentList()) and
      sink = args.getAPropertyWrite().getRhs()
    )
  }

  private predicate indirectCommandInjectionCandidate(DataFlow::ArrayLiteralNode args, StringLiteral shell, string dashC) {
    shellCmd(shell, dashC) and
    args.getAPropertyWrite().getRhs().mayHaveStringValue(dashC)
  }
}

/** DEPRECATED: Use `CommandInjection::Source` instead. */
deprecated class CommandInjectionSource = CommandInjection::Source;

/** DEPRECATED: Use `CommandInjection::Sink` instead. */
deprecated class CommandInjectionSink = CommandInjection::Sink;

/** DEPRECATED: Use `CommandInjection::Sanitizer` instead. */
deprecated class CommandInjectionSanitizer = CommandInjection::Sanitizer;

/** DEPRECATED: Use `CommandInjection::Configuration` instead. */
deprecated class CommandInjectionTrackingConfig = CommandInjection::Configuration;
