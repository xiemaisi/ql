/**
 * INTERNAL: Do not use directly.
 *
 * Provides auxiliary predicates for defining inter-procedural data flow configurations.
 */

import javascript
import semmle.javascript.dataflow.Configuration

/**
 * Holds if flow should be tracked through properties of `obj`.
 *
 * Flow is tracked through object literals, `module` and `module.exports` objects.
 */
predicate shouldTrackProperties(AbstractValue obj) {
  obj instanceof AbstractExportsObject or
  obj instanceof AbstractModuleObject
}

/**
 * Holds if `invk` may invoke `f`.
 */
predicate calls(DataFlow::InvokeNode invk, Function f) {
  if invk.isIndefinite("global") then
    (f = invk.getACallee() and f.getFile() = invk.getFile())
  else
    f = invk.getACallee()
}

/**
 * Holds if `invk` may invoke `f` indirectly through the given `callback` argument.
 *
 * This only holds for explicitly modeled partial calls.
 */
private predicate partiallyCalls(DataFlow::AdditionalPartialInvokeNode invk, DataFlow::AnalyzedNode callback, Function f) {
  invk.isPartialArgument(callback, _, _) and
  exists (AbstractFunction callee | callee = callback.getAValue() |
    if callback.getAValue().isIndefinite("global") then
      (f = callee.getFunction() and f.getFile() = invk.getFile())
    else
      f = callee.getFunction()
  )
}

/**
 * Holds if `f` captures the variable defined by `def` in `cap`.
 */
cached
predicate captures(Function f, SsaExplicitDefinition def, SsaVariableCapture cap) {
  def.getSourceVariable() = cap.getSourceVariable() and
  f = cap.getContainer()
}

/**
 * Holds if `source` corresponds to an expression returned by `f`, and
 * `sink` equals `source`.
 */
pragma[noinline]
predicate returnExpr(Function f, DataFlow::Node source, DataFlow::Node sink) {
  sink.asExpr() = f.getAReturnedExpr() and source = sink
}

/**
 * Holds if data can flow in one step from `pred` to `succ`,  taking
 * additional steps from the configuration into account.
 */
pragma[inline]
predicate localFlowStep(DataFlow::Node pred, DataFlow::Node succ,
                        DataFlow::Configuration configuration,
                        FlowLabel predlbl, FlowLabel succlbl) {
  pred = succ.getAPredecessor() and predlbl = succlbl
  or
  any(DataFlow::AdditionalFlowStep afs).step(pred, succ) and predlbl = succlbl
  or
  exists (boolean vp | configuration.isAdditionalFlowStep(pred, succ, vp) |
    vp = true and
    predlbl = succlbl
    or
    vp = false and
    (predlbl = FlowLabel::data() or predlbl = FlowLabel::taint()) and
    succlbl = FlowLabel::taint()
  )
  or
  configuration.isAdditionalFlowStep(pred, succ, predlbl, succlbl)
}

/**
 * Holds if `arg` is passed as an argument into parameter `parm`
 * through invocation `invk` of function `f`.
 */
predicate argumentPassing(DataFlow::InvokeNode invk, DataFlow::ValueNode arg, Function f, Parameter parm) {
  calls(invk, f) and
  exists (int i |
    f.getParameter(i) = parm and not parm.isRestParameter() and
    arg = invk.getArgument(i)
  )
  or
  exists (DataFlow::Node callback, int i |
    invk.(DataFlow::AdditionalPartialInvokeNode).isPartialArgument(callback, arg, i) and
    partiallyCalls(invk, callback, f) and
    parm = f.getParameter(i) and not parm.isRestParameter())
}


/**
 * Holds if there is a flow step from `pred` to `succ` through parameter passing
 * to a function call.
 */
predicate callStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists (Parameter parm |
    argumentPassing(_, pred, _, parm) and
    succ = DataFlow::parameterNode(parm)
  )
}

/**
 * Holds if there is a flow step from `pred` to `succ` through returning
 * from a function call.
 */
predicate returnStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists (Function f |
    returnExpr(f, pred, _) and
    calls(succ, f)
  )
}

/**
 * Holds if there is an assignment to property `prop` of an object represented by `obj`
 * with right hand side `rhs` somewhere, and properties of `obj` should be tracked.
 */
