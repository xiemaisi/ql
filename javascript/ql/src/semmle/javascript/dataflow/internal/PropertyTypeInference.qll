/**
 * INTERNAL: Do not use directly; use `semmle.javascript.dataflow.TypeInference` instead.
 *
 * Provides classes implementing type inference for properties.
 */

import javascript
import semmle.javascript.dataflow.AbstractProperties
private import AbstractPropertiesImpl
private import AbstractValuesImpl

/**
 * Flow analysis for property reads, either explicitly (`x.p` or `x[e]`) or
 * implicitly.
 */
abstract class AnalyzedPropertyRead extends DataFlow::AnalyzedNode {
  /**
   * Holds if this property read may read property `propName` of a concrete value represented
   * by `base`.
   */
  pragma[nomagic]
  abstract predicate reads(AbstractValue base, string propName);

  override AbstractValue getAValue() {
    result = getASourceProperty().getAValue() or
    result = DataFlow::AnalyzedNode.super.getAValue()
  }

  override AbstractValue getALocalValue() {
    result = getASourceProperty().getALocalValue() or
    result = DataFlow::AnalyzedNode.super.getALocalValue()
  }

  /**
   * Gets an abstract property representing one of the concrete properties that
   * this read may refer to.
   */
  pragma[noinline]
  private AbstractProperty getASourceProperty() {
    exists (AbstractValue base, string prop | reads(base, prop) |
      result = MkAbstractProperty(base, prop)
    )
  }

  override predicate isIncomplete(DataFlow::Incompleteness cause) {
    super.isIncomplete(cause) or
    exists (AbstractValue base | reads(base, _) |
      base.isIndefinite(cause)
    )
  }
}

/**
 * Flow analysis for (non-numeric) property read accesses.
 */
private class AnalyzedPropertyAccess extends AnalyzedPropertyRead, DataFlow::ValueNode {
  override PropAccess astNode;
  DataFlow::AnalyzedNode baseNode;
  string propName;

  AnalyzedPropertyAccess() {
    astNode.accesses(baseNode.asExpr(), propName) and
    isNonNumericPropertyName(propName) and
    astNode instanceof RValue
  }

  override predicate reads(AbstractValue base, string prop) {
    base = getAProtoStar(baseNode.getALocalValue()) and
    prop = propName
  }
}

/**
 * Gets the (reflexive, transitive) prototype of `obj`.
 */
private AbstractObjectValue getAProtoStar(AbstractObjectValue obj) {
  result = obj or result = getAProtoStar(obj.getAPrototype())
}

/**
 * Holds if `prop` is a property name that does not look like an array index.
 */
private predicate isNonNumericPropertyName(string prop) {
  exists (PropAccess pacc |
    prop = pacc.getPropertyName() and
    not exists(prop.toInt())
  )
}

/**
 * Holds if properties named `prop` should be tracked.
 */
pragma[noinline]
private predicate isTrackedPropertyName(string prop) {
  exists (MkAbstractProperty(_, prop))
}

/**
 * Flow analysis for property writes, including exports (which are
 * modeled as assignments to `module.exports`).
 */
abstract class AnalyzedPropertyWrite extends DataFlow::Node {
  /**
   * Holds if this property write assigns `source` to property `propName` of one of the
   * concrete objects represented by `baseVal`.
   */
  abstract predicate writes(AbstractValue baseVal, string propName, DataFlow::AnalyzedNode source);

  /**
   * Holds if the flow information for the base node of this property write is incomplete
   * due to `reason`.
   */
  predicate baseIsIncomplete(DataFlow::Incompleteness reason) { none() }
}

/**
 * Flow analysis for property writes.
 */
private class AnalyzedExplicitPropertyWrite extends AnalyzedPropertyWrite {
  AnalyzedExplicitPropertyWrite() {
    this instanceof DataFlow::PropWrite
  }

  override predicate writes(AbstractValue base, string prop, DataFlow::AnalyzedNode source) {
    explicitPropertyWrite(this, base, prop, source)
  }

  override predicate baseIsIncomplete(DataFlow::Incompleteness reason) {
    this.(DataFlow::PropWrite).getBase().isIncomplete(reason)
  }
}

pragma[noopt]
private predicate explicitPropertyWrite(DataFlow::PropWrite pw, AbstractValue base,
                                        string prop, DataFlow::Node source) {
  exists (DataFlow::AnalyzedNode baseNode |
    pw.writes(baseNode, prop, source) and
    isTrackedPropertyName(prop) and
    base = baseNode.getALocalValue() and
    shouldTrackProperties(base)
  )
}
/**
 * Flow analysis for `arguments.callee`. We assume it is never redefined,
 * which is unsound in practice, but pragmatically useful.
 */
private class AnalyzedArgumentsCallee extends AnalyzedPropertyAccess {
  AnalyzedArgumentsCallee() {
    propName = "callee"
  }

  override AbstractValue getALocalValue() {
    exists (AbstractArguments baseVal | reads(baseVal, _) |
      result = TAbstractFunction(baseVal.getFunction())
    )
    or
    hasNonArgumentsBase(astNode) and result = super.getALocalValue()
  }
}

/**
 * Holds if `pacc` is of the form `e.callee` where `e` could evaluate to some
 * value that is not an arguments object.
 */
private predicate hasNonArgumentsBase(PropAccess pacc) {
  pacc.getPropertyName() = "callee" and
  exists (AbstractValue baseVal |
    baseVal = pacc.getBase().analyze().getALocalValue() and
    not baseVal instanceof AbstractArguments
  )
}