pragma[noinline]
private predicate trackedPropertyWrite(AbstractValue obj, string prop, DataFlow::Node rhs) {
  exists (AnalyzedPropertyWrite pw |
    pw.writes(obj, prop, rhs) and
    shouldTrackProperties(obj) and
    // avoid introducing spurious global flow
    not pw.baseIsIncomplete("global")
  )
}

/**
 * Holds if there is a flow step from `pred` to `succ` through an object property.
 */
predicate propertyFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists (AbstractValue obj, string prop |
    trackedPropertyWrite(obj, prop, pred) and
    succ.(AnalyzedPropertyRead).reads(obj, prop)
  )
}

/**
 * Gets a node whose value is assigned to `gv` in `f`.
 */
pragma[noinline]
private DataFlow::ValueNode getADefIn(GlobalVariable gv, File f) {
  exists (VarDef def |
    def.getFile() = f and
    def.getTarget() = gv.getAReference() and
    result = DataFlow::valueNode(def.getSource())
  )
}

/**
 * Gets a use of `gv` in `f`.
 */
pragma[noinline]
DataFlow::ValueNode getAUseIn(GlobalVariable gv, File f) {
  result.getFile() = f and
  result = DataFlow::valueNode(gv.getAnAccess())
}

/**
 * Holds if there is a flow step from `pred` to `succ` through a global
 * variable. Both `pred` and `succ` must be in the same file.
 */
predicate globalFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
  exists (GlobalVariable gv, File f |
    pred = getADefIn(gv, f) and
    succ = getAUseIn(gv, f)
  )
}

/**
 * Holds if there is a write to property `prop` of global variable `gv`
 * in file `f`, where the right-hand side of the write is `rhs`.
 */
pragma[noinline]
predicate globalPropertyWrite(GlobalVariable gv, File f, string prop, DataFlow::Node rhs) {
  exists (DataFlow::PropWrite pw |
    pw.writes(getAUseIn(gv, f), prop, rhs)
  )
}

/**
 * Holds if there is a read from property `prop` of `base`, which is
 * an access to global variable `base` in file `f`.
 */
pragma[noinline]
predicate globalPropertyRead(GlobalVariable gv, File f, string prop, DataFlow::Node base) {
  exists (DataFlow::PropRead pr |
    base = getAUseIn(gv, f) and
    pr.accesses(base, prop)
  )
}

/**
 * Holds if there is a store step from `pred` to `succ` under property `prop`,
 * that is, `succ` is the local source of the base of a write of property
 * `prop` with right-hand side `pred`.
 *
 * For example, for this code snippet:
 *
 * ```
 * var a = new A();
 * a.p = e;
 * ```
 *
 * there is a store step from `e` to `new A()` under property `prop`.
 *
 * As a special case, if the base of the property write is a global variable,
 * then there is a store step from the right-hand side of the write to any
 * read of the same property from the same global variable in the same file.
 */
predicate basicStoreStep(DataFlow::Node pred, DataFlow::Node succ, string prop) {
  succ.(DataFlow::SourceNode).hasPropertyWrite(prop, pred)
  or
  exists (GlobalVariable gv, File f |
    globalPropertyWrite(gv, f, prop, pred) and
    globalPropertyRead(gv, f, prop, succ)
  )
}

/**
 * Holds if `f` contains a property write to property `prop` of a value that it returns
 * with right-hand side `rhs`.
 */
predicate returnedPropWrite(Function f, string prop, DataFlow::Node rhs) {
  exists (DataFlow::SourceNode base |
    base.hasPropertyWrite(prop, rhs) and
    base.flowsToExpr(f.getAReturnedExpr())
  )
}

/**
 * Holds if `f` contains a property write to property `prop` of its parameter `parm`
 * with right-hand side `rhs`.
 */
predicate parameterPropWrite(Function f, Parameter parm, string prop, DataFlow::Node rhs) {
  parm = f.getAParameter() and
  DataFlow::parameterNode(parm).hasPropertyWrite(prop, rhs)
}

/**
 * Holds if there is a load step from `pred` to `succ` under property `prop`,
 * that is, `succ` is a read of property `prop` from `pred`.
 */
predicate loadStep(DataFlow::Node pred, DataFlow::PropRead succ, string prop) {
  succ.accesses(pred, prop)
}

/**
 * A utility class that is equivalent to `boolean` but does not require type joining.
 */
class Boolean extends boolean {
  Boolean() { this = true or this = false }
}

/**
 * A summary of an inter-procedural data flow path.
 */
newtype TPathSummary =
  /** A summary of an inter-procedural data flow path. */
  MkPathSummary(Boolean hasReturn, Boolean hasCall, FlowLabel start, FlowLabel end)

/**
 * A summary of an inter-procedural data flow path.
 *
 * The summary includes a start flow label and an end flow label, and keeps track of
 * whether the path contains any call steps from an argument of a function call to the
 * corresponding parameter, and/or any return steps from the `return` statement of a
 * function to a call of that function.
 *
 * We only want to build properly matched call/return sequences, so if a path has both
 * call steps and return steps, all return steps must precede all call steps.
 */
class PathSummary extends TPathSummary {
  Boolean hasReturn;
  Boolean hasCall;
  FlowLabel start;
  FlowLabel end;

  PathSummary() {
    this = MkPathSummary(hasReturn, hasCall, start, end)
  }

  /** Indicates whether the path represented by this summary contains any return steps. */
  boolean hasReturn() {
    result = hasReturn
  }

  /** Indicates whether the path represented by this summary contains any call steps. */
  boolean hasCall() {
    result = hasCall
  }

  /** Gets the flow label describing the value at the end of this flow path. */
  FlowLabel getEndLabel() {
    result = end
  }

  /**
   * Gets the summary for the path obtained by appending `that` to `this`.
   *
   * Note that a path containing a `return` step cannot be appended to a path containing
   * a `call` step in order to maintain well-formedness.
   */
  PathSummary append(PathSummary that) {
    exists (Boolean hasReturn2, Boolean hasCall2, FlowLabel end2 |
      that = MkPathSummary(hasReturn2, hasCall2, end, end2) |
      result = MkPathSummary(hasReturn.booleanOr(hasReturn2),
                             hasCall.booleanOr(hasCall2),
                             start, end2) and
      // avoid constructing invalid paths
      not (hasCall = true and hasReturn2 = true)
    )
  }

  /**
   * Gets the summary for the path obtained by appending `that` to `this`, where
   * `that` must be a path mapping `data` to `data` (in other words, it must be
   * a value-preserving path).
   */
  PathSummary appendValuePreserving(PathSummary that) {
    exists (Boolean hasReturn2, Boolean hasCall2 |
      that = MkPathSummary(hasReturn2, hasCall2, FlowLabel::data(), FlowLabel::data()) |
      result = MkPathSummary(hasReturn.booleanOr(hasReturn2),
                             hasCall.booleanOr(hasCall2),
                             start, end) and
      // avoid constructing invalid paths
      not (hasCall = true and hasReturn2 = true)
    )
  }

  /**
   * Gets the summary for the path obtained by appending `this` to `that`.
   */
  PathSummary prepend(PathSummary that) {
    result = that.append(this)
  }

  /** Gets a textual representation of this path summary. */
  string toString() {
    exists (string withReturn, string withCall |
      (if hasReturn = true then withReturn = "with" else withReturn = "without") and
      (if hasCall = true then withCall = "with" else withCall = "without") |
      result = "path " + withReturn + " return steps and " + withCall + " call steps " +
               "transforming " + start + " into " + end
    )
  }
}

module PathSummary {
  /**
   * Gets a summary describing a path without any calls or returns.
   */
  PathSummary level() {
    exists (FlowLabel lbl |
      result = MkPathSummary(false, false, lbl, lbl)
    )
  }

  /**
   * Gets a summary describing a path with one or more calls, but no returns.
   */
  PathSummary call() {
    exists (FlowLabel lbl |
      result = MkPathSummary(false, true, lbl, lbl)
    )
  }

  /**
   * Gets a summary describing a path with one or more returns, but no calls.
   */
  PathSummary return() {
    exists (FlowLabel lbl |
      result = MkPathSummary(true, false, lbl, lbl)
    )
  }
}
